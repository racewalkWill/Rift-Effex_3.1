//
//  PGLFilterAttributeColor.swift
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

class PGLFilterAttributeColor: PGLFilterAttribute {
    var colorSpace = CGColorSpace.genericRGBLinear
        //        kCGColorSpaceDeviceRGB or  CGColorSpace.displayP3

    var red: CGFloat = 0.0
    var green: CGFloat = 0.0
    var blue: CGFloat = 0.0
    var alpha: CGFloat = 0.0

    required init?(pglFilter: PGLSourceFilter, attributeDict: [String:Any], inputKey: String ) {
        super.init(pglFilter: pglFilter, attributeDict: attributeDict, inputKey: inputKey)
        if let thisFilterColor = getColorValue() {
            // how to determine the colorSpace of the filter color??
            // if it is different then the conversion to displayP3 or genericRGBLinear etc.. is needed
            red = thisFilterColor.red
            green = thisFilterColor.green
            blue = thisFilterColor.blue
            alpha = thisFilterColor.alpha
        }

    }


    override  func setUICellDescription(_ uiCell: UITableViewCell) {
      var content = uiCell.defaultContentConfiguration()
      let newDescriptionString = self.attributeDisplayName ?? ""
      content.text = newDescriptionString
      content.imageProperties.tintColor = .secondaryLabel
        content.image = UIImage(systemName: "slider.horizontal.3")

      uiCell.contentConfiguration = content

    }
    override func set(_ value: Any) {
            if let aColor = SliderColor(rawValue: uiIndexTag) {
                 let floatColor = CGFloat((value as? Float ?? 0.0))       //value as? CGFloat {
                setColor(color: aColor , newValue: floatColor )
                parmInputState = .inputValueSet

            }

    }
    
    func setColor(color: SliderColor, newValue: CGFloat) {
        let changedColor: CIColor?
        guard let rgbSpace = CGColorSpace(name: CGColorSpace.sRGB)
            else {
            return
        }
        if let oldColor = getColorValue() {
            switch color {
            case SliderColor.Red:
                    changedColor = CIColor(red: newValue, green: oldColor.green, blue: oldColor.blue, alpha: oldColor.alpha, colorSpace: rgbSpace)
            case SliderColor.Green:
                changedColor = CIColor(red: oldColor.red, green: newValue, blue: oldColor.blue, alpha: oldColor.alpha, colorSpace: rgbSpace)
            case SliderColor.Blue:
                changedColor = CIColor(red: oldColor.red, green: oldColor.green, blue: newValue, alpha: oldColor.alpha, colorSpace: rgbSpace)
            case SliderColor.Alpha:
                changedColor = CIColor(red: oldColor.red, green: oldColor.green, blue: oldColor.blue, alpha: newValue, colorSpace: rgbSpace)
            }
            if changedColor != nil {
                aSourceFilter.setColorValue(newValue: changedColor!, keyName: attributeName!)
            }

//            NSLog("PGLFilterAttribute setColor to \(changedColor)")
        }
    }

}
