//
//  PGLBumpFace.swift
//  Glance
//
//  Created by Will on 1/24/19.
//  Copyright © 2019 Will Loew-Blosser. All rights reserved.
//

import UIKit


class PGLBumpFaceCIFilter: PGLFilterCIAbstract {
    // put the bump filter on the selected face feature
    override class func register() {
        //       let attr: [String: AnyObject] = [:]
        CIFilter.registerName(kPBumpFace, constructor: PGLFilterConstructor(), classAttributes: PGLBumpFaceCIFilter.customAttributes())
    }



    @objc override class func customAttributes() -> [String: Any] {
        let customDict:[String: Any] = [
            kCIAttributeFilterDisplayName : "Bump Face",

            kCIAttributeFilterCategories :
                [kCICategoryBlur],

            // "inputCenter" is left off.. detector supplies that value

            "inputRadius" :  [
                kCIAttributeMin       :  0.0,
                kCIAttributeSliderMin :  0.0,
                kCIAttributeSliderMax : 600.0,
                kCIAttributeDefault   : 300.0,
                kCIAttributeIdentity  :  0.0,
                kCIAttributeType      : kCIAttributeTypeScalar
            ],
            
            "inputScale" : [

                kCIAttributeMin       : -1.0 ,
                kCIAttributeSliderMin : -1.0,
                kCIAttributeSliderMax : 1.0 ,
                kCIAttributeDefault   : 0.0 ,
                kCIAttributeIdentity  : 0,
                kCIAttributeType      : kCIAttributeTypeScalar

            ],


        ]
        return combineCustomAttributes(otherAttributes: customDict)
    }

    let radiusDefault:NSNumber = 500.0
    var mappedRadius:CGFloat  = 500.0
//    @objc dynamic  var inputImage: CIImage?
    @objc dynamic var inputRadius: NSNumber = 200.0
    @objc dynamic var inputScale: NSNumber = 0.5



    override func setDefaults() {
        inputFeatureSelect = 0
    }

    var bumpDistortFilter = CIFilter(name: "BumpDistort")

    override var outputImage: CIImage? {
        get {

            if features.isEmpty { return inputImage}
//            if inputFeatureSelect < 0 {return inputImage}
            bumpDistortFilter?.setValue(inputImage, forKey: kCIInputImageKey)

            if inputFeatureSelect >= 0 {
                let featureIndex = min( inputFeatureSelect, features.count - 1) // don't go beyond the number of featurs
                let thisFeature = features[featureIndex]
                let theFaceCenter = faceCenter( thisFeature)
                if inputRadius == radiusDefault {
                    if let theBoundingBox = thisFeature.boundingBox() {
                    mappedRadius = (min( theBoundingBox.size.width, theBoundingBox.size.height ) / 1.5 )
                    }
                }
                else {mappedRadius = CGFloat(truncating: inputRadius) }

                bumpDistortFilter?.setValue(theFaceCenter, forKey: kCIInputCenterKey)


                bumpDistortFilter?.setValue(mappedRadius, forKey: kCIInputRadiusKey)
                bumpDistortFilter?.setValue(inputScale, forKey: kCIInputScaleKey)

            }
            else { return inputImage}

            return bumpDistortFilter?.outputImage ?? inputImage


        }
    }




    func faces() -> [PGLFaceBounds] {
        return features
        //        return (detector?.features(in: inputImage!))!
    }

    func faceCenter(_ aFace: PGLFaceBounds) -> CIVector {
        let featureBox = aFace.boundingBox(withinImageBounds: inputImage!.extent)
        let xCenter: CGFloat = featureBox.origin.x + featureBox.size.width/2.0
        let yCenter: CGFloat = featureBox.origin.y + featureBox.size.height/2.0
        return CIVector(x: xCenter, y: yCenter)
    }





}
