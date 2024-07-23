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
            case 2, 3 :
                // not sure what a 3 d transform looks like...
                let newPoint = self.cgPointValue.applying(transform)
                return CIVector(cgPoint: newPoint)
            case 4:
                let newRect = self.cgRectValue.applying(transform)
                return CIVector(cgRect: newRect)

            default :
                // special case. but no error
                return self

        }

    }

}


