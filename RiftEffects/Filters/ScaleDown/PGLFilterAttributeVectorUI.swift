//
//  PGLFilterAttributeVectorUI.swift
//  RiftEffects
//
//  Created by Will on 12/5/23.
//  Copyright © 2023 Will Loew-Blosser. All rights reserved.
//

import Foundation
import UIKit
import os


// get/set vector point in the PGLSourceFilter..
// value not held in the ciFilter attribute

class PGLFilterAttributeVectorUI: PGLFilterAttributeVector {
    /// supports PGLTriangleGradientFilter & PGLScaleDownFrame

        /// PGLScaleDownFrame used to center and scale in the imageController
        /// do NOT set defaultVectorValue  - if true then fullscreen shifts image left, down and quarter size
    override func shouldSetDefaultVectorValue() -> Bool {
        /// PGLScaleDownFrame used to center and scale in the imageController
        /// do NOT set defaultVectorValue  - if true then fullscreen shifts image left, down and quarter size
        return false
    }

    override func getVectorValue() -> CIVector? {
        if let myParent = self.aSourceFilter as? (any PGLCenterPoint) {
                // PGLScaleDownFrame & PGLTriangleGradientFilter are current adopters of the protocol
            return CIVector(cgPoint: myParent.centerPoint )
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

// MARK: ViewControl hide/show

///  only display the positionControl if the parm is selected
///    parent default is to show all vectorAttributes
    override func shouldHidePosition(userSelected: Bool) -> Bool {
            // userSelected means should NOT HIDE
            return !userSelected
        }
}
