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

@MainActor
class PGLPasteUIImageFilter: PGLScaleUpFrame {
    // need to pass customAttributes into the blendFilter
    // or surface the blendFilter attributes into the interfadce
    // consider that customeAttributes will be stored...


        /// add the centerPoint attribute to other Lanczos Scale attributes
    required init?(filter: String, position: PGLFilterCategoryIndex) {
        super.init(filter: filter, position: position)
        attributes.append(self.clipboardImageAttribute())
        hasAnimation = true }


    var clipboardImage: CIImage?

    var blendFilter = CIFilter(name:"CIBlendWithAlphaMask")
    // else { return CIImage.empty() }

    override class func localizedDescription(filterName: String) -> String {
        // custom subclasses should override
       return "Paste image from clipboard"
    }

    override class func displayName() -> String? {

        // FilterDescriptor will use the ciFilter.localizedName if this is nil.
        // where a ciFilter is used with different pglSourceFilter classes then this method should be implemented
        // by the subclass
        return kUIImagePasteFilter
    }

//    override var filterName: String? {
//        return "CIMaximumTran"
//
//    }


  func clipboardImageAttribute() -> PGLFilterAttributeImage {

      let inputDict: [String:Any] = [

          "CIAttributeType" : kCIAttributeTypeImage,
          "CIAttributeDisplayName" : "Clipboard Image" ,
          "kCIAttributeDescription": "Image pasted from clipboard",
          "CIAttributeClass":  "CIImage"
      ]
      let newImageAttribute = PGLFilterAttributeImage(pglFilter: self, attributeDict: inputDict, inputKey: kUIImagePasteFilter)
      return newImageAttribute!

    }

//    func imageInputAttribute() -> PGLFilterAttributeImage?
//    {
//        blendFilter.attribute(nameKey: kCIInputImageKey) as? PGLFilterAttributeImage
//    }

// implement set and valueFor??/
/// set center point
///  cifilter does not hold the center point
    override func setImageValue(newValue: CIImage, keyName: String) {
    //        logParm(#function, newValue.debugDescription, keyName)
    //        shouldMoveCenter = true
        switch keyName {
            case kUIImagePasteFilter:
                clipboardImage = newValue
                super.setImageValue(newValue: newValue, keyName: kCIInputImageKey)
//                postImageChange()
            case kCIInputImageKey:
                // blend uses prior input as background
                blendFilter?.setValue(newValue, forKey: kCIInputBackgroundImageKey)
            default:
                super.setImageValue(newValue: newValue, keyName: keyName)
        }


    }

    override func valueFor( keyName: String) -> Any? {
        switch keyName {
            case kUIImagePasteFilter:
                return clipboardImage

//            case kCIInputImageKey:
//                // re map prior input to blend filter background
//                return blendFilter?.value( forKey: kCIInputBackgroundImageKey)

            default:
                return super.valueFor(keyName: keyName)
        }

    }

    

   // ===================
    override func outputImageBasic() -> CIImage? {
        // Ensure required inputs are available

        let resizedClipImage = super.outputImageBasic()

        guard let myBlendFilter = blendFilter
            else { return nil }

//        guard let myInput = inputImage()
//            else { return nil }

        // prior filter input will be background. Pasted clipped scaled image is mask and input
        myBlendFilter.setValue(resizedClipImage, forKey: kCIInputImageKey)
        myBlendFilter.setValue(resizedClipImage, forKey: kCIInputMaskImageKey)

//        myBlendFilter.setValue(myInput, forKey: kCIInputBackgroundImageKey)
        // background set already

        // Produce output
        return myBlendFilter.outputImage
    }

}

