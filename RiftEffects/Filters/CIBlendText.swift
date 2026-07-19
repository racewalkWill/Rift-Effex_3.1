//
//  CIBlendText.swift
//  RiftEffects
//
//  Created by Will on 5/2/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//
import Foundation
import CoreGraphics
import UIKit
import os

class CIBlendText: CIFilter {

    class override var supportsSecureCoding: Bool { get {
        // subclasses must  implement this
        // Core Data requires secureCoding to store the filter
        return true
    }}

    let colorBlendFilter: CIFilter
    let textImageFilter: CIFilter
    let rotateFilter: CIFilter
    let colorGenerator: CIFilter

    @objc var inputImage : CIImage?
    @objc var inputScaleFactor: NSNumber = 2
    @objc var inputFontName: NSString = "HelveticaNeue"
    @objc var inputFontSize: NSNumber = 24
    @objc var inputText: NSString = "Text"
    @objc var inputTextPosition: CIVector = CIVector(x: 300.0, y: 300.0)
    @objc var inputYaw: NSNumber = 0
    @objc var inputRoll: NSNumber = 0
    @objc var inputPitch: NSNumber = 0
    @objc var inputTextColor: CIColor = CIColor(color: UIColor.black)

    override init() {
        colorBlendFilter = CIFilter(name: "CIBlendWithAlphaMask")!
        textImageFilter = CIFilter(name: "CITextImageGenerator")!
        rotateFilter = CIFilter(name: "CIPerspectiveRotate")!
        colorGenerator = CIFilter(name: "CIConstantColorGenerator")!

        super.init()
    }

    required init?(coder aDecoder: NSCoder)
    {
        colorBlendFilter = CIFilter(name: "CIBlendWithAlphaMask")!
        textImageFilter = CIFilter(name: "CITextImageGenerator")!
        rotateFilter = CIFilter(name: "CIPerspectiveRotate")!
        colorGenerator = CIFilter(name: "CIConstantColorGenerator")!

        super.init(coder: aDecoder)
//        fatalError("init(coder:) has not been implemented")
    }

    func positionText(textCIImage: CIImage) -> CIImage {
        // similar to the filter method  PGLRectangleFilter.scaleOutput
        // this is internal to filter for chaining from textImageFilter to
        // the blendFilter

        let midPointY = textCIImage.extent.midY
        let translate = CGAffineTransform(translationX: inputTextPosition.x, y: (inputTextPosition.y - midPointY))

        return textCIImage.transformed(by: translate)
    }


    override var outputImage: CIImage!
    {

        textImageFilter.setValuesForKeys(
            ["inputScaleFactor":  inputScaleFactor,
             "inputFontName" : inputFontName,
             "inputFontSize" : inputFontSize,
             "inputText" : inputText

            ]
        )  
        guard let textOutput = textImageFilter.outputImage else {
            return inputImage
        }
        colorGenerator.setValue(inputTextColor, forKey: "inputColor")

        // scale & position textOutput to the inputTextPosition
        let scaledText = positionText(textCIImage: textOutput)
        rotateFilter.setValuesForKeys(
            ["inputImage" : scaledText,
            "inputYaw" : inputYaw,
             "inputRoll" : inputRoll,
             "inputPitch": inputPitch])

        let rotatedText = rotateFilter.outputImage!
        colorBlendFilter.setValuesForKeys(["inputImage": colorGenerator.outputImage!,
                                           "inputMaskImage": rotatedText,
                                           "inputBackgroundImage": inputImage as Any]
                                            )

        return colorBlendFilter.outputImage
    }


    @objc    class func customAttributes() -> [String: Any] {
        let textAttributes: [String:Any] = [
            kCIAttributeFilterCategories :
                                  [kCICategoryGenerator ,
                                   kCICategoryCompositeOperation,
                                   kCICategoryStillImage,
                                  kCICategoryVideo],

            kCIAttributeFilterDisplayName : NSLocalizedString("Blend Text", comment: "Blend Text filter display name"),

            // now list the full set..
            "inputImage": [kCIAttributeIdentity: 0,
                kCIAttributeClass: "CIImage",
                kCIAttributeDisplayName: NSLocalizedString("Image", comment: "Filter parameter display name"),
                               kCIAttributeType: kCIAttributeTypeImage] as [String : Any],

            "inputFontSize": [kCIAttributeIdentity: 0,
                kCIAttributeClass: "NSNumber",
                kCIAttributeDefault: 24,
                kCIAttributeDisplayName: NSLocalizedString("Font Size", comment: "Blend Text parameter display name"),
                kCIAttributeMin: 9,
                kCIAttributeSliderMin: 9,
                kCIAttributeSliderMax: 128,
                                  kCIAttributeType: kCIAttributeTypeScalar] as [String : Any],

            "inputScaleFactor": [kCIAttributeIdentity: 1,
                kCIAttributeClass: "NSNumber",
                kCIAttributeDefault: 2,
                kCIAttributeDisplayName: NSLocalizedString("Scale Factor", comment: "Blend Text parameter display name"),
                kCIAttributeMin: 0,
                kCIAttributeSliderMin: 1,
                kCIAttributeSliderMax: 4,
                                     kCIAttributeType: kCIAttributeTypeScalar] as [String : Any] as [String : Any],

            "inputFontName": [kCIAttributeDefault: "HelveticaNeue",
                              kCIAttributeDisplayName: NSLocalizedString("Font Name", comment: "Blend Text parameter display name"),
                              kCIAttributeClass: "NSString" ],

            "inputText" : [kCIAttributeDisplayName: NSLocalizedString("Text", comment: "Blend Text parameter display name"),
                           kCIAttributeClass: "NSString"

            ],

            "inputTextPosition" : [ kCIAttributeClass: "CIVector",
                                        kCIAttributeType: "CIAttributeTypePosition",
                                        kCIAttributeDefault: CIVector(x: 300.0, y: 300.0),
                                        kCIAttributeDisplayName: NSLocalizedString("Text Position", comment: "Blend Text parameter display name"),
                                        kCIAttributeDescription: NSLocalizedString("Position Text", comment: "Blend Text parameter description")
                                  ] as [String : Any] ,


        "inputPitch" : [ kCIAttributeClass: "NSNumber",
                                    kCIAttributeType: "CIAttributeTypeAngle",
                                    kCIAttributeDefault: 0,
                                    kCIAttributeDisplayName: NSLocalizedString("Pitch", comment: "Blend Text parameter display name"),
                                    kCIAttributeDescription: NSLocalizedString("Pitch angle in radians.", comment: "Blend Text parameter description"),
                                    kCIAttributeSliderMin:  -0.5235987755982988,
                                    kCIAttributeSliderMax: 0.5235987755982988,
                              ] as [String : Any] ,

        "inputYaw" : [ kCIAttributeClass: "NSNumber",
                                    kCIAttributeType: "CIAttributeTypeAngle",
                                    kCIAttributeDefault: 0,
                                    kCIAttributeDisplayName: NSLocalizedString("Yaw", comment: "Blend Text parameter display name"),
                                    kCIAttributeDescription: NSLocalizedString("Yaw angle in radians.", comment: "Blend Text parameter description"),
                                    kCIAttributeMin: 0,
                                    kCIAttributeSliderMin: -0.5235987755982988,
                                    kCIAttributeSliderMax: 0.5235987755982988,
                              ] as [String : Any] ,


        "inputRoll" : [ kCIAttributeClass: "NSNumber",
                                    kCIAttributeType: "CIAttributeTypeAngle",
                                    kCIAttributeDefault: 0,
                                    kCIAttributeDisplayName: NSLocalizedString("Roll", comment: "Blend Text parameter display name"),
                                    kCIAttributeDescription: NSLocalizedString("Roll", comment: "Blend Text parameter description"),

                                    kCIAttributeSliderMin: -0.7853981633974483,
                                    kCIAttributeSliderMax: 0.7853981633974483,
                              ] as [String : Any ],
            "inputColor" :[ kCIAttributeClass: "CIColor",
                             kCIAttributeType: "CIAttributeTypeColor",
                          kCIAttributeDefault: CIColor(color: UIColor.black),
                             kCIAttributeDisplayName: NSLocalizedString("Color", comment: "Blend Text parameter display name"),
                             kCIAttributeDescription: NSLocalizedString("Color", comment: "Blend Text parameter description")
                        ] as [String : Any ]

            ]
        return textAttributes
    }




    class func register()   {
 //       let attr: [String: AnyObject] = [:]
//        NSLog("CompositeTextPositionFilter #register()")

            Logger().info("CompositeTextPositionFilter #register()")
        CIFilter.registerName(kBlendTextFilter, constructor: PGLFilterConstructor(), classAttributes: [
            kCIAttributeFilterCategories :    [kCICategoryGenerator ,
                                               kCICategoryStillImage,
                                               kCICategoryVideo],
            kCIAttributeFilterDisplayName : NSLocalizedString("Blend Text", comment: "Blend Text filter display name")
            ])

        CIFilter.registerName(kCompositeTextPositionFilter, constructor: PGLFilterConstructor(), classAttributes: [
            kCIAttributeFilterCategories :    [kCICategoryGenerator ,
                                               kCICategoryStillImage,
                                               kCICategoryVideo],
            kCIAttributeFilterDisplayName : NSLocalizedString("Composite Text", comment: "Composite Text filter display name")
            ])

    }


}

class CompositeTextPositionFilter: CIBlendText {
    override class func register()   {
 //       let attr: [String: AnyObject] = [:]
//        NSLog("CompositeTextPositionFilter #register()")

            Logger().info("CompositeTextPositionFilter #register()")

        CIFilter.registerName(kCompositeTextPositionFilter, constructor: PGLFilterConstructor(), classAttributes: [
            kCIAttributeFilterCategories :    [kCICategoryGenerator ,
                                               kCICategoryStillImage,
                                               kCICategoryVideo],
            kCIAttributeFilterDisplayName : NSLocalizedString("Composite Text", comment: "Composite Text filter display name")
            ])

    }
}
