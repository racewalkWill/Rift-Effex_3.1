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

// implement set and valueFor??/
/// set center point
///  cifilter does not hold the center point
    override func setImageValue(newValue: CIImage, keyName: String) {
    //        logParm(#function, newValue.debugDescription, keyName)
    //        shouldMoveCenter = true
        clipboardImage = newValue
        postImageChange()
    }

    override func valueFor( keyName: String) -> Any? {
        if keyName == kUIImagePasteFilter {
            return clipboardImage
        } else {
            return super.valueFor(keyName: keyName)
        }
    }

   // ===================
    override func outputImageBasic() -> CIImage? {
        // Ensure required inputs are available
        guard let myBlendFilter = blendFilter
            else { return nil }
        guard let myClipboardImage = clipboardImage
            else { return nil }
        guard let myInput = inputImage()
            else { return nil }

        // prior filter input will be background. Pasted clipped scaled image is mask and input
        myBlendFilter.setValue(myClipboardImage, forKey: kCIInputImageKey)
        myBlendFilter.setValue(myInput, forKey: kCIInputBackgroundImageKey)
        myBlendFilter.setValue(myClipboardImage, forKey: kCIInputMaskImageKey)

        // Produce output
        return myBlendFilter.outputImage
    }

}

