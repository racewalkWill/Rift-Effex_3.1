//
//  PGLPasteUIImageFilter.swift
//  RiftEffects
//
//  Created by Will on 11/21/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//

import UIKit

///  input UIImage from clipboard add to stack with Blend with Mask
///     saves UIImage to PhotoLibrary on save command
class PGLPasteUIImageFilter: CIFilter {
    // pattern fromn PGLBumpBlendCI PGLBumpBlend

    @objc dynamic   var inputImage: CIImage?
    @objc dynamic   var inputBackgroundImage: CIImage?
//    @objc dynamic   var inputMaskImage: CIImage?

    class func register() {
        //       let attr: [String: AnyObject] = [:]

        CIFilter.registerName(kUIImagePasteFilter, constructor: PGLFilterConstructor(), classAttributes: PGLPasteUIImageFilter.customAttributes())
    }

    class override var supportsSecureCoding: Bool { get {
        // subclasses must  implement this
        // Core Data requires secureCoding to store the filter
        return true
    }}

    @objc class func customAttributes() -> [String: Any] {

        let customDict:[String: Any] = [
            kCIAttributeFilterDisplayName : kUIImagePasteFilter,

            kCIAttributeFilterCategories :
                [kCICategoryStillImage , kCICategoryStylize],

            "pasteImage": [kCIAttributeIdentity: 0,
                kCIAttributeClass: "CIImage",
                kCIAttributeDisplayName: "Paste Image",
                kCIAttributeType: kCIAttributeTypeImage] as [String : Any],

            "inputRadius" :
                [
                    kCIAttributeMin       :  0.0,
                    kCIAttributeSliderMin :  0.0,
                    kCIAttributeSliderMax : 1000.0,
                    kCIAttributeDefault   : 300.0,
                    kCIAttributeIdentity  :  0.0,
                    kCIAttributeType      : kCIAttributeTypeScalar
                ] as [String : Any],
            "inputRadius1" :
                [
                    kCIAttributeMin       :  0.0,
                    kCIAttributeSliderMin :  0.0,
                    kCIAttributeSliderMax : 1000.0,
                    kCIAttributeDefault   : 400.0,
                    kCIAttributeIdentity  :  0.0,
                    kCIAttributeType      : kCIAttributeTypeScalar
                ] as [String : Any],
            "inputScale" : [

                kCIAttributeMin       : -5.0 ,
                kCIAttributeSliderMin : -5.0,
                kCIAttributeSliderMax : 5.0 ,
                kCIAttributeDefault   : 0.50 ,
                kCIAttributeIdentity  : 0,
                kCIAttributeType      : kCIAttributeTypeScalar

            ] as [String : Any],

            "inputCenter" : [  //kCIInputCenterKey"
                kCIAttributeClass : "CIVector" ,
                kCIAttributeDefault : CIVector(x: 300, y: 300),
                kCIAttributeDescription :"The center of the effect as x and y coordinates",
                kCIAttributeDisplayName :"Center",
                kCIAttributeType : kCIAttributeTypePosition
                            ] as [String : Any],
        ]
        return customDict

    }
        //    @objc  var inputImage:  CIImage?
        //  standard input from prior filter

//    @objc  var pasteImage:  CIImage?
//    @objc  var  inputRadius: NSNumber = 100.0
//    @objc  var  inputRadius1: NSNumber = 400.0
//    @objc var inputCenter:CIVector = CIVector(x: 200, y: 200)
//     @objc  var  inputScale: NSNumber = 0.50



//    override func setDefaults()
//    {
//        self.inputRadius = 400.0
//        self.inputRadius1 = 400.0
//        self.inputCenter = CIVector(x: 600 , y: 600)
//        self.inputScale = 0.50
//    }

    override var outputImage: CIImage? {
        guard let myInput = inputImage else { return nil }


        guard let blendFilter = CIFilter(name:"CIBlendWithMask",  parameters: [
            kCIInputImageKey: inputBackgroundImage!,
            "inputMaskImage": inputBackgroundImage!,
            "inputBackgroundImage": myInput ])
        else { return CIImage.empty() }

        let pasteOutput = blendFilter.outputImage?.cropped(to: myInput.extent )

//        let opaqueGreen      = CIColor(red:0.0, green:1.0, blue:0.0, alpha:1.0)
//        let transparentGreen = CIColor(red:0.0, green:1.0, blue:0.0, alpha:0.0)
//
//        let gradient0Filter = CIFilter(name: "CIRadialGradient", parameters: [
//            "inputCenter": inputCenter,
//            "inputRadius0": inputRadius,
//            "inputRadius1": inputRadius1,
//            "inputColor0": opaqueGreen,
//            "inputColor1": transparentGreen ] )
//        let gradient0 = gradient0Filter?.outputImage

        return pasteOutput
    }



}
