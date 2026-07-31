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

        if let myminValue = minValue, let mymaxValue = sliderMaxValue {
            let randomValue: Float =  Float.random(in: myminValue...mymaxValue)
            set(randomValue)
        }
    }
}

extension PGLFilterAttributeVector {
    @objc override func setRandomValue() {
        ///  pick a random value in the middle third of the minValue to arbitrary maxValue
        ///  maxValue is not difined.. sliderMaxValue may be defined
        ///  may use defaultValue if defined

        if defaultValue == nil {

            let maxWidth = TargetSize.width / 2
            let maxHeight = TargetSize.height / 2
            let randomValue: CGFloat = CGFloat.random(in: 0...maxWidth)
            let randomValue2: CGFloat = CGFloat.random(in: 0...maxHeight)
            let newRandom = CIVector(x: randomValue, y: randomValue2)
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




