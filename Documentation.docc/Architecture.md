# RiftEffects — Architecture Document

> A UIKit + SwiftUI hybrid iOS app for composing image effects on top of a Core Image
> filter pipeline, rendered with Metal. This document describes the data model object
> graph, the view/controller hierarchy, the rendering path, and how the pieces
> communicate.

---

## 1. Overview

RiftEffects lets a user build a **chain of image filters** ("a stack"), feed it photos
or videos from the Photos library, tune each filter's parameters (with optional
animation), and render the result live via Metal — including to an external AirPlay
display.

The architecture has four conceptual layers:

| Layer | Primary types | Responsibility |
|-------|---------------|----------------|
| **Application state** | `PGLAppStack` | Single source of truth; owns stacks, renderer, photo cache, undo |
| **Filter pipeline** | `PGLFilterStack`, `PGLSourceFilter`, `PGLFilterAttribute` | Ordered, composable, recursively nestable image-processing graph |
| **Assets** | `PGLImageList`, `PGLAsset`, `PGLUserAssetSelection`, `PGLCachedImageMgr` | Photos-library access, caching, selection |
| **Presentation** | `PGLSplitViewController` + column controllers, `Renderer` (Metal) | Three-column editing UI and live rendering |

Most model types are reference types (`class`) and annotated `@MainActor`. The image
cache is implemented as an `actor`.

---

## 2. Data Model

### 2.1 Object graph

Everything hangs off one `@MainActor` object, `PGLAppStack`, which is created and held
by `AppDelegate`.

```
PGLAppStack  (held by AppDelegate)
├── outputStack       : PGLFilterStack      — final rendered output
├── viewerStack       : PGLFilterStack      — stack currently being edited (may be a child)
├── pushedStacks      : [PGLFilterStack]     — breadcrumb nav for nested child stacks
├── flatCellFilters   : [PGLFilterIndent]    — flattened filter tree for table display
├── stackSectionArray : [PGLStackSection]    — indents grouped by level (table sections)
├── appRenderer       : Renderer            — Metal / Core Image engine
├── photoMgr          : PGLCachedImageMgr   — Photos caching (actor)
├── dataProvider      : PGLStackProvider    — Core Data persistence
└── appStackUndoManager : UndoManager       — 8-level undo
```

### 2.2 The filter pipeline (core)

Three nested types form the heart of the app:

**`PGLFilterStack`** (class) — an ordered chain of filters.
- `activeFilters: [PGLSourceFilter]`, `activeFilterIndex: Int`
- `imageUpdate()` wires each filter's output → the next filter's input.
- A stack can be **top-level** or a **child** ("input") stack; a child stack is
  referenced from a parent filter's image attribute via `parentAttribute` (weak) and
  tagged `stackType == "input"`.
- Persists to Core Data (`storedStack: CDFilterStack?`), supports undo
  (`removedFilters`), and export to a Photos album.

**`PGLSourceFilter`** (class) — a wrapper around a single `CIFilter`.
- Parses the `CIFilter`'s attributes into UI-friendly `PGLFilterAttribute` objects
  (`attributes: [PGLFilterAttribute]`).
- Renders via `outputImage()`; manages `setInput()` / `inputImage()`.
- Supports animation (`hasAnimation`, `animationAttributes`, `addFilterStepTime()`).
- Subclassed for specialized behavior — transitions, detectors, rectangles, sequences,
  gradient polygons, camera/video, etc.

**`PGLFilterAttribute`** (class, base) — a single filter parameter.
- Bridges a CI attribute (`attributeName`, `attributeType`, `attributeClass`) to UI
  controls and to the backing `CIFilter`.
- Tracks input state via `ParmInputState` (e.g. `inputValueSet`, `inputPriorFilter`,
  `inputChildStack`, `missingImageInput`).
- Drives animation via `VaryDissolveState` and delta stepping.

**Attribute subclasses** (one per CI value type):

| Subclass | Value | UI |
|----------|-------|-----|
| `PGLFilterAttributeNumber` | scalar `NSNumber` | slider |
| `PGLFilterAttributeColor` | RGBA `CIColor` | per-channel sliders |
| `PGLFilterAttributeAngle` | radians | slider (0…2π) |
| `PGLFilterAttributeVector` / `Vector3` | `CIVector` point | position control + start→end animation |
| `PGLFilterAttributeAffine` | `CGAffineTransform` | rotate / scale / translate sub-controls |
| `PGLFilterAttributeTime` | seconds | timer slider (used for sequencing) |
| `PGLFilterAttributeImage` | `CIImage` | image picker; **can host a child `PGLFilterStack`** |
| `PGLAttributeRectangle` | `CGRect` | interactive crop editor |

### 2.3 The key recursion

A **`PGLFilterAttributeImage` may hold a child `PGLFilterStack`** through its
`inputStack` property. This means a filter's image input can itself be the rendered
output of an entire nested filter graph — the mechanism behind masks, backgrounds, and
multi-input/transition effects.

```
PGLFilterStack
└── PGLSourceFilter
    ├── CIFilter (the backing filter)
    └── PGLFilterAttribute[]
        └── PGLFilterAttributeImage
            ├── inputCollection : PGLImageList      (photos)
            └── inputStack       : PGLFilterStack    (nested graph) ──┐
                                                                      └─ recursion
```

### 2.4 Asset model (`Models/PhotoList/`)

```
PGLImageList ──── [PGLAsset]            (wraps PHAsset; lazy CIImage + thumbnail)
   │                  ▲
   │                  └── cached by PGLCachedImageMgr (actor, PHCachingImageManager)
   └── PGLUserAssetSelection ──── [PGLAlbumSource]   (wraps PHAssetCollection)
```

- **`PGLImageList`** — ordered sequence container; supports `.each` / `.odd` / `.even`
  iteration modes used by transition filters; may instead draw its image from an
  `inputStack`.
- **`PGLAsset`** — wraps a `PHAsset`; lazily loads and caches `CIImage`, generates
  thumbnails, handles orientation and video playback (`PGLAssetVideoPlayer`).
- **`PGLUserAssetSelection`** / **`PGLAlbumSource`** — track the user's cross-album
  selection while building an input list.
- **`PGLCachedImageMgr`** — `actor` wrapping `PHCachingImageManager` for async,
  cancellable image requests.
- **`PGLImageListPicker`** — bridges `PHPickerViewController` results into a new
  `PGLImageList` assigned to an image attribute (with undo registration).

### 2.5 View-model & catalog helpers

- **`PGLFilterIndent`** — a filter + indent level + owning stack; the view model for one
  filter row.
- **`PGLStackSection`** — groups indents from one stack into a table section.
- **`PGLFilterDescriptor`** (struct) — factory mapping a `CIFilter` name to the right
  `PGLSourceFilter` subclass.
- **`PGLFilterCategory`** — catalog of available filters grouped into the 13 Core Image
  categories; drives the filter-picker menu.

### 2.6 Notable enums / value types

`ParmInputState`, `VaryDissolveState`, `NextElement` (`.each/.odd/.even`),
`FilterChangeMode` (`.add/.replace`), `PGLFilterCategoryIndex` (menu position),
`PGLCenterScaler` (image fit/center), `PGLVectorScaling` (aspect preservation).

---

## 3. View Hierarchy

The UI backbone is a three-column `UISplitViewController` (`PGLSplitViewController`,
instantiated from `Main.storyboard` as `"RootSplitView"`). Each column is wrapped in its
own `UINavigationController`.

```
PGLSplitViewController
├── PRIMARY  (left)    → PGLOpenStackController / PGLLibraryController
│                          Browse & load saved stacks (CollectionView grid, Core Data)
├── SUPPLEMENTARY      → PGLStackController (UITableViewController)
│   (middle)             One row per filter in the current stack; reorder / delete
├── SECONDARY (right)  → PGLImageController
│                          Live preview + parameter sliders
└── COMPACT (iPhone)   → PGLStackImageContainerController
                           Combined single-column interface for compact width
```

### 3.1 Column responsibilities

| Controller | Type | Role |
|------------|------|------|
| `PGLSplitViewController` | `UISplitViewController` | Root container; owns the four columns and the SwiftUI image-list overlay |
| `PGLOpenStackController` / `PGLLibraryController` | `UIViewController` | Library: browse/load saved stacks (diffable `UICollectionView`) |
| `PGLStackController` | `UITableViewController` | Stack editor: one row per filter; reorder, delete, save |
| `PGLImageController` / `PGLCompactImageController` | `UIViewController` | Preview + parameter sliders; gateway to full-screen render |
| `PGLMetalController` | `UIViewController` (`MTKView`) | Full-screen Metal render with pinch/pan/tap gestures |
| `PGLMainFilterController` | `UIViewController` (CollectionView) | Pick / swap a filter, grouped by category, with search |
| `PGLSelectParmController` | `PGLCommonController` (UITableView) | Edit the selected filter's parameters |
| `PGLParmImageController` | `UIViewController` | Choose images for an image input (PHPicker) |
| `PGLRectangleController` | `UIViewController` | Interactive corner-handle crop editing |
| `PGLAirPlayMetalController` | `UIViewController` (`MTKView`) | External-display rendering |
| `PGLHelpPageController` / `PGLHelpSinglePage` | `UIPageViewController` / `UIViewController` | In-app help |

### 3.2 Editing & navigation flow

```
Startup → PGLSplitViewController.requestStartupImage() → PHPicker → initial PGLImageList

Main screen (3 columns):
  LEFT   Library → tap a saved stack → load into working area
  MIDDLE Stack   → tap a filter row  → PGLMainFilterController (swap filter)
                 → swipe a filter row → PGLSelectParmController (edit parameters)
  RIGHT  Preview → slider → update parameter
                 → double-tap → full-screen PGLMetalController

Parameter editing (PGLSelectParmController) branches to:
  • image parameter      → PGLParmImageController (select photos)
  • rectangle parameter  → PGLRectangleController (interactive crop)
  • child-stack parameter→ nested PGLStackController (edit the child graph)
```

### 3.3 SwiftUI integration

SwiftUI is used selectively and hosted inside UIKit via `UIHostingController`:

- **`PGLImageListOverlayView`** — the primary SwiftUI surface; an overlay listing a
  filter's input images, backed by `PGLImageListViewModel: ObservableObject`. Toggled by
  the `PGLShowImageListOverLay` notification.
- **`PGLPhotoPicker`** — a `UIViewControllerRepresentable` wrapping
  `PHPickerViewController`.
- `PGLStackRow` / `PGLStackItem` — placeholder / work-in-progress components.

---

## 4. Rendering Path (Metal + Core Image)

`Renderer` (`Metal Render/Renderer.swift`) is an `MTKViewDelegate` that owns a Metal
`CIContext`.

```
PGLAppStack.appRenderer (Renderer)
  ├── reads the active PGLFilterStack
  ├── walks the filter chain, producing a CIImage (lastStackOutputImage)
  ├── draws into the MTKView via the Metal CIContext
  └── optionally syncs to childDeviceRenderer (AirPlay)
```

- **Supporting Metal files:** `Quad.swift`, `VertexDescriptor.swift`,
  `AAPLShaders.metal`, `AAPLShaderTypes.h`, `PGLCaptureOutput.swift` (image/video
  export).
- **AirPlay:** `PGLAirPlaySceneDelegate` creates a separate external-display scene
  (role `.windowExternalDisplayNonInteractive`) hosting `PGLAirPlayMetalController` and a
  `PGLRenderOnAirPlay` (a `Renderer` subclass). The main renderer drives it through its
  `childDeviceRenderer` reference.

---

## 5. App & Scene Lifecycle

```
@main AppDelegate
  ├── owns appStack : PGLAppStack         (shared application state)
  ├── owns dataWrapper : CoreDataWrapper  (NSPersistentCloudKitContainer)
  ├── registers custom Core Image filters on launch
  └── builds the app menu

PGLWindowSceneDelegate  → instantiates "RootSplitView" from Main.storyboard
PGLAirPlaySceneDelegate → creates the external-display scene on connection
```

---

## 6. Communication — Notifications

Inter-column and model→view coordination is largely `NotificationCenter`-based:

| Notification | Posted by | Observed by | Purpose |
|--------------|-----------|-------------|---------|
| `PGLStackChange` | stack edits | Stack controller, Library | Refresh stack display |
| `PGLRedrawFilterChange` | parameter changes | Split view, Metal controller | Re-render preview |
| `PGLCurrentFilterChange` | filter selection | Image controller | Reload parameter UI |
| `PGLSelectActiveStackRow` | selection | Stack controller | Highlight active filter |
| `PGLShowImageListOverLay` | UI | Split view | Toggle SwiftUI image-list overlay |
| `PGLLoadedDataStack` | random/demo filter | Stack controller | Navigate to stack view |
| `PGLStackStartSave` | save button | Stack controller | Present save dialog |
| `PGLUpdateSplitView` | window changes | Stack controller | Refresh layout |

---

## 7. Persistence

- **Core Data** via `NSPersistentCloudKitContainer` (`CoreDataWrapper`), accessed through
  `PGLStackProvider`.
- Saved filter stacks persist as `CDFilterStack` with stored filters and a thumbnail;
  loaded back via `PGLFilterStack.on(cdStack:)`.

---

## 8. Concurrency & Memory Notes

- Model types are `@MainActor`; `PGLCachedImageMgr` is an `actor` for off-main image
  loading. The codebase favors `async`/`await` over Combine.
- Key reference-cycle guards:
  - `PGLFilterAttribute.aSourceFilter` — `unowned`
  - `PGLFilterStack.parentAttribute` — `weak`
  - `PGLUserAssetSelection.myTargetFilterAttribute` — `weak`
  - `PGLAlbumSource.filterParm` — `unowned`
- Identity-based hashing: `PGLFilterStack` and `PGLFilterIndent` hash by object
  identity; `PGLAsset` by `localIdentifier`; `PGLFilterDescriptor` by filter name.

---

## 9. Mental Model (one paragraph)

`PGLAppStack` is the single source of truth, holding nested `PGLFilterStack`s of
`PGLSourceFilter`s of `PGLFilterAttribute`s. Image inputs come from `PGLImageList`s of
`PGLAsset`s — or, recursively, from a child `PGLFilterStack` attached to an image
attribute. The three-column split view exposes those layers as **Library → Stack →
Parameters**, a `Renderer` turns the active stack into pixels via Metal (mirrored to
AirPlay when present), and `NotificationCenter` keeps the columns in sync as the model
changes.
