//
//  PGL5SidedGradientFilter.swift
//  RiftEffects
//
//  Created by Will on 3/23/24.
//  Copyright © 2024 Will Loew-Blosser. All rights reserved.
//

import Foundation
import CoreImage
import simd
import UIKit
import os

let kGradientBlendFilter = "CIDarkenBlendMode"
let kGradientFilterName = "CILinearGradient"
let kGradientAttributePrefix = "linear"

/// 5 sided gradient
class PGLTriangleGradientFilter: PGLSourceFilter, PGLCenterPoint {
    /// 12 storable values  3 linear gradients with 4 values - 2 vectors & 2 colors
    /// attribute namings is linear#value#  example linear1value2
    /// value1 and value2 are vectors
    ///  value3 and value4 are colors

        /// UI index for the current linear gradient
    var indexGradient = 0
    var sideCount = 3
    var linearGradients =  [PGLSourceFilter]()
    var blendFilters = [CIFilter]()
    var valueParms = [PGLFilterAttribute]()
    var centerPoint: CGPoint = CGPoint(x: TargetSize.width/2, y: TargetSize.height/2)
//    var gradientKeys: [String:]

    required init?(filter: String, position: PGLFilterCategoryIndex) {

        // on UI select of a linear attribute then four subcells of 4 values
        super.init(filter: filter, position: position)
        attributes.append(self.centerPointAttribute() )
        for _ in 1 ..< sideCount {
            blendFilters.append(CIFilter(name: kGradientBlendFilter)! )
        }

        for index in 0 ..< sideCount  {

            // for the attributes in the ciFilter parm
            if let  childLinearFilter = PGLGradientChildFilter(filter: "CILinearGradient", position: PGLFilterCategoryIndex()) {
                childLinearFilter.parentFilter = self
                childLinearFilter.sideKey = index

                linearGradients.append(childLinearFilter)
                let vectorAttributes = childLinearFilter.attributes.filter( {$0.isVector() })

                for aVector in vectorAttributes {
                    /// set to form linear1.inputPoint0 etc..
                    ///  decoded back in  PGLGradienChildFilter setVectorValue...
                    aVector.attributeName = kGradientAttributePrefix + String(index) + String(kPGradientKeyDelimitor) + aVector.attributeName!
                    aVector.attributeDisplayName = "Side " + String(index + 1 ) + " " + aVector.attributeDisplayName!
                    }
                attributes.append(contentsOf: vectorAttributes )
                childLinearFilter.setDefaults()
            }
        }
//        hasAnimation = true
    }

    override class func localizedDescription(filterName: String) -> String {
        // custom subclasses should override
       return "Gradient with 5 sides"
    }

    func centerPointAttribute() -> PGLFilterAttributeVector {
        let inputDict: [String:Any] = [
            "CIAttributeIdentity" : [200, 200],
            "CIAttributeDefault" : [200, 200],
            "CIAttributeType" : kCIAttributeTypePosition,
            "CIAttributeDisplayName" : "Center" ,
            "kCIAttributeDescription": "Position of the frame",
            "CIAttributeClass":  "CIVector"
        ]
        let newVectorAttribute = PGLFilterAttributeVectorUI(pglFilter: self, attributeDict: inputDict, inputKey: kCIInputCenterKey)
        return newVectorAttribute!
    }


    override func outputImageBasic() -> CIImage? {
        //notice that .outputImage() is used for the linearGradients image return
        // BUT .outputImage is used for the blendFilter image return.. 
        // it's a bug in the filter code !!

        let linear0Image = linearGradients[0].outputImage()
        let linear1Image = linearGradients[1].outputImage()
        let linear2Image = linearGradients[2].outputImage()
        blendFilters[0].setValue(linear0Image, forKey: kCIInputImageKey)
        blendFilters[0].setValue(linear1Image, forKey: kCIInputBackgroundImageKey)

        let blend0Image = blendFilters[0].outputImage

        blendFilters[1].setValue(blend0Image, forKey: kCIInputImageKey)
        blendFilters[1].setValue(linear2Image, forKey: kCIInputBackgroundImageKey)

        return blendFilters[1].outputImage

    }
    
        ///    format is gradient.keyName  ie linear1.inputPoint1
        ///    answer zero if not found
    func prefixGradientIndex(compoundKeyName: String) -> Int {
        if let delimitorIndex = compoundKeyName.firstIndex(of: kPGradientKeyDelimitor) {
            let prefix = compoundKeyName.prefix(upTo: delimitorIndex)
            let lastChar = prefix.last
            return lastChar?.wholeNumberValue ?? 0
        }
        return 0
    }

    /// attribute keyName is compound form of gradient.keyName  ie linear1.inputPoint1
    /// return the  gradient filter indicated by the prefix number
    func targetGradient(keyName: String) -> PGLSourceFilter? {
        let gradientIndex = prefixGradientIndex(compoundKeyName: keyName)
        if (linearGradients.isEmpty) || (linearGradients.count < gradientIndex - 1 ) {
            return nil
        }
        return linearGradients[gradientIndex]
    }
    override func setVectorValue(newValue: CIVector, keyName: String) {
        logParm(#function, newValue.debugDescription, keyName)
        if keyName == kCIInputCenterKey {
            // create a translation transform for the change from the oldPoint to the newValue
            let oldCenterPoint = centerPoint
            centerPoint = CGPoint(x: newValue.x, y: newValue.y)
            let mappingTransform = CGAffineTransform(translationX: centerPoint.x - oldCenterPoint.x , y: centerPoint.y - oldCenterPoint.y)
            for aLinearGradientFilter in linearGradients {
                if let thisGradient = aLinearGradientFilter as? PGLGradientChildFilter {
                    thisGradient.applyTranslationMove(translation: mappingTransform)
                }
            }
        } else {
            if let targetGradient = targetGradient(keyName: keyName) {
                targetGradient.setVectorValue(newValue: newValue, keyName: keyName)
            }
        }
        postImageChange()
    }

    override func valueFor( keyName: String) -> Any? {
        if keyName == kCIInputCenterKey {
            return centerPoint
        }
        if let targetGradient = targetGradient(keyName: keyName) {
            return targetGradient.valueFor(keyName: keyName)
        }
        else {
           return super.valueFor(keyName: keyName)
        }
    }

}
