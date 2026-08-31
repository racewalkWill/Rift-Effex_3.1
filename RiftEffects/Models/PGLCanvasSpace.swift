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

/// Per-axis stretch from `FilterCanvasSize` into `renderSize`. Both spaces share the same
/// lower-left origin (CoreImage LLO working rect), so no translate term is needed.
func canvasToRenderTransform(renderSize: CGSize) -> CGAffineTransform {
    guard FilterCanvasSize.width > 0, FilterCanvasSize.height > 0 else {
        return .identity
    }
    let sx = renderSize.width / FilterCanvasSize.width
    let sy = renderSize.height / FilterCanvasSize.height
    return CGAffineTransform(scaleX: sx, y: sy)
}

/// Inverse of `canvasToRenderTransform(renderSize:)`.
func renderToCanvasTransform(renderSize: CGSize) -> CGAffineTransform {
    guard renderSize.width > 0, renderSize.height > 0 else {
        return .identity
    }
    return canvasToRenderTransform(renderSize: renderSize).inverted()
}

extension CIVector {
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
/// y-down) - the on-screen center for a draggable position marker.
func canvasVectorToViewPoint(_ vector: CIVector, viewSize: CGSize) -> CGPoint {
    guard FilterCanvasSize.width > 0, FilterCanvasSize.height > 0 else {
        return .zero
    }
    let x = vector.x * viewSize.width / FilterCanvasSize.width
    let y = viewSize.height - (vector.y * viewSize.height / FilterCanvasSize.height)
    return CGPoint(x: x, y: y)
}

/// Inverse of `canvasVectorToViewPoint(_:viewSize:)` - maps a UIKit view point (e.g. where the
/// user dropped a drag gesture) back into canvas-space CIVector coordinates.
func viewPointToCanvasVector(_ point: CGPoint, viewSize: CGSize) -> CIVector {
    guard viewSize.width > 0, viewSize.height > 0 else {
        return CIVector(x: 0, y: 0)
    }
    let x = point.x * FilterCanvasSize.width / viewSize.width
    let flippedY = viewSize.height - point.y
    let y = flippedY * FilterCanvasSize.height / viewSize.height
    return CIVector(x: x, y: y)
}

/// Maps a canvas-space rect (LLO) to a UIKit view rect (ULO) for `viewSize`.
func canvasRectToViewRect(_ rect: CGRect, viewSize: CGSize) -> CGRect {
    guard FilterCanvasSize.width > 0, FilterCanvasSize.height > 0 else {
        return .zero
    }
    let sx = viewSize.width / FilterCanvasSize.width
    let sy = viewSize.height / FilterCanvasSize.height
    let x = rect.origin.x * sx
    let flippedY = viewSize.height - (rect.origin.y + rect.height) * sy
    return CGRect(x: x, y: flippedY, width: rect.width * sx, height: rect.height * sy)
}

/// Inverse of `canvasRectToViewRect(_:viewSize:)`.
func viewRectToCanvasRect(_ rect: CGRect, viewSize: CGSize) -> CGRect {
    guard viewSize.width > 0, viewSize.height > 0 else {
        return .zero
    }
    let sx = FilterCanvasSize.width / viewSize.width
    let sy = FilterCanvasSize.height / viewSize.height
    let flippedY = viewSize.height - (rect.origin.y + rect.height)
    return CGRect(x: rect.origin.x * sx, y: flippedY * sy, width: rect.width * sx, height: rect.height * sy)
}

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
