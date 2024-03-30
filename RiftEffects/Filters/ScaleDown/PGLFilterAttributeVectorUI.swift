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

    override func getVectorValue() -> CIVector? {
        if let myParent = self.aSourceFilter as? PGLCenterPoint {
                // PGLScaleDownFrame & PGLTriangleGradientFilter are current adopters of the protocol
            return CIVector(cgPoint: myParent.centerPoint )
        }
        else { return nil }


    }

    override func set(_ value: Any) {
        if attributeName != nil {
            if let newVectorValue = value as? CIVector {
                aSourceFilter.setVectorValue(newValue: newVectorValue, keyName: attributeName!) }
        }
    }
}
