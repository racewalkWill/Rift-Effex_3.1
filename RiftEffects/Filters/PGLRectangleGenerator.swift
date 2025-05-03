//
//  PGLRectangleGenerator.swift
//  RiftEffects
//
//  Created by Will on 5/2/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//

import Foundation
import UIKit

class PGLRectangleGenerator: PGLRectangleFilter {

    /// in CIBlurredRectangleGenerator, CIRoundedRectangleGenerator

    override func setDefaults() {
        // rect does not show until default value is explictly set
        // should not need this but.. we do
        
        let extentKey = "inputExtent"
        if let inputExtentAttribute = attribute(nameKey: extentKey){

//            CIVector
//            Printing description of defaultValue:
//            [0 0 100 100]

            if let defaultValue = inputExtentAttribute.initDict["CIAttributeDefault"] as? CIVector {
                localFilter.setValue(defaultValue, forKey: extentKey)
            }
        } else {
            localFilter.setValue(CGRect(x: 100, y: 100, width: 300, height: 300), forKey: extentKey)
        }

    }

    override func scaleOutput(ciOutput: CIImage, stackCropRect: CGRect) -> CIImage {
        // no scaling for the generators
        
        return ciOutput
    }
}
