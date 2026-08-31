//
//  CIVector.swift
//  RiftEffects
//
//  Created by Will on 7/23/24.
//  Copyright © 2024 Will Loew-Blosser. All rights reserved.
//

import Foundation
import CoreImage
extension CIVector {

    func applying(_ transform: CGAffineTransform) -> CIVector {
        switch self.count {
            case 2 :
                let newPoint = self.cgPointValue.applying(transform)
                return CIVector(cgPoint: newPoint)
            case 3 :
                // z is a radius/distance, not a coordinate - scale it by the transform's
                // (assumed axis-aligned, non-rotated) x scale factor rather than dropping it.
                // Uses the x axis alone (not min(a,d)) so that applying a transform and then
                // its inverse round-trips exactly - see the comment on
                // CIVector.scaledFromCanvas(toRenderSize:) in PGLCanvasSpace.swift.
                let newPoint = self.cgPointValue.applying(transform)
                return CIVector(x: newPoint.x, y: newPoint.y, z: self.z * transform.a)
            case 4:
                let newRect = self.cgRectValue.applying(transform)
                return CIVector(cgRect: newRect)

            default :
                // special case. but no error
                return self

        }

    }

}


