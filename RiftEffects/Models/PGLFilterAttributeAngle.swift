//
//  PGLFilterAttributeAngle.swift
//  RiftEffects
//
//  Created by Will on 1/21/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//
import Foundation
import UIKit
import Photos
import CoreImage
import Accelerate
import os
import Combine

class PGLFilterAttributeAngle: PGLFilterAttribute {
    // attributeType = CIAttributeTypeAngle
    // attributeClass = NSNumber
    //  an angle in radians  presuming maxValue is 2Pi radians

    required init?(pglFilter: PGLSourceFilter, attributeDict: [String:Any], inputKey: String ) {
        super.init(pglFilter: pglFilter, attributeDict: attributeDict, inputKey: inputKey)
        // super.init already parsed sliderMinValue/sliderMaxValue from the filter's own
        // CIAttributeSliderMin/Max when the filter supplies them (e.g. CIVortexDistortion's
        // +/-30pi range). Only fall back to the 0...2pi assumption when the filter doesn't.
        if sliderMinValue == nil { sliderMinValue = 0.0 }
        if sliderMaxValue == nil { sliderMaxValue = 2 * Float.pi }
        minValue = sliderMinValue

    }

    override  func setUICellDescription(_ uiCell: UITableViewCell) {
      var content = uiCell.defaultContentConfiguration()
      let newDescriptionString = self.attributeDisplayName ?? ""
      content.text = newDescriptionString
      content.imageProperties.tintColor = .secondaryLabel
        content.image = UIImage(systemName: "slider.horizontal.below.rectangle")

      uiCell.contentConfiguration = content

    }
    
    override func set(_ value: Any) {
        if attributeName != nil { if let newNumber = value as? NSNumber {
            parmInputState = .inputValueSet
            aSourceFilter.setNumberValue(newValue: newNumber, keyName: attributeName!) }

        }
    }
  // this is in class PGLFilterAttributeAngle
    override func incrementValueDelta() {
        // animation time range 0.0 to 1.0
        // PGLFilterAttributeAngle has
            //attributeType = CIAttributeTypeAngle
            // attributeClass = NSNumber
            //  an angle in radians  presuming maxValue is 2Pi radians

        if !hasAnimation() {return }
        // get the current value and add the delta
        // then set into the filter
        // NSNumber may box a Double, so `as? Float` can fail even when a
        // value is present - use Float(truncating:) to convert unconditionally.
        let currentValue = Float(truncating: getNumberValue() ?? 0.0)

        let incrementValue = NSNumber ( value: currentValue + ( attributeValueDelta  ?? 0.0 ) )
        aSourceFilter.setNumberValue(newValue: incrementValue, keyName: attributeName!)
        postUIChange(attribute: self)


    }


  func hasSwipeAction() -> Bool {
        return true // subclasses override if they support timer or filter input actions

    }
}  // END class PGLFilterAttributeAngle
