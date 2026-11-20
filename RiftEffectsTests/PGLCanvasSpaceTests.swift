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
        width.applyRenderSize(landscape)
        let landscapeValue = try #require(filter.localFilter.value(forKey: kCIInputWidthKey) as? NSNumber).doubleValue
        width.applyRenderSize(portrait)
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

    @Test func applyRenderSizeIsIdempotentAndOrderIndependent() {
        let filter = PGLSourceFilter(filter: "CIPerspectiveCorrection")!
        let attribute = filter.attribute(nameKey: "inputTopLeft") as! PGLFilterAttributeVector
        let canonicalBefore = attribute.getVectorValue()

        let sizeA = CGSize(width: 1206, height: 1195)
        let sizeB = CGSize(width: 1206, height: 2622)

        attribute.applyRenderSize(sizeA)
        attribute.applyRenderSize(sizeB)
        attribute.applyRenderSize(sizeA)
        attribute.applyRenderSize(sizeA) // repeat - must not double-apply

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
