//
//  PGLFilterAttributeNumber.swift
//  Glance
//
//  Created by Will on 4/1/19.
//  Copyright © 2019 Will. All rights reserved.
//

import Foundation

import UIKit
import Photos
import CoreImage

class PGLFilterAttributeNumber: PGLFilterAttribute {



    required init?(pglFilter: PGLSourceFilter, attributeDict: [String:Any], inputKey: String ) {
        super.init(pglFilter: pglFilter, attributeDict: attributeDict, inputKey: inputKey)


    }

    override func set(_ value: Any) {
         if attributeName != nil {
            if let myNumber = value as? NSNumber {
                aSourceFilter.setNumberValue(newValue: myNumber, keyName: attributeName!) }
        }
    }

    override func incrementValueDelta() {
        if let curentNumericValue =  self.getNumberValue() as? Float {

            // now increment value
            if  (attributeValueDelta != nil ){
                let newValue = curentNumericValue + attributeValueDelta!
//                NSLog("PGLFilterAttributeNumber incrementValueDelta didSet to newValue = \(newValue)")
               
                aSourceFilter.setNumberValue(newValue: newValue as NSNumber, keyName: attributeName!)
                postUIChange(attribute: self)
            }
        }
    }
    override func valueString() -> String {
        let parmNumber = getValue() as! Double
        // could use getNumberValue() to avoid a generic..
//        NSLog("PGLFilterAttributeNumber #valueString has value \(parmNumber)")
        return String(format: "%.03f", parmNumber)
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






