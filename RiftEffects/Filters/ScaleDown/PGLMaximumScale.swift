//
//  PGLMaximumScale.swift
//  RiftEffects
//
//  Created by Will on 5/2/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//

import Foundation
import CoreImage
import simd
import UIKit
import os

/// set larger scale defaults, add centerPoint to CIMaximumScaleTransform
class PGLScaleUpFrame: PGLScaleDownFrame {

    override class func localizedDescription(filterName: String) -> String {
        // custom subclasses should override
       return NSLocalizedString("Enlarge & pan", comment: "Maximum Scale custom filter description")
    }

    override func setDefaults() {
        // change default of attribute key : "CIAttributeSliderMax"
       // from old value : 1.5 to 5
        if let scaleInputParm = attribute(nameKey: "inputScale")
            {
                scaleInputParm.sliderMaxValue = 10.0
                scaleInputParm.sliderMinValue = 0.1
            }
    }

}
