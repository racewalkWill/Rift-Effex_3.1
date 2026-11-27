//
//  PGLCanvasSpace.swift
//  RiftEffects
//
//  Created by Claude on 8/27/26.
//  Copyright © 2026 Will Loew-Blosser. All rights reserved.
//

import CoreGraphics
import CoreImage

/// Fixed logical coordinate space that vector/rect filter parms are authored and stored in.
/// Never derived from a view or drawable, and never reassigned. Storing parm values relative
/// to this constant (rather than the live, mutable `RenderTargetSize`) is what makes them
/// independent of navigation history, rotation, and which view last resized.
let FilterCanvasSize = CGSize(width: 1040, height: 768)

/// Uniform scale that fits `FilterCanvasSize` inside `renderSize` - the same aspect-fit
/// PGLCenterScaler applies to images, so a point keeps its position relative to the image
/// when the render size changes shape (rotation, double-tap full screen).
/// In FullScreenAspectFillMode images are stretched per axis, so this answers the x-axis
/// stretch to match the per-axis canvasToRenderTransform below.
@MainActor
func canvasFitScale(renderSize: CGSize) -> CGFloat {
    guard FilterCanvasSize.width > 0, FilterCanvasSize.height > 0 else {
        return 1.0
    }
    if FullScreenAspectFillMode {
        return renderSize.width / FilterCanvasSize.width
    }
    return canvasUniformFitScale(size: renderSize)
}

/// The aspect-fit scale of `FilterCanvasSize` inside `size`, ignoring FullScreenAspectFillMode.
/// Persistence of Distance number parms uses this so a saved value converts back exactly
/// and renders the same pixel distance at the size it was saved at.
func canvasUniformFitScale(size: CGSize) -> CGFloat {
    guard FilterCanvasSize.width > 0, FilterCanvasSize.height > 0,
          size.width > 0, size.height > 0 else {
        return 1.0
    }
    return min(size.width / FilterCanvasSize.width, size.height / FilterCanvasSize.height)
}

/// Maps `FilterCanvasSize` into `renderSize` for display - aspect-fit (uniform scale and
/// centered) like PGLCenterScaler.setAspectFitTransform, or a per-axis stretch in
/// FullScreenAspectFillMode like PGLCenterScaler.setAspectFillTransform.
/// Both spaces share the same lower-left origin (CoreImage LLO working rect).
/// Persistence does NOT use this - see CIVector.scaledFromCanvas(toRenderSize:).
@MainActor
func canvasToRenderTransform(renderSize: CGSize) -> CGAffineTransform {
    guard FilterCanvasSize.width > 0, FilterCanvasSize.height > 0,
          renderSize.width > 0, renderSize.height > 0 else {
        return .identity
    }
    if FullScreenAspectFillMode {
        let sx = renderSize.width / FilterCanvasSize.width
        let sy = renderSize.height / FilterCanvasSize.height
        return CGAffineTransform(scaleX: sx, y: sy)
    }
    let scale = canvasFitScale(renderSize: renderSize)
    let shiftX = (renderSize.width - FilterCanvasSize.width * scale) * 0.5
    let shiftY = (renderSize.height - FilterCanvasSize.height * scale) * 0.5
    return CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: shiftX, ty: shiftY)
}

/// Inverse of `canvasToRenderTransform(renderSize:)`.
@MainActor
func renderToCanvasTransform(renderSize: CGSize) -> CGAffineTransform {
    guard renderSize.width > 0, renderSize.height > 0 else {
        return .identity
    }
    return canvasToRenderTransform(renderSize: renderSize).inverted()
}

/// How canvas-space point and Distance parms map into one filter's CIFilter for a frame.
///
/// `referenceRect` is where, in render pixels, the image the filter's parms belong to is
/// drawn - a photo's aspect-fit rect (its extent after PGLCenterScaler), a video frame's
/// full view, a prior filter's reference passed down the stack, or a transition's input and
/// target rects blended by inputTime (see PGLSourceFilter #parmReferenceRect).
/// The canvas is stretched per axis onto that rect, so a point keeps its position in the
/// image for any image shape and any view size; distances use the uniform fit of the canvas
/// in the rect, so they scale with the image.
/// nil (generators, no image input) falls back to the aspect-fit of FilterCanvasSize in
/// the render size - canvasToRenderTransform(renderSize:).
struct PGLParmMapping: Equatable {
    var referenceRect: CGRect?
    var renderSize: CGSize
    var aspectFill: Bool

    @MainActor
    static func current(referenceRect: CGRect?) -> PGLParmMapping {
        return PGLParmMapping(referenceRect: referenceRect,
                              renderSize: RenderTargetSize,
                              aspectFill: FullScreenAspectFillMode)
    }

    private var usableRect: CGRect? {
        guard let referenceRect,
              !referenceRect.isInfinite, !referenceRect.isNull,
              referenceRect.width > 0, referenceRect.height > 0,
              FilterCanvasSize.width > 0, FilterCanvasSize.height > 0
            else { return nil }
        return referenceRect
    }

    /// canvas -> render pixels (CoreImage LLO)
    @MainActor
    func canvasToRender() -> CGAffineTransform {
        guard let rect = usableRect else {
            return canvasToRenderTransform(renderSize: renderSize)
        }
        return CGAffineTransform(a: rect.width / FilterCanvasSize.width, b: 0,
                                 c: 0, d: rect.height / FilterCanvasSize.height,
                                 tx: rect.minX, ty: rect.minY)
    }

    /// scale for canvas distances (Distance parms, the z radius of a 3-value point)
    @MainActor
    func distanceScale() -> CGFloat {
        guard let rect = usableRect else {
            return canvasFitScale(renderSize: renderSize)
        }
        return min(rect.width / FilterCanvasSize.width, rect.height / FilterCanvasSize.height)
    }

    @MainActor
    func toRender(_ vector: CIVector) -> CIVector {
        let transform = canvasToRender()
        switch vector.count {
            case 2:
                let point = CGPoint(x: vector.x, y: vector.y).applying(transform)
                return CIVector(x: point.x, y: point.y)
            case 3:
                let point = CGPoint(x: vector.x, y: vector.y).applying(transform)
                return CIVector(x: point.x, y: point.y, z: vector.z * distanceScale())
            case 4:
                return CIVector(cgRect: vector.cgRectValue.applying(transform))
            default:
                return vector
        }
    }

    @MainActor
    func toRender(distance: CGFloat) -> CGFloat {
        return distance * distanceScale()
    }

    /// Inverse of `toRender(_:)` for a rect - a render-pixel rect (CoreImage LLO) back to canvas units
    @MainActor
    func toCanvas(rect renderRect: CGRect) -> CGRect {
        return renderRect.applying(canvasToRender().inverted())
    }

    // MARK: view points - the position marker and drag gesture

    /// canvas point -> UIKit view point (upper-left origin, y-down) in a view of `viewSize`
    /// that shows the render size. Without a reference rect this is the R297 view fit.
    @MainActor
    func viewPoint(for vector: CIVector, viewSize: CGSize) -> CGPoint {
        guard usableRect != nil, renderSize.width > 0, renderSize.height > 0 else {
            return canvasVectorToViewPoint(vector, viewSize: viewSize)
        }
        let renderPoint = CGPoint(x: vector.x, y: vector.y).applying(canvasToRender())
        let viewScaleX = viewSize.width / renderSize.width
        let viewScaleY = viewSize.height / renderSize.height
        return CGPoint(x: renderPoint.x * viewScaleX,
                       y: viewSize.height - (renderPoint.y * viewScaleY))
    }

    /// canvas rect -> UIKit view rect (upper-left origin, y-down) - the rectangle parm overlay.
    /// Without a reference rect this is the R297 view fit.
    @MainActor
    func viewRect(for canvasRect: CGRect, viewSize: CGSize) -> CGRect {
        guard usableRect != nil, renderSize.width > 0, renderSize.height > 0 else {
            return canvasRectToViewRect(canvasRect, viewSize: viewSize)
        }
        let renderRect = canvasRect.applying(canvasToRender())
        let viewScaleX = viewSize.width / renderSize.width
        let viewScaleY = viewSize.height / renderSize.height
        return CGRect(x: renderRect.minX * viewScaleX,
                      y: viewSize.height - (renderRect.maxY * viewScaleY),
                      width: renderRect.width * viewScaleX,
                      height: renderRect.height * viewScaleY)
    }

    /// Inverse of `viewRect(for:viewSize:)` - the edited overlay frame back to a canvas rect.
    @MainActor
    func canvasRect(for viewRect: CGRect, viewSize: CGSize) -> CGRect {
        guard usableRect != nil, renderSize.width > 0, renderSize.height > 0,
              viewSize.width > 0, viewSize.height > 0 else {
            return viewRectToCanvasRect(viewRect, viewSize: viewSize)
        }
        let viewScaleX = viewSize.width / renderSize.width
        let viewScaleY = viewSize.height / renderSize.height
        let renderRect = CGRect(x: viewRect.minX / viewScaleX,
                                y: (viewSize.height - viewRect.maxY) / viewScaleY,
                                width: viewRect.width / viewScaleX,
                                height: viewRect.height / viewScaleY)
        return renderRect.applying(canvasToRender().inverted())
    }

    /// Inverse of `viewPoint(for:viewSize:)` - a dragged view point back to a canvas vector.
    @MainActor
    func canvasVector(for viewPoint: CGPoint, viewSize: CGSize) -> CIVector {
        guard usableRect != nil, renderSize.width > 0, renderSize.height > 0,
              viewSize.width > 0, viewSize.height > 0 else {
            return viewPointToCanvasVector(viewPoint, viewSize: viewSize)
        }
        let viewScaleX = viewSize.width / renderSize.width
        let viewScaleY = viewSize.height / renderSize.height
        let renderPoint = CGPoint(x: viewPoint.x / viewScaleX,
                                  y: (viewSize.height - viewPoint.y) / viewScaleY)
        let canvasPoint = renderPoint.applying(canvasToRender().inverted())
        return CIVector(x: canvasPoint.x, y: canvasPoint.y)
    }
}

extension CIVector {
    /// Maps a canvas-space vector into `renderSize`-space for display - the value given to
    /// the CIFilter. Uses `canvasToRenderTransform(renderSize:)` so points keep their position
    /// relative to the aspect-fit image. The z component (a radius/distance) and rect sizes
    /// scale by `canvasFitScale(renderSize:)`.
    @MainActor
    func fittedFromCanvas(toRenderSize renderSize: CGSize) -> CIVector {
        canvasMapped(canvasToRenderTransform(renderSize: renderSize))
    }

    /// Inverse of `fittedFromCanvas(toRenderSize:)`.
    @MainActor
    func fittedToCanvas(fromRenderSize renderSize: CGSize) -> CIVector {
        canvasMapped(renderToCanvasTransform(renderSize: renderSize))
    }

    /// `transform` is scale + translate only (no rotation) - z scales by the x factor `a`.
    private func canvasMapped(_ transform: CGAffineTransform) -> CIVector {
        switch count {
            case 2:
                let point = CGPoint(x: x, y: y).applying(transform)
                return CIVector(x: point.x, y: point.y)
            case 3:
                let point = CGPoint(x: x, y: y).applying(transform)
                return CIVector(x: point.x, y: point.y, z: z * transform.a)
            case 4:
                return CIVector(cgRect: cgRectValue.applying(transform))
            default:
                return self
        }
    }

    /// Persistence only: a per-axis stretch into `renderSize` (the saved globalSize space).
    /// storeParmValue writes this and resizeFrom(savedSize:) reverses it with the same
    /// per-axis stretch, so saved and CloudKit values keep their meaning. Display uses
    /// `fittedFromCanvas(toRenderSize:)` instead.
    ///
    /// Scales a canvas-space vector into `renderSize`-space. Handles 2-component points,
    /// 3-component points (the z component is a radius/distance, scaled by the x-axis
    /// factor rather than silently dropped), and 4-component rects.
    ///
    /// z (and the scalar helper below) intentionally scale by the x-axis factor alone,
    /// not min(sx,sy): a value's round trip through two *different* non-uniform stretches
    /// (e.g. canvas->render at save time, then render->canvas at load time with a
    /// different render size) is only exactly invertible if the same single axis is used
    /// both times - min(sx,sy) of a transform's inverse is not the inverse of min(sx,sy)
    /// of the forward transform unless the stretch happens to be uniform.
    func scaledFromCanvas(toRenderSize renderSize: CGSize) -> CIVector {
        canvasScaled(otherSize: renderSize, canvasIsSource: true)
    }

    /// Inverse of `scaledFromCanvas(toRenderSize:)` - maps a render-space vector back to canvas space.
    func scaledToCanvas(fromRenderSize renderSize: CGSize) -> CIVector {
        canvasScaled(otherSize: renderSize, canvasIsSource: false)
    }

    private func canvasScaled(otherSize: CGSize, canvasIsSource: Bool) -> CIVector {
        guard FilterCanvasSize.width > 0, FilterCanvasSize.height > 0,
              otherSize.width > 0, otherSize.height > 0 else {
            return self
        }
        var sx = otherSize.width / FilterCanvasSize.width
        var sy = otherSize.height / FilterCanvasSize.height
        if !canvasIsSource {
            sx = 1.0 / sx
            sy = 1.0 / sy
        }
        switch count {
            case 2:
                return CIVector(x: x * sx, y: y * sy)
            case 3:
                return CIVector(x: x * sx, y: y * sy, z: z * sx)
            case 4:
                let rect = cgRectValue
                let scaledRect = CGRect(x: rect.origin.x * sx, y: rect.origin.y * sy,
                                         width: rect.width * sx, height: rect.height * sy)
                return CIVector(cgRect: scaledRect)
            default:
                return self
        }
    }
}

/// Maps a canvas-space vector to a point in a UIKit view of `viewSize` (upper-left origin,
/// y-down) - the on-screen center for a draggable position marker. Uses the same fit as
/// `fittedFromCanvas(toRenderSize:)` so the marker sits where the filter draws the point.
@MainActor
func canvasVectorToViewPoint(_ vector: CIVector, viewSize: CGSize) -> CGPoint {
    guard FilterCanvasSize.width > 0, FilterCanvasSize.height > 0 else {
        return .zero
    }
    let lloPoint = CGPoint(x: vector.x, y: vector.y).applying(canvasToRenderTransform(renderSize: viewSize))
    return CGPoint(x: lloPoint.x, y: viewSize.height - lloPoint.y)
}

/// Inverse of `canvasVectorToViewPoint(_:viewSize:)` - maps a UIKit view point (e.g. where the
/// user dropped a drag gesture) back into canvas-space CIVector coordinates.
@MainActor
func viewPointToCanvasVector(_ point: CGPoint, viewSize: CGSize) -> CIVector {
    guard viewSize.width > 0, viewSize.height > 0 else {
        return CIVector(x: 0, y: 0)
    }
    let lloPoint = CGPoint(x: point.x, y: viewSize.height - point.y)
    let canvasPoint = lloPoint.applying(renderToCanvasTransform(renderSize: viewSize))
    return CIVector(x: canvasPoint.x, y: canvasPoint.y)
}

/// Maps a canvas-space rect (LLO) to a UIKit view rect (ULO) for `viewSize`.
@MainActor
func canvasRectToViewRect(_ rect: CGRect, viewSize: CGSize) -> CGRect {
    guard FilterCanvasSize.width > 0, FilterCanvasSize.height > 0 else {
        return .zero
    }
    let lloRect = rect.applying(canvasToRenderTransform(renderSize: viewSize))
    return CGRect(x: lloRect.origin.x, y: viewSize.height - lloRect.maxY,
                  width: lloRect.width, height: lloRect.height)
}

/// Inverse of `canvasRectToViewRect(_:viewSize:)`.
@MainActor
func viewRectToCanvasRect(_ rect: CGRect, viewSize: CGSize) -> CGRect {
    guard viewSize.width > 0, viewSize.height > 0 else {
        return .zero
    }
    let lloRect = CGRect(x: rect.origin.x, y: viewSize.height - rect.maxY,
                         width: rect.width, height: rect.height)
    return lloRect.applying(renderToCanvasTransform(renderSize: viewSize))
}

/// Scales a canvas-space scalar distance (e.g. a gradient width or radius) into `renderSize`-space
/// for display - matches the scale `fittedFromCanvas(toRenderSize:)` applies to points.
@MainActor
func canvasFitScalar(_ value: CGFloat, renderSize: CGSize) -> CGFloat {
    return value * canvasFitScale(renderSize: renderSize)
}

/// Persistence only - pairs with CIVector.scaledFromCanvas(toRenderSize:).
/// Scales a canvas-space scalar distance (e.g. a gradient width or radius) into `renderSize`-space.
/// Uses the x-axis factor alone - see the comment on CIVector.scaledFromCanvas(toRenderSize:)
/// for why a single consistent axis (not min(sx,sy)) is required for exact round-tripping.
func canvasScalar(_ value: CGFloat, renderSize: CGSize) -> CGFloat {
    guard FilterCanvasSize.width > 0 else {
        return value
    }
    let sx = renderSize.width / FilterCanvasSize.width
    return value * sx
}
