//
//  PGLGradientWidthAttribute.swift
//  RiftEffects
//
//  Created by Will on 8/16/26.
//  Copyright © 2026 Will Loew-Blosser. All rights reserved.
//

import Foundation
import CoreImage

// get/set the shared edge width of the PGLTriangleGradientFilter polygon
// value not held in the ciFilter attribute - it is held on the parent filter as gradientWidth

class PGLGradientWidthAttribute: PGLFilterAttributeNumber {

    // PGLFilterAttributeNumber.valueString() force-casts getValue() as! Double,
    // so getValue() (not just getNumberValue()) must be overridden here.
    override func getValue() -> Any? {
        if let myParent = self.aSourceFilter as? PGLTriangleGradientFilter {
            return NSNumber(value: Double(myParent.gradientWidth))
        }
        else { return nil }
    }
}
