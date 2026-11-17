//
//  PGLRandomParms.swift
//  RiftEffects
//
//  Created by Will on 11/17/24.
//  Copyright © 2024 Will Loew-Blosser. All rights reserved.
//

import Foundation
import UIKit

extension PGLFilterAttribute {

    ///  Subclasses may override
    @objc func setRandomValue() {
        ///  pick a random value in the middle third of the minValue to arbitrary maxValue
        ///  maxValue is not difined.. sliderMaxValue may be defined
    }
}

extension PGLFilterAttributeNumber {
    @objc override func setRandomValue() {
        ///  pick a random value in the middle third of the minValue to arbitrary maxValue
        ///  maxValue is not difined.. sliderMaxValue may be defined
        ///  may use defaultValue if defined
        ///   set  in the middle range 20 % to 80% of the min to max
        if let definedMinValue = sliderMinValue, let definedMaxValue = sliderMaxValue
        {
            let valueRangeOffset = (definedMinValue - definedMinValue) / 5

                let randomValue: Float =  Float.random(in: (definedMinValue + valueRangeOffset)...(definedMaxValue - valueRangeOffset))
                set(randomValue)
            NSLog("PGLFilterAttributeNumber \(String(describing: myFilter)) \(String(describing: attributeName)) #setRandomValue = \(randomValue) ")
            }

        }
}

extension PGLFilterAttributeVector {
    @objc override func setRandomValue() {
        ///  pick a random value in the middle third of the minValue to arbitrary maxValue
        ///  maxValue is not difined.. sliderMaxValue may be defined
        ///  may use defaultValue if defined

        if defaultValue == nil {
            // to middle part
            let maxWidth = FilterCanvasSize.width * 0.85
            let maxHeight = FilterCanvasSize.height * 0.85
            let minWidth = maxWidth / 8
            let minHeight = maxHeight / 8
            let randomValue: CGFloat = CGFloat.random(in: minWidth...maxWidth)
            let randomValue2: CGFloat = CGFloat.random(in: minHeight...maxHeight)
            let newRandom = CIVector(x: randomValue, y: randomValue2)
            NSLog("PGLFilterAttributeVector \(String(describing: myFilter)) \(String(describing: attributeName)) #setRandomValue = \(newRandom) ")
            set(newRandom)
        }
        else { super.setRandomValue() }
        // place holder for modification
    }
}

extension PGLFilterAttributeAffine {
    @objc override func setRandomValue() {
        ///  pick a random value in the middle third of the minValue to arbitrary maxValue
        ///  maxValue is not difined.. sliderMaxValue may be defined
        ///  may use defaultValue if defined
        super.setRandomValue()
            // place holder for modification
    }
}

extension PGLFilterAttributeAngle {
    @objc override func setRandomValue() {
        ///  pick a random value in the middle third of the minValue to arbitrary maxValue
        ///  maxValue is not difined.. sliderMaxValue may be defined
        ///  may use defaultValue if defined
        super.setRandomValue()
            // place holder for modification
    }
}

extension PGLFilterAttributeTime {
    @objc override func setRandomValue() {
        ///  pick a random value in the middle third of the minValue to arbitrary maxValue
        ///  maxValue is not difined.. sliderMaxValue may be defined
        ///  may use defaultValue if defined
        ///   if let myminValue = minValue, let mymaxValue = sliderMaxValue {
        if let myminValue = minValue, let mymaxValue = sliderMaxValue {
            let randomValue: Float =  Float.random(in: myminValue...mymaxValue)
            set(randomValue)
        } else {
            super.setRandomValue()
                // place holder for modification
        }
    }
}




