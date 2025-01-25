//
//  PGLFilterAttributeTime.swift
//  RiftEffects
//
//  Created by Will on 1/24/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//

import UIKit

class PGLFilterAttributeTime: PGLFilterAttribute {
    // this attribute needs to send the slider set message
    // to the filter addStepTime.. in contrast to the vary logic which
    // uses the a frameCounter and frames per second to control the change in a
    // numeric or vector attribute

    let timeDivisor: Float = 25.0
    var uiSliderValue: Float = 0
        // a holder of the ui input for db store

    required init?(pglFilter: PGLSourceFilter, attributeDict: [String:Any], inputKey: String ) {
        super.init(pglFilter: pglFilter, attributeDict: attributeDict, inputKey: inputKey)
        sliderMaxValue = 10 // seconds per image
        sliderMinValue = 0.001 // seconds per image - this is 100 images/second
        defaultValue = 0.5

    }

    override func set(_ value: Any) {
        if let myNumber = value as? NSNumber {
           let newRate = myNumber.floatValue
                //simd_smoothstep is not called here
                // see addStepTime on the Transition filter
            uiSliderValue = newRate

            aSourceFilter.setTimerDt(lengthSeconds: newRate )
        }

    }

    override func getNumberValue() -> NSNumber? {
        return uiSliderValue as NSNumber
    }
    override func valueString() -> String {
        // remove obsolete?
        let parmNumber = getTimerDt() * timeDivisor

        return String(format: "%.03f", parmNumber)
    }

    override func cellAction() -> [PGLTableCellAction ] {
        return [PGLTableCellAction ]()  // no action on time
    }

    override func uiCellIdentifier() -> String {
        // change back to superclass answer if vary is needed
        // super class uses "parmNoDetailCell"
        return "parmNoDisclosureCell"
    }

    override  func setUICellDescription(_ uiCell: UITableViewCell) {
      var content = uiCell.defaultContentConfiguration()
      let newDescriptionString = self.attributeDisplayName ?? ""
      content.text = newDescriptionString
      content.imageProperties.tintColor = .secondaryLabel
        content.image = UIImage(systemName: "slider.horizontal.below.rectangle")

      uiCell.contentConfiguration = content

    }

}
