//
//  PGLCanvasSpaceTests.swift
//  RiftEffectsTests
//
//  Created by Claude on 8/28/26.
//  Copyright © 2026 Will Loew-Blosser. All rights reserved.
//

import Testing
import CoreGraphics
import CoreImage
import CoreData
import UIKit

@testable import RiftEffects

@MainActor
@Suite struct PGLCanvasSpaceTests {

    let renderSizes: [CGSize] = [
        CGSize(width: 402, height: 874),     // iPhone parm-editing panel (tall, from the reported bug)
        CGSize(width: 1206, height: 1195),   // iPhone main image editor
        CGSize(width: 2732, height: 2048),   // iPad landscape
        CGSize(width: 2048, height: 2732),   // iPad portrait
        FilterCanvasSize,                    // identity case
    ]

    @Test func canvasToRenderRoundTrip() {
        for renderSize in renderSizes {
            let vector = CIVector(x: 130, y: 1125)
            let rendered = vector.scaledFromCanvas(toRenderSize: renderSize)
            let backToCanvas = rendered.scaledToCanvas(fromRenderSize: renderSize)
            #expect(abs(backToCanvas.x - vector.x) < 0.001)
            #expect(abs(backToCanvas.y - vector.y) < 0.001)
        }
    }

    @Test func canvasToRenderIsIdentityAtCanvasSize() {
        let vector = CIVector(x: 130, y: 1125)
        let rendered = vector.scaledFromCanvas(toRenderSize: FilterCanvasSize)
        #expect(abs(rendered.x - vector.x) < 0.001)
        #expect(abs(rendered.y - vector.y) < 0.001)
    }

    @Test func fittedCanvasToRenderRoundTrip() {
        for renderSize in renderSizes {
            let vector = CIVector(x: 130, y: 1125, z: 40)
            let rendered = vector.fittedFromCanvas(toRenderSize: renderSize)
            let backToCanvas = rendered.fittedToCanvas(fromRenderSize: renderSize)
            #expect(abs(backToCanvas.x - vector.x) < 0.001)
            #expect(abs(backToCanvas.y - vector.y) < 0.001)
            #expect(abs(backToCanvas.z - vector.z) < 0.001)
        }
    }

    /// The "zoom star" rotation report: the Zoom Blur center must keep its position relative
    /// to the aspect-fit input image when the render size rotates.
    @Test func fittedPointKeepsImageRelativePositionAcrossRotation() {
        let imageExtent = CGRect(x: 0, y: 0, width: 1179, height: 786)
        let canvasCenter = CIVector(x: 510.33, y: 495.16)
        let landscape = CGSize(width: 1542, height: 1179)
        let portrait = CGSize(width: 1179, height: 1604)

        func imageRelative(_ renderSize: CGSize) -> CGPoint {
            // same fit as PGLCenterScaler.setAspectFitTransform (without its rounding)
            let scale = min(renderSize.width / imageExtent.width, renderSize.height / imageExtent.height)
            let fitRect = CGRect(x: (renderSize.width - imageExtent.width * scale) / 2,
                                 y: (renderSize.height - imageExtent.height * scale) / 2,
                                 width: imageExtent.width * scale, height: imageExtent.height * scale)
            let rendered = canvasCenter.fittedFromCanvas(toRenderSize: renderSize)
            return CGPoint(x: (rendered.x - fitRect.minX) / fitRect.width,
                           y: (rendered.y - fitRect.minY) / fitRect.height)
        }
        let landscapeRelative = imageRelative(landscape)
        let portraitRelative = imageRelative(portrait)
        #expect(abs(landscapeRelative.x - portraitRelative.x) < 0.001)
        #expect(abs(landscapeRelative.y - portraitRelative.y) < 0.001)
    }

    @Test func fittedUsesPerAxisStretchInAspectFillMode() {
        let savedMode = FullScreenAspectFillMode
        defer { FullScreenAspectFillMode = savedMode }
        FullScreenAspectFillMode = true
        let vector = CIVector(x: 100, y: 200)
        let renderSize = CGSize(width: FilterCanvasSize.width * 2, height: FilterCanvasSize.height * 3)
        let rendered = vector.fittedFromCanvas(toRenderSize: renderSize)
        #expect(abs(rendered.x - 200) < 0.001)
        #expect(abs(rendered.y - 600) < 0.001)
    }

    /// Sixfold Rotated Tile inputWidth is a Distance parm - it must scale with the aspect-fit
    /// image so each tile covers the same part of the image after rotation.
    @Test func distanceParmScalesWithFitAcrossRotation() throws {
        let savedSize = RenderTargetSize
        defer { RenderTargetSize = savedSize }
        let filter = try #require(PGLSourceFilter(filter: "CISixfoldRotatedTile"))
        let width = try #require(filter.attribute(nameKey: kCIInputWidthKey) as? PGLFilterAttributeNumber)
        #expect(width.usesCanvasDistance())

        let landscape = CGSize(width: 1542, height: 1179)
        let portrait = CGSize(width: 1179, height: 1604)
        RenderTargetSize = landscape
        width.set(NSNumber(value: 100.0))
        width.applyMapping(PGLParmMapping(referenceRect: nil, renderSize: landscape, aspectFill: false))
        let landscapeValue = try #require(filter.localFilter.value(forKey: kCIInputWidthKey) as? NSNumber).doubleValue
        width.applyMapping(PGLParmMapping(referenceRect: nil, renderSize: portrait, aspectFill: false))
        let portraitValue = try #require(filter.localFilter.value(forKey: kCIInputWidthKey) as? NSNumber).doubleValue

        #expect(abs(landscapeValue - 100.0 * canvasUniformFitScale(size: landscape)) < 0.001)
        #expect(abs(portraitValue - 100.0 * canvasUniformFitScale(size: portrait)) < 0.001)
        // the canvas value seen by the slider and storage is unchanged by the render size
        #expect(width.getNumberValue()?.doubleValue == 100.0)
    }

    /// storeParmValue writes canvas * fit(RenderTargetSize); load sets that value then
    /// resizeFrom(savedSize: globalSize) divides by fit(savedSize).
    @Test func distanceParmStoredValueRoundTrips() throws {
        let filter = try #require(PGLSourceFilter(filter: "CISixfoldRotatedTile"))
        let width = try #require(filter.attribute(nameKey: kCIInputWidthKey) as? PGLFilterAttributeNumber)
        for saveSize in renderSizes {
            let stored = 75.0 * Double(canvasUniformFitScale(size: saveSize))
            width.set(NSNumber(value: stored))
            width.resizeFrom(savedSize: saveSize)
            #expect(abs((width.getNumberValue()?.doubleValue ?? 0) - 75.0) < 0.001)
        }
    }

    /// CICircularWrap adds the input image's origin to the hole radius - the letterboxed
    /// image (portrait fitRect y = 360) must reach the filter at a (0,0) origin.
    @Test func circularWrapInputIsOriginNormalized() throws {
        let letterboxed = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 360, width: 1179, height: 884))
        let wrap = try #require(PGLSourceFilter(filter: "CICircularWrap"))
        wrap.setImageValue(newValue: letterboxed, keyName: kCIInputImageKey)
        let wrapInput = try #require(wrap.localFilter.value(forKey: kCIInputImageKey) as? CIImage)
        #expect(wrapInput.extent == CGRect(x: 0, y: 0, width: 1179, height: 884))

        // position independent filters keep the input where it is
        let twirl = try #require(PGLSourceFilter(filter: "CITwirlDistortion"))
        twirl.setImageValue(newValue: letterboxed, keyName: kCIInputImageKey)
        let twirlInput = try #require(twirl.localFilter.value(forKey: kCIInputImageKey) as? CIImage)
        #expect(twirlInput.extent == letterboxed.extent)
    }

    // MARK: image reference rect mapping

    /// The 'Eightfold Reflected Tile' report: a portrait photo (1132x1604) is drawn
    /// height-bound in both orientations while the canvas fit flips axes. Mapping onto the
    /// photo's own rect keeps the center and tile width fixed relative to the photo.
    @Test func referenceRectKeepsPointAndDistanceOnPortraitPhotoAcrossRotation() throws {
        let savedSize = RenderTargetSize
        defer { RenderTargetSize = savedSize }
        let filter = try #require(PGLSourceFilter(filter: "CIEightfoldReflectedTile"))
        let center = try #require(filter.attribute(nameKey: kCIInputCenterKey) as? PGLFilterAttributeVector)
        let width = try #require(filter.attribute(nameKey: kCIInputWidthKey) as? PGLFilterAttributeNumber)
        center.set(CIVector(x: 617.47, y: 363.71))
        width.set(NSNumber(value: 100.0))

        // the logged photo rects - PGLCenterScaler aspect-fit in each orientation
        let cases: [(render: CGSize, photo: CGRect)] = [
            (CGSize(width: 1179, height: 1604), CGRect(x: 24, y: 0, width: 1132, height: 1604)),
            (CGSize(width: 1542, height: 1179), CGRect(x: 355, y: 0, width: 832.06, height: 1179)),
        ]
        var relativeCenters = [CGPoint]()
        var relativeWidths = [Double]()
        for aCase in cases {
            RenderTargetSize = aCase.render
            let photoImage = CIImage(color: .red).cropped(to: aCase.photo)
            let photo = photoImage.extent // cropped(to:) rounds out to whole pixels
            filter.setImageValue(newValue: photoImage, keyName: kCIInputImageKey)
            #expect(filter.parmReferenceRect() == photo)
            let mapping = filter.parmMapping()
            center.applyMapping(mapping)
            width.applyMapping(mapping)
            let renderCenter = try #require(filter.localFilter.value(forKey: kCIInputCenterKey) as? CIVector)
            let renderWidth = try #require(filter.localFilter.value(forKey: kCIInputWidthKey) as? NSNumber).doubleValue
            relativeCenters.append(CGPoint(x: (renderCenter.x - photo.minX) / photo.width,
                                           y: (renderCenter.y - photo.minY) / photo.height))
            relativeWidths.append(renderWidth / photo.width)
        }
        #expect(abs(relativeCenters[0].x - relativeCenters[1].x) < 0.0001)
        #expect(abs(relativeCenters[0].y - relativeCenters[1].y) < 0.0001)
        #expect(abs(relativeWidths[0] - relativeWidths[1]) < 0.0001)
        // the canvas values used by the slider, marker and storage are unchanged
        #expect(center.getVectorValue()?.x == 617.47)
        #expect(width.getNumberValue()?.doubleValue == 100.0)
    }

    /// A transition blends the input and target rects by inputTime. The image swaps happen
    /// where that image's weight is zero, so the blended rect does not jump at a swap.
    @Test func transitionReferenceRectBlendsByTime() throws {
        let savedSize = RenderTargetSize
        defer { RenderTargetSize = savedSize }
        RenderTargetSize = CGSize(width: 1542, height: 1179)
        let dissolve = try #require(PGLSourceFilter(filter: "CIDissolveTransition"))
        let portrait = CGRect(x: 355, y: 0, width: 833, height: 1179)
        let landscape = CGRect(x: 0, y: 11, width: 1542, height: 1156)
        dissolve.setImageValue(newValue: CIImage(color: .red).cropped(to: portrait), keyName: kCIInputImageKey)
        dissolve.setImageValue(newValue: CIImage(color: .blue).cropped(to: landscape), keyName: kCIInputTargetImageKey)

        dissolve.localFilter.setValue(0.0, forKey: kCIInputTimeKey)
        #expect(dissolve.parmReferenceRect() == portrait)
        dissolve.localFilter.setValue(1.0, forKey: kCIInputTimeKey)
        #expect(dissolve.parmReferenceRect() == landscape)
        dissolve.localFilter.setValue(0.5, forKey: kCIInputTimeKey)
        let middle = try #require(dissolve.parmReferenceRect())
        #expect(abs(middle.minX - 177.5) < 0.001)
        #expect(abs(middle.width - 1187.5) < 0.001)

        // at time 1 the hidden input swaps to a different shape - the rect must not move
        dissolve.localFilter.setValue(1.0, forKey: kCIInputTimeKey)
        let beforeSwap = dissolve.parmReferenceRect()
        dissolve.setImageValue(newValue: CIImage(color: .green).cropped(to: CGRect(x: 400, y: 0, width: 700, height: 1179)), keyName: kCIInputImageKey)
        #expect(dissolve.parmReferenceRect() == beforeSwap)
    }

    /// Generators and infinite inputs have no reference rect - the mapping falls back to
    /// the R297 aspect-fit of the canvas in the render size.
    @Test func noReferenceRectFallsBackToViewFit() throws {
        let savedSize = RenderTargetSize
        defer { RenderTargetSize = savedSize }
        RenderTargetSize = CGSize(width: 1179, height: 1604)
        let tile = try #require(PGLSourceFilter(filter: "CIEightfoldReflectedTile"))
        tile.setImageValue(newValue: CIImage(color: .red), keyName: kCIInputImageKey) // infinite extent
        #expect(tile.parmReferenceRect() == nil)
        let vector = CIVector(x: 300, y: 200)
        #expect(tile.parmMapping().toRender(vector) == vector.fittedFromCanvas(toRenderSize: RenderTargetSize))

        // a chained input takes the prior filter's reference explicitly
        let priorRect = CGRect(x: 24, y: 0, width: 1132, height: 1604)
        tile.setImageReferenceRect(priorRect, forKey: kCIInputImageKey)
        #expect(tile.parmReferenceRect() == priorRect)

        let generator = try #require(PGLSourceFilter(filter: "CICheckerboardGenerator"))
        #expect(generator.parmReferenceRect() == nil)
    }

    /// A tile filter's output is infinite - the next filter in the stack takes the tile's
    /// reference (the photo rect), not the cropped extent of the tile output.
    @Test func stackChainPassesReferenceThroughInfiniteOutput() throws {
        let savedSize = RenderTargetSize
        defer { RenderTargetSize = savedSize }
        RenderTargetSize = CGSize(width: 1542, height: 1179)
        let photoImage = CIImage(color: .red).cropped(to: CGRect(x: 355, y: 0, width: 833, height: 1179))

        let tile = try #require(PGLSourceFilter(filter: "CIEightfoldReflectedTile"))
        tile.setImageValue(newValue: photoImage, keyName: kCIInputImageKey)
        tile.setInputImageParmState(newState: ParmInputState.inputPhoto)
        let twirl = try #require(PGLSourceFilter(filter: "CITwirlDistortion"))
        twirl.setInputImageParmState(newState: ParmInputState.inputPriorFilter)

        let stack = PGLFilterStack()
        stack.append(tile)
        stack.append(twirl)
        _ = stack.stackOutputImage(false)

        #expect(twirl.imageReferenceRects[kCIInputImageKey] == photoImage.extent)
        #expect(stack.outputReferenceRect == photoImage.extent)
    }

    // MARK: rectangle parms

    /// Defaults come from the filter's own CIAttributeDefault: the unbounded CICrop default and
    /// the reduction filters show the whole image; a zero default (CIClamp) gets the R239.0 inset
    /// of 200 render pixels so the first display shows output.
    @Test func rectangleDefaultsFollowTheFilterDefault() throws {
        let savedSize = RenderTargetSize
        defer { RenderTargetSize = savedSize }
        RenderTargetSize = CGSize(width: 1179, height: 1604)
        let wholeCanvas = CGRect(origin: .zero, size: FilterCanvasSize)

        let average = try #require(PGLSourceFilter(filter: "CIAreaAverage"))
        let averageExtent = try #require(average.attribute(nameKey: kCIInputExtentKey) as? PGLAttributeRectangle)
        #expect(averageExtent.canvasRect == wholeCanvas)

        let crop = try #require(PGLFilterDescriptor("CICrop", PGLRectangleFilter.self)?.pglSourceFilter())
        let cropRect = try #require(crop.attribute(nameKey: "inputRectangle") as? PGLAttributeRectangle)
        #expect(cropRect.canvasRect == wholeCanvas)

        let clamp = try #require(PGLFilterDescriptor("CIClamp", PGLRectangleFilter.self)?.pglSourceFilter())
        let clampExtent = try #require(clamp.attribute(nameKey: kCIInputExtentKey) as? PGLAttributeRectangle)
        let insetX = FilterCanvasSize.width * 200 / RenderTargetSize.width
        let insetY = FilterCanvasSize.height * 200 / RenderTargetSize.height
        let expected = wholeCanvas.insetBy(dx: insetX, dy: insetY)
        #expect(abs(clampExtent.canvasRect.minX - expected.minX) < 0.001)
        #expect(abs(clampExtent.canvasRect.minY - expected.minY) < 0.001)
        #expect(abs(clampExtent.canvasRect.width - expected.width) < 0.001)
        #expect(abs(clampExtent.canvasRect.height - expected.height) < 0.001)
    }

    /// While the overlay is open a crop shows its uncropped input, unscaled, and passes the
    /// input's reference on; when editing ends it crops and zooms again.
    @Test func cropShowsUncroppedInputWhileEditing() throws {
        let savedSize = RenderTargetSize
        defer { RenderTargetSize = savedSize }
        RenderTargetSize = CGSize(width: 1179, height: 1604)
        let photoImage = CIImage(color: .red).cropped(to: CGRect(x: 137, y: 0, width: 905, height: 1604))
        let crop = try #require(PGLFilterDescriptor("CICrop", PGLRectangleFilter.self)?.pglSourceFilter() as? PGLRectangleFilter)
        crop.setImageValue(newValue: photoImage, keyName: kCIInputImageKey)
        crop.setInputImageParmState(newState: ParmInputState.inputPhoto)
        let cropRect = try #require(crop.attribute(nameKey: "inputRectangle") as? PGLAttributeRectangle)
        cropRect.canvasRect = CGRect(x: 300, y: 200, width: 300, height: 400)
        let stackRect = CGRect(origin: .zero, size: RenderTargetSize)

        crop.isEditingRect = true
        let editingOutput = try #require(crop.outputImage())
        #expect(editingOutput.extent == photoImage.extent)
        let editingScaled = crop.scaleOutput(ciOutput: editingOutput, stackCropRect: stackRect)
        #expect(editingScaled.extent == photoImage.extent)
        #expect(crop.outputReferenceRect() == photoImage.extent)

        crop.isEditingRect = false
        let croppedOutput = try #require(crop.outputImage())
        let renderCrop = try #require(crop.localFilter.value(forKey: "inputRectangle") as? CIVector).cgRectValue
        #expect(croppedOutput.extent.width < photoImage.extent.width)
        #expect(abs(croppedOutput.extent.width - renderCrop.width) < 1.0)
        _ = crop.scaleOutput(ciOutput: croppedOutput, stackCropRect: stackRect)
        #expect(crop.scaledOutputRect != nil)
    }

    /// Mask and the generators edit in their own output space - no pass-through.
    @Test func maskAndGeneratorDoNotPassInputWhileEditing() throws {
        let mask = try #require(PGLFilterDescriptor("CICrop", PGLMaskFilter.self)?.pglSourceFilter() as? PGLRectangleFilter)
        mask.isEditingRect = true
        #expect(!mask.isShowingInputForEditing())
        let generator = try #require(PGLFilterDescriptor("CIRoundedRectangleGenerator", PGLRectangleGenerator.self)?.pglSourceFilter() as? PGLRectangleFilter)
        generator.isEditingRect = true
        #expect(!generator.isShowingInputForEditing())
    }

    /// A crop committed in portrait keeps the same region of a portrait photo in landscape.
    @Test func rectangleFollowsPhotoAcrossRotation() throws {
        let savedSize = RenderTargetSize
        defer { RenderTargetSize = savedSize }
        let crop = try #require(PGLSourceFilter(filter: "CICrop"))
        let cropRect = try #require(crop.attribute(nameKey: "inputRectangle") as? PGLAttributeRectangle)

        RenderTargetSize = CGSize(width: 1179, height: 1604)
        let portraitPhoto = CIImage(color: .red).cropped(to: CGRect(x: 24, y: 0, width: 1132, height: 1604))
        crop.setImageValue(newValue: portraitPhoto, keyName: kCIInputImageKey)
        // the overlay OK action commits a render-pixel rect
        let committed = CGRect(x: 300, y: 400, width: 500, height: 600)
        cropRect.applyCropRect(mappedCropRect: committed)
        let portraitRender = try #require(crop.localFilter.value(forKey: "inputRectangle") as? CIVector).cgRectValue
        #expect(abs(portraitRender.minX - committed.minX) < 0.001)
        #expect(abs(portraitRender.width - committed.width) < 0.001)

        RenderTargetSize = CGSize(width: 1542, height: 1179)
        let landscapePhoto = CIImage(color: .red).cropped(to: CGRect(x: 355, y: 0, width: 833, height: 1179))
        crop.setImageValue(newValue: landscapePhoto, keyName: kCIInputImageKey)
        cropRect.applyMapping(crop.parmMapping())
        let landscapeRender = try #require(crop.localFilter.value(forKey: "inputRectangle") as? CIVector).cgRectValue

        func relative(_ rect: CGRect, in photo: CGRect) -> CGRect {
            CGRect(x: (rect.minX - photo.minX) / photo.width, y: (rect.minY - photo.minY) / photo.height,
                   width: rect.width / photo.width, height: rect.height / photo.height)
        }
        let before = relative(portraitRender, in: portraitPhoto.extent)
        let after = relative(landscapeRender, in: landscapePhoto.extent)
        #expect(abs(before.minX - after.minX) < 0.0001)
        #expect(abs(before.minY - after.minY) < 0.0001)
        #expect(abs(before.width - after.width) < 0.0001)
        #expect(abs(before.height - after.height) < 0.0001)
    }

    @Test func rectangleCancelRestoresPreviousRect() throws {
        let crop = try #require(PGLSourceFilter(filter: "CICrop"))
        let cropRect = try #require(crop.attribute(nameKey: "inputRectangle") as? PGLAttributeRectangle)
        let original = cropRect.canvasRect
        cropRect.applyCropRect(mappedCropRect: CGRect(x: 10, y: 20, width: 30, height: 40))
        #expect(cropRect.canvasRect != original)
        cropRect.restoreOldValue()
        #expect(cropRect.canvasRect == original)
    }

    /// The overlay frame is the committed rect drawn through the mapping (view points, y-down),
    /// and committing that same frame back gives the same canvas rect.
    @Test func rectangleOverlayViewRectRoundTrips() {
        let renderSize = CGSize(width: 1542, height: 1179)
        let viewSize = CGSize(width: 514, height: 393) // 3x drawable
        let canvas = CGRect(x: 100, y: 150, width: 400, height: 300)
        for referenceRect in [CGRect(x: 355, y: 0, width: 833, height: 1179), nil] {
            let mapping = PGLParmMapping(referenceRect: referenceRect, renderSize: renderSize, aspectFill: false)
            let viewRect = mapping.viewRect(for: canvas, viewSize: viewSize)
            let backToCanvas = mapping.canvasRect(for: viewRect, viewSize: viewSize)
            #expect(abs(backToCanvas.minX - canvas.minX) < 0.001)
            #expect(abs(backToCanvas.minY - canvas.minY) < 0.001)
            #expect(abs(backToCanvas.width - canvas.width) < 0.001)
            #expect(abs(backToCanvas.height - canvas.height) < 0.001)
        }
        // with a reference rect the overlay sits over the rendered rect: render / 3, y flipped
        let mapping = PGLParmMapping(referenceRect: CGRect(x: 355, y: 0, width: 833, height: 1179), renderSize: renderSize, aspectFill: false)
        let renderRect = mapping.toRender(CIVector(cgRect: canvas)).cgRectValue
        let viewRect = mapping.viewRect(for: canvas, viewSize: viewSize)
        #expect(abs(viewRect.minX - renderRect.minX / 3) < 0.001)
        #expect(abs(viewRect.minY - (viewSize.height - renderRect.maxY / 3)) < 0.001)
        #expect(abs(viewRect.width - renderRect.width / 3) < 0.001)
    }

    /// A drag ends as a pending edit (shown, not applied); OK commits it; Cancel drops it.
    @Test func rectanglePendingEditCommitAndCancel() throws {
        let crop = try #require(PGLSourceFilter(filter: "CICrop"))
        let cropRect = try #require(crop.attribute(nameKey: "inputRectangle") as? PGLAttributeRectangle)
        let viewSize = CGSize(width: 393, height: 534.67)
        let original = cropRect.canvasRect

        let dragged = CGRect(x: 50, y: 60, width: 200, height: 150)
        cropRect.setPendingOverlay(viewRect: dragged, viewSize: viewSize)
        #expect(cropRect.canvasRect == original) // not applied before OK
        let shown = cropRect.overlayViewRect(viewSize: viewSize)
        #expect(abs(shown.minX - dragged.minX) < 0.001)
        #expect(abs(shown.height - dragged.height) < 0.001)

        cropRect.commitOverlay(viewRect: shown, viewSize: viewSize)
        #expect(cropRect.pendingCanvasRect == nil)
        #expect(cropRect.canvasRect != original)

        cropRect.restoreOldValue()
        #expect(cropRect.canvasRect == original)
    }

    /// The crop output is zoomed to fit the render area (uniform scale, centered), and the next
    /// filter maps its parms onto that drawn rect.
    @Test func cropOutputZoomsToFitAndPassesItsDrawnRect() throws {
        let savedSize = RenderTargetSize
        defer { RenderTargetSize = savedSize }
        RenderTargetSize = CGSize(width: 1542, height: 1179)
        let photoImage = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 11, width: 1542, height: 1156))

        // the app builds CICrop through its descriptor with the mapped PGLRectangleFilter class
        let crop = try #require(PGLFilterDescriptor("CICrop", PGLRectangleFilter.self)?.pglSourceFilter() as? PGLRectangleFilter)
        crop.setImageValue(newValue: photoImage, keyName: kCIInputImageKey)
        crop.setInputImageParmState(newState: ParmInputState.inputPhoto)
        let cropRect = try #require(crop.attribute(nameKey: "inputRectangle") as? PGLAttributeRectangle)
        cropRect.canvasRect = CGRect(x: 200, y: 100, width: 300, height: 400) // a tall crop
        let twirl = try #require(PGLSourceFilter(filter: "CITwirlDistortion"))
        twirl.setInputImageParmState(newState: ParmInputState.inputPriorFilter)

        let stack = PGLFilterStack()
        stack.append(crop)
        stack.append(twirl)
        _ = stack.stackOutputImage(false)

        let drawn = try #require(crop.scaledOutputRect)
        let cropRender = try #require(crop.localFilter.value(forKey: "inputRectangle") as? CIVector).cgRectValue
        if PGLRectangleFilter.outputScaling == .zoomToFit {
            // same shape as the crop, fills the height, centered across the width
            #expect(abs(drawn.width / drawn.height - cropRender.width / cropRender.height) < 0.001)
            #expect(abs(drawn.height - RenderTargetSize.height) < 0.001)
            #expect(abs(drawn.midX - RenderTargetSize.width / 2) < 0.001)
        } else {
            #expect(drawn == CGRect(origin: .zero, size: RenderTargetSize))
        }
        #expect(twirl.imageReferenceRects[kCIInputImageKey] == drawn)
        #expect(crop.outputReferenceRect() == drawn)
        #expect(crop.parmReferenceRect() == photoImage.extent) // the crop rect itself maps onto the photo
    }

    /// storeParmValue writes canvas stretched to RenderTargetSize; load sets that rect and
    /// resizeFrom(savedSize: globalSize) stretches it back to canvas units.
    @Test func rectangleStoredValueRoundTrips() throws {
        let crop = try #require(PGLSourceFilter(filter: "CICrop"))
        let cropRect = try #require(crop.attribute(nameKey: "inputRectangle") as? PGLAttributeRectangle)
        let canvas = CGRect(x: 100, y: 150, width: 400, height: 300)
        for saveSize in renderSizes {
            let stored = CIVector(cgRect: canvas).scaledFromCanvas(toRenderSize: saveSize).cgRectValue
            cropRect.canvasRect = stored
            cropRect.resizeFrom(savedSize: saveSize)
            #expect(abs(cropRect.canvasRect.minX - canvas.minX) < 0.001)
            #expect(abs(cropRect.canvasRect.minY - canvas.minY) < 0.001)
            #expect(abs(cropRect.canvasRect.width - canvas.width) < 0.001)
            #expect(abs(cropRect.canvasRect.height - canvas.height) < 0.001)
        }
    }

    /// The position marker sits where the filter renders the point - the view point is the
    /// render point scaled to view points (y flipped) - and a drag maps back exactly.
    @Test func markerViewPointMatchesRenderedPointWithReferenceRect() {
        let renderSize = CGSize(width: 1542, height: 1179)
        let viewSize = CGSize(width: 514, height: 393) // 3x drawable
        let mapping = PGLParmMapping(referenceRect: CGRect(x: 355, y: 0, width: 833, height: 1179),
                                     renderSize: renderSize, aspectFill: false)
        let vector = CIVector(x: 617.47, y: 363.71)
        let renderPoint = mapping.toRender(vector)
        let viewPoint = mapping.viewPoint(for: vector, viewSize: viewSize)
        #expect(abs(viewPoint.x - renderPoint.x / 3) < 0.001)
        #expect(abs(viewPoint.y - (viewSize.height - renderPoint.y / 3)) < 0.001)

        let backToCanvas = mapping.canvasVector(for: viewPoint, viewSize: viewSize)
        #expect(abs(backToCanvas.x - vector.x) < 0.001)
        #expect(abs(backToCanvas.y - vector.y) < 0.001)
    }

    /// without a reference rect the marker keeps the R297 view fit
    @Test func markerViewPointFallsBackToViewFit() {
        let viewSize = CGSize(width: 393, height: 534.67)
        let mapping = PGLParmMapping(referenceRect: nil, renderSize: CGSize(width: 1179, height: 1604), aspectFill: false)
        let vector = CIVector(x: 436.4, y: 300.4)
        #expect(mapping.viewPoint(for: vector, viewSize: viewSize) == canvasVectorToViewPoint(vector, viewSize: viewSize))
        let point = CGPoint(x: 164.9, y: 298.9)
        #expect(mapping.canvasVector(for: point, viewSize: viewSize) == viewPointToCanvasVector(point, viewSize: viewSize))
    }

    @Test func viewRectRoundTrip() {
        for viewSize in renderSizes {
            let rect = CGRect(x: 100, y: 150, width: 300, height: 200)
            let viewRect = canvasRectToViewRect(rect, viewSize: viewSize)
            let backToCanvas = viewRectToCanvasRect(viewRect, viewSize: viewSize)
            #expect(abs(backToCanvas.origin.x - rect.origin.x) < 0.001)
            #expect(abs(backToCanvas.origin.y - rect.origin.y) < 0.001)
            #expect(abs(backToCanvas.width - rect.width) < 0.001)
            #expect(abs(backToCanvas.height - rect.height) < 0.001)
        }
    }

    @Test func viewPointRoundTrip() {
        for viewSize in renderSizes {
            let vector = CIVector(x: 200, y: 300)
            let point = canvasVectorToViewPoint(vector, viewSize: viewSize)
            let backToVector = viewPointToCanvasVector(point, viewSize: viewSize)
            #expect(abs(backToVector.x - vector.x) < 0.001)
            #expect(abs(backToVector.y - vector.y) < 0.001)
        }
    }

    @Test func viewPointMappingIsIndependentOfRenderTargetSize() {
        // the whole point of the redesign: marker placement must not depend on the live,
        // mutable RenderTargetSize global - only on the view's own size.
        let vector = CIVector(x: 400, y: 500)
        let viewSize = CGSize(width: 402, height: 874)

        RenderTargetSize = CGSize(width: 1206, height: 1195)
        let firstPoint = canvasVectorToViewPoint(vector, viewSize: viewSize)

        RenderTargetSize = CGSize(width: 1206, height: 2622)
        let secondPoint = canvasVectorToViewPoint(vector, viewSize: viewSize)

        #expect(firstPoint == secondPoint)
    }

    @Test func threeComponentVectorPreservesAndScalesZ() {
        let vector = CIVector(x: 100, y: 200, z: 50)
        let renderSize = CGSize(width: FilterCanvasSize.width * 2, height: FilterCanvasSize.height * 3)
        let rendered = vector.scaledFromCanvas(toRenderSize: renderSize)
        #expect(rendered.count == 3)
        #expect(abs(rendered.x - 200) < 0.001)
        #expect(abs(rendered.y - 600) < 0.001)
        // z is a radius/distance - scaled by the x-axis factor (sx=2), not dropped
        #expect(abs(rendered.z - 100) < 0.001)
    }

    @Test func fourComponentRectScalesOriginAndSize() {
        let rect = CGRect(x: 10, y: 20, width: 100, height: 50)
        let vector = CIVector(cgRect: rect)
        let renderSize = CGSize(width: FilterCanvasSize.width * 2, height: FilterCanvasSize.height * 2)
        let rendered = vector.scaledFromCanvas(toRenderSize: renderSize)
        let renderedRect = rendered.cgRectValue
        #expect(abs(renderedRect.origin.x - 20) < 0.001)
        #expect(abs(renderedRect.origin.y - 40) < 0.001)
        #expect(abs(renderedRect.width - 200) < 0.001)
        #expect(abs(renderedRect.height - 100) < 0.001)
    }

    @Test func civectorApplyingPreservesThirdComponent() {
        // regression test for the bug where CIVector.applying(_:) silently dropped z
        // for 3-component vectors during the CoreData legacy-resize path.
        let vector = CIVector(x: 10, y: 20, z: 5)
        let transform = CGAffineTransform(scaleX: 2, y: 3)
        let result = vector.applying(transform)
        #expect(result.count == 3)
        #expect(abs(result.x - 20) < 0.001)
        #expect(abs(result.y - 60) < 0.001)
        #expect(abs(result.z - 10) < 0.001) // min(2,3) == 2
    }

    @Test func resizeStoredTransformIsIdentityWhenSavedSizeMatchesDestination() {
        let anyAttribute = PGLSourceFilter(filter: "CIPerspectiveCorrection")!.attributes[0]
        let transform = anyAttribute.resizeStoredTransform(FilterCanvasSize, destination: FilterCanvasSize)
        #expect(transform.isIdentity)
    }

    @Test func resizeStoredTransformIsIdentityForZeroOrNilSavedSize() {
        let anyAttribute = PGLSourceFilter(filter: "CIPerspectiveCorrection")!.attributes[0]
        #expect(anyAttribute.resizeStoredTransform(nil).isIdentity)
        #expect(anyAttribute.resizeStoredTransform(.zero).isIdentity)
    }

    @Test func perspectiveCorrectionDefaultsAreCanvasRelativeAndStable() {
        // the reported bug: default corner values must not depend on RenderTargetSize.
        RenderTargetSize = CGSize(width: 1206, height: 1195)
        let firstFilter = PGLSourceFilter(filter: "CIPerspectiveCorrection")!
        let firstTopLeft = firstFilter.attribute(nameKey: "inputTopLeft")?.getVectorValue()

        RenderTargetSize = CGSize(width: 1206, height: 2622)
        let secondFilter = PGLSourceFilter(filter: "CIPerspectiveCorrection")!
        let secondTopLeft = secondFilter.attribute(nameKey: "inputTopLeft")?.getVectorValue()

        #expect(firstTopLeft != nil)
        #expect(secondTopLeft != nil)
        #expect(firstTopLeft?.x == secondTopLeft?.x)
        #expect(firstTopLeft?.y == secondTopLeft?.y)
    }

    @Test func applyMappingIsIdempotentAndOrderIndependent() {
        let filter = PGLSourceFilter(filter: "CIPerspectiveCorrection")!
        let attribute = filter.attribute(nameKey: "inputTopLeft") as! PGLFilterAttributeVector
        let canonicalBefore = attribute.getVectorValue()

        let sizeA = CGSize(width: 1206, height: 1195)
        let sizeB = CGSize(width: 1206, height: 2622)

        let mappingA = PGLParmMapping(referenceRect: nil, renderSize: sizeA, aspectFill: false)
        let mappingB = PGLParmMapping(referenceRect: CGRect(x: 24, y: 0, width: 1132, height: 1604), renderSize: sizeB, aspectFill: false)
        attribute.applyMapping(mappingA)
        attribute.applyMapping(mappingB)
        attribute.applyMapping(mappingA)
        attribute.applyMapping(mappingA) // repeat - must not double-apply

        let canonicalAfter = attribute.getVectorValue()
        #expect(canonicalAfter?.x == canonicalBefore?.x)
        #expect(canonicalAfter?.y == canonicalBefore?.y)
    }

    @Test func vector3RoundTripsFullXYZThroughCoreData() throws {
        // Regression test for: CDAttributeVector3 only ever persisted z (via the
        // separately-stored zValue) because storeParmValue read x/y from `startPoint`,
        // which is nil outside the vary/animation flow. setStoredValueToAttribute then
        // bailed out entirely (dropping z too) whenever x/y were missing.
        let container = try PGLInMemoryStore.makeContainer(name: "PGLCanvasSpaceTests")
        let moContext = container.viewContext

        let filter = try #require(PGLSourceFilter(filter: "CISpotLight"))
        let attribute = try #require(filter.attribute(nameKey: "inputLightPosition") as? PGLFilterAttributeVector3)

        let savedRenderSize = CGSize(width: 1179, height: 2556)
        RenderTargetSize = savedRenderSize
        attribute.set3ValueVector(CIVector(x: 436.4, y: 300.4), newZValue: 187.675)
        let canonicalBefore = try #require(attribute.getVectorValue())

        attribute.storeParmValue(moContext: moContext)
        let stored = try #require(attribute.storedParmValue as? CDAttributeVector3)

        // storeParmValue must have written all three components, not just z.
        #expect(stored.vectorX != nil)
        #expect(stored.vectorY != nil)

        // Reload into a fresh attribute instance, simulating a later app launch where
        // RenderTargetSize has changed since the save.
        RenderTargetSize = CGSize(width: 800, height: 1200)
        let freshFilter = try #require(PGLSourceFilter(filter: "CISpotLight"))
        let freshAttribute = try #require(freshFilter.attribute(nameKey: "inputLightPosition") as? PGLFilterAttributeVector3)
        freshAttribute.setStoredValueToAttribute(stored)
        freshAttribute.resizeFrom(savedSize: savedRenderSize)

        let canonicalAfter = try #require(freshAttribute.getVectorValue())
        #expect(abs(canonicalAfter.x - canonicalBefore.x) < 0.01)
        #expect(abs(canonicalAfter.y - canonicalBefore.y) < 0.01)
        #expect(abs(canonicalAfter.z - canonicalBefore.z) < 0.01)
    }

    @Test func vector3LegacySaveMissingXYStillRestoresZ() throws {
        // Regression test for the load-side half of the same bug: a record saved by the
        // old buggy code (or before this fix) with vectorX/vectorY nil must still restore z,
        // rather than the whole setStoredValueToAttribute bailing out and losing everything.
        let container = try PGLInMemoryStore.makeContainer(name: "PGLCanvasSpaceTests")
        let moContext = container.viewContext

        let legacyRecord = NSEntityDescription.insertNewObject(forEntityName: "CDAttributeVector3", into: moContext) as! CDAttributeVector3
        legacyRecord.vectorX = nil
        legacyRecord.vectorY = nil
        legacyRecord.vectorZ = 187.675

        let filter = try #require(PGLSourceFilter(filter: "CISpotLight"))
        let attribute = try #require(filter.attribute(nameKey: "inputLightPosition") as? PGLFilterAttributeVector3)
        let defaultXY = try #require(attribute.getVectorValue())

        attribute.setStoredValueToAttribute(legacyRecord)

        #expect(abs(attribute.zValue - 187.675) < 0.001) // vectorZ is a Float, so exact equality doesn't round-trip
        // x/y should fall back to whatever the attribute already had, not get zeroed out.
        let afterVector = try #require(attribute.getVectorValue())
        #expect(afterVector.x == defaultXY.x)
        #expect(afterVector.y == defaultXY.y)
    }

    @Test func scaleDownFrameCenterRoundTripsThroughCoreDataAsRegularFilter() throws {
        // Regression test for: PGLScaleDownFrame's centerPoint attribute (PGLFilterAttributeVectorUI)
        // overrides getVectorValue()/set() to delegate to centerPoint directly, bypassing
        // canvasVector entirely - so the base class's resizeFrom used to silently no-op on
        // load (it checked canvasVector, which this subclass never populates), leaving
        // centerPoint in stale live-space-at-save-time coordinates after a reload.
        let container = try PGLInMemoryStore.makeContainer(name: "PGLCanvasSpaceTests")
        let moContext = container.viewContext

        let descriptor = try #require(PGLFilterDescriptor("CILanczosScaleTransform", PGLScaleDownFrame.self))
        let filter = try #require(descriptor.pglSourceFilter() as? PGLScaleDownFrame)
        let attribute = try #require(filter.attribute(nameKey: kCIInputCenterKey) as? PGLFilterAttributeVectorUI)
        #expect(filter.workingSize == FilterCanvasSize) // regular attribute-UI role, not the internal zoom/pan role

        let savedRenderSize = CGSize(width: 2420, height: 1668)
        RenderTargetSize = savedRenderSize
        attribute.set(CIVector(x: 846.498, y: 157.928))
        let canonicalBefore = try #require(attribute.getVectorValue())

        attribute.storeParmValue(moContext: moContext)
        let stored = try #require(attribute.storedParmValue as? CDAttributeVector)

        RenderTargetSize = CGSize(width: 800, height: 1200)
        let freshDescriptor = try #require(PGLFilterDescriptor("CILanczosScaleTransform", PGLScaleDownFrame.self))
        let freshFilter = try #require(freshDescriptor.pglSourceFilter() as? PGLScaleDownFrame)
        let freshAttribute = try #require(freshFilter.attribute(nameKey: kCIInputCenterKey) as? PGLFilterAttributeVectorUI)
        freshAttribute.setStoredValueToAttribute(stored)
        freshAttribute.resizeFrom(savedSize: savedRenderSize)

        let canonicalAfter = try #require(freshAttribute.getVectorValue())
        #expect(abs(canonicalAfter.x - canonicalBefore.x) < 0.01)
        #expect(abs(canonicalAfter.y - canonicalBefore.y) < 0.01)
    }

    @Test func scaleDownFrameZoomPanRoleKeepsLiveCoordinates() {
        // The internal pinch-zoom/pan role (Renderer.outputZoomPanFilter) manipulates
        // centerPoint directly in live drawable-pixel coordinates and must NOT be converted -
        // workingSize kept in sync with RenderTargetSize makes that conversion an identity.
        RenderTargetSize = CGSize(width: 1206, height: 2622)
        let zoomFilter = PGLScaleDownFrame.initZoomPanFilter()
        zoomFilter.workingSize = RenderTargetSize
        let liveCenter = CGPoint(x: 500, y: 900)
        zoomFilter.centerPoint = liveCenter

        #expect(zoomFilter.workingSize == RenderTargetSize)
        #expect(zoomFilter.centerPoint == liveCenter)
    }
}
