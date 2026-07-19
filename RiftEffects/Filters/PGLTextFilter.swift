//
//  PGLTextFilter.swift
//  Glance
//
//  Created by Will on 6/19/20.
//  Copyright © 2020 Will. All rights reserved.
//

import Foundation
import CoreGraphics
import UIKit
import os

class PGLTextFilter: PGLSourceFilter {
    // super class for the text filters which have a
    // attribute answering isTextInputUI() true
        // CIAttributedTextImageGenerator inputText,
        // CIAztecCodeGenerator inputMessage
        // CICode128BarcodeGenerator  inputMessage
        // CIPDF417BarcodeGenerator  inputMessage
        // CIQRCodeGenerator  inputMessage 
        // CITextImageGenerator inputText

    // see the PGLCommonController methods for UITextFieldDelegate

}

class PGLQRCodeGenerator: PGLTextFilter {
    // the CIQRCodeGenerator does not have a defaults
    //  "CIQRCodeGenerator filter requires L, M, Q, or H for inputCorrectionLevel"

    static let inputCorrectionLevelSettings: [NSString] = ["L", "M", "Q", "H" ]

    required init?(filter: String, position: PGLFilterCategoryIndex) {
           super.init(filter: filter, position: position)
        let defaultCorrectionLevel = (PGLQRCodeGenerator.inputCorrectionLevelSettings[2])
        // default is "Q" 25% additional encoding size for error correction
        setStringValue(newValue: defaultCorrectionLevel, keyName: "inputCorrectionLevel")
           hasAnimation = false

    }

    override func setStringValue(newValue: NSString, keyName: String) {
        // convert to matching inputCorrectionLevel
        if keyName == "inputCorrectionLevel" {
            if PGLQRCodeGenerator.inputCorrectionLevelSettings.contains(newValue) {
                super.setStringValue(newValue: newValue, keyName: keyName)
            }
        }
    }
}

class PGLCIAztecCodeGenerator: PGLTextFilter {
    // filter attributes to match CIAztecCodeGenerator requirements

    override func setNumberValue(newValue: NSNumber, keyName: String) {
        switch keyName {
//          case "inputCorrectionLevel":
//                default case
            case "inputLayers" :
                if (newValue.floatValue <= 32.00) {
                    super.setNumberValue(newValue: newValue, keyName: keyName)
                } else {
                    super.setNumberValue(newValue: 0.0, keyName: keyName)
                }
            case "inputCompactStyle" :
                if (newValue.boolValue) {
                    // true case
                    super.setNumberValue(newValue: 1.0, keyName: keyName)
                } else {
                    // false case
                    super.setNumberValue(newValue: 0.0, keyName: keyName)
                }
            default:
                super.setNumberValue(newValue: newValue, keyName: keyName)
        }
    }
}



class PGLTextImageGenerator: PGLTextFilter {
    // overide defaults for Font Size and Scale Factor
    // adds a position parm for text positioning
    // uses CompositeTextPositionFilter and positions origin of the text 

    override class func displayName() -> String? {
        // for the older subclass override this displayname
        // currently there are two 'Blend Text in the Generator category..
        return NSLocalizedString("Blend Text", comment: "Blend Text filter display name")
    }

    override func setDefaults() {
        setVectorValue(newValue: CIVector(x: 300.0, y: 300.0), keyName: "inputTextPosition")

    }



}


