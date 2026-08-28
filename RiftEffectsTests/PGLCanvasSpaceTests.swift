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
        // z is a radius/distance - scaled by min(sx,sy), not dropped and not axis-scaled
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
}
