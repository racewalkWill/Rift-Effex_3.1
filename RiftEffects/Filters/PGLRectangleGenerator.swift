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

    /// a generator has no input - the generated rect is what is edited
    override var showsInputWhileEditing: Bool {
        return false
    }

    /// in CIBlurredRectangleGenerator, CIRoundedRectangleGenerator

    override func setDefaults() {
        // rect does not show until default value is explictly set
        // should not need this but.. we do
        
        let extentKey = "inputExtent"
        if let extentAttribute = cropAttribute {
            // the PGLAttributeRectangle init has already resolved the initial rect
            // (saved value, or default inset rect for a zero or undefined vector default).
            // Apply it to the filter the same as the OK swipe action so the initial display uses it.
            // Setting the raw CIAttributeDefault here would overwrite that rect.
            extentAttribute.pushToFilter(mapping: extentAttribute.currentParmMapping())
        }
        else if let inputExtentAttribute = attribute(nameKey: extentKey){

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
