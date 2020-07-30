//
//  PGLNullCIFilter.swift
//  Glance
//
//  Created by Will on 2/2/19.
//  Copyright © 2019 Will Loew-Blosser. All rights reserved.
//


import UIKit

class PGLImageCIFilter: PGLFilterCIAbstract {
    // just return an image.. NO EFFECTS.. Starts the filter chain..
    override class func register() {
        //       let attr: [String: AnyObject] = [:]
        NSLog("PGLImageCIFilter #register()")
        CIFilter.registerName(kPImages, constructor: PGLFilterConstructor(), classAttributes: PGLImageCIFilter.customAttributes())
    }

    @objc    override class func customAttributes() -> [String: Any] {
        let customDict:[String: Any] = [
            kCIAttributeFilterDisplayName : "Images",

            kCIAttributeFilterCategories :
                [kCICategoryTransition],
            "inputTime" :  [

                kCIAttributeDefault   : 0.00,
                kCIAttributeIdentity  :  0.0,
                kCIAttributeType      : kCIAttributeTypeTime
                ]
        ]
        return customDict
    }

//    @objc dynamic  var inputImage: CIImage?
    @objc dynamic  var inputTime = 0.0

    override var outputImage: CIImage? {
        get { return inputImage }
    }
}
