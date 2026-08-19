//
//  PGLGradientCornerAttribute.swift
//  RiftEffects
//
//  Created by Will on 8/16/26.
//  Copyright © 2026 Will Loew-Blosser. All rights reserved.
//

import Foundation
import CoreImage

// get/set one corner of the PGLTriangleGradientFilter polygon
// value not held in the ciFilter attribute - it is held in the parent filter's corners array

class PGLGradientCornerAttribute: PGLFilterAttributeVector {

    var cornerIndex = 0

    override func shouldSetDefaultVectorValue() -> Bool {
        return false
    }

    override func getVectorValue() -> CIVector? {
        if let myParent = self.aSourceFilter as? PGLTriangleGradientFilter {
            return CIVector(cgPoint: myParent.corners[cornerIndex])
        }
        else { return nil }
    }

    override func set(_ value: Any) {
        if attributeName != nil {
            if let newVectorValue = value as? CIVector {
                parmInputState = .inputValueSet
                aSourceFilter.setVectorValue(newValue: newVectorValue, keyName: attributeName!) }
        }
    }

    override func shouldHidePosition(userSelected: Bool) -> Bool {
        // always show the corner handle
        return false
    }
}
