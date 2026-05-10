//
//  PGLSaliencyBlur.swift
//  Surreality
//
//  Created by Will on 1/18/21.
//  Copyright © 2021 Will Loew-Blosser. All rights reserved.
//

import Foundation
import CoreImage
import Vision

class PGLSaliencyBlurFilter: CIFilter {
    // attention based saliency with Gaussian Blur
    class override var supportsSecureCoding: Bool { get {
        // subclasses must  implement this
        // Core Data requires secureCoding to store the filter
        return true
    }}
    
    @objc dynamic   var inputImage: CIImage?
    @objc dynamic   var inputRadius: NSNumber = 10.0

    @objc    class func customAttributes() -> [String: Any] {
            let customDict:[String: Any] = [
                kCIAttributeFilterDisplayName : "Saliency Blur",

                kCIAttributeFilterCategories :
                    [kCICategoryBlur, kCICategoryInterlaced, kCICategoryNonSquarePixels, kCICategoryStillImage] ,

                "inputRadius" :  [
                        kCIAttributeMin       :  0.0,
                        kCIAttributeSliderMin :  0.0,
                        kCIAttributeSliderMax : 30.0,
                        kCIAttributeDefault   : 10.0,
                        kCIAttributeIdentity  :  0.0,
                        kCIAttributeType      : kCIAttributeTypeScalar
                ] as [String : Any]

                ]


            return customDict
        }


    @objc dynamic  override var outputImage: CIImage? {
        get { return imageChain()  }
    }

    func createHeatMapMask(from observation: VNSaliencyImageObservation) -> CIImage? {
        let pixelBuffer = observation.pixelBuffer
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let vector = CIVector(x: 0, y: 0, z: 0, w: 1)
        let saliencyImage = ciImage.applyingFilter("CIColorMatrix", parameters: ["inputBVector": vector])

        return saliencyImage
    }

    func processSaliency() ->  CIImage {
        guard let input = inputImage else {
            return CIImage.empty()
        }
//        NSLog(#function + "inputImage size: \(input.extent.width) x \(input.extent.height)")
        let requestHandler = VNImageRequestHandler(ciImage: input, options: [ : ]) // <#T##[VNImageOption : Any]#>

        let request = VNGenerateObjectnessBasedSaliencyImageRequest()
            // VNGenerateObjectnessBasedSaliencyImageRequest()
            //VNGenerateAttentionBasedSaliencyImageRequest()

        try? requestHandler.perform([request])

        guard let observation = request.results?.first as? VNSaliencyImageObservation
            else { return CIImage.empty() } //VNSaliencyImageObservation
        guard let heatMask =  createHeatMapMask(from: observation) else { return CIImage.empty() }
//        let fitScale =  min(inputImage!.extent.width / heatMask.extent.width, inputImage!.extent.height / heatMask.extent.height)
//        NSLog(#function + "heat mask size: \(heatMask.extent.width) x \(heatMask.extent.height)")
        let scaleT = CGAffineTransform(scaleX: inputImage!.extent.width / heatMask.extent.width, y: inputImage!.extent.height / heatMask.extent.height)
//        NSLog("scaleT: \(scaleT)")
       let scaledUpHeatMask =  heatMask.transformed(by: scaleT)
//        NSLog("scaledUpHeatMask: \(scaledUpHeatMask)")
        return scaledUpHeatMask

    }
    func imageChain() -> CIImage? {
        if ( (inputRadius.floatValue) < 0.16 )  {
            // if radius is too small to have any effect just return input image
            return inputImage }
//        let opaqueGreen = CIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0 )
//        let transparentGreen =  CIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 0.0 )

        let blurredImage = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": inputRadius, kCIInputImageKey: inputImage as Any])?.outputImage
//        blurredImage = blurredImage?.translateNegativeXY()
//        blurredImage = blurredImage?.cropped(to: (inputImage?.extent)!)
//        NSLog(#function + "blurredImage size: \(String(describing: blurredImage?.extent.width)) x \(String(describing: blurredImage?.extent.height))")

        // capture the saliency transformed to matching coordinates of inputImage

        var maskImage = processSaliency() // of input
//        maskImage = maskImage.translateNegativeXY()
        maskImage = maskImage.cropped(to: (inputImage?.extent)!)
//        NSLog(#function + "maskImage size: \(String(describing: maskImage.extent.width)) x \(String(describing: maskImage.extent.height))")
        let blendMask = CIFilter(name: "CIBlendWithMask" )
           blendMask?.setValue(blurredImage, forKey: kCIInputBackgroundImageKey)
           blendMask?.setValue(maskImage, forKey: kCIInputMaskImageKey)
           blendMask?.setValue(inputImage, forKey: kCIInputImageKey )


       let returnImage = blendMask?.outputImage
//        NSLog(#function + "returnImage size: \(String(describing: returnImage?.extent.width)) x \(String(describing: returnImage?.extent.height))")
        return returnImage

    }



    class func register()   {
 //       let attr: [String: AnyObject] = [:]
//        NSLog("Saliency Blur #register()")
        CIFilter.registerName(kSaliencyBlurFilter, constructor: PGLFilterConstructor(), classAttributes: [
            kCIAttributeFilterCategories :    [
                kCICategoryBlur, kCICategoryInterlaced, kCICategoryNonSquarePixels, kCICategoryStillImage
                                               ],
            kCIAttributeFilterDisplayName : "Saliency Blur"
            ])
    }

}
