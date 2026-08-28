//
//  PGLRectangleFilter.swift
//  RiftEffects
//
//  Created by Will on 2/12/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//

import UIKit
import os

class PGLRectangleFilter : PGLSourceFilter {
    // applies CIImage level methods to the image output



    var cropAttribute: PGLAttributeRectangle? {
        didSet{
//            if cropAttribute == nil { fatalError("PGLRectangleFilter cropAttribute set to nil ")}
//            NSLog("PGLRectangleFilter didSet var cropAttribute = \(cropAttribute)")
        }
    }

   override func scaleOutput(ciOutput: CIImage, stackCropRect: CGRect) -> CIImage {

        // RectangleFilter needs to crop then scale to full size
        // Most filters do not need this. Parnent PGLSourceFilter has empty implementation
          //ciOutputImage.extent    CGRect    (origin = (x = 592, y = 491), size = (width = 729, height = 742))
        // currentStack.cropRect    CGRect    (origin = (x = 0, y = 0), size = (width = 1583, height = 1668))
       
//       let skipScaling = false
//       if skipScaling {
//           return ciOutput
//       }
       if ciOutput.extent.isInfinite {
           // ciClamp filter output is always infinite extent
           // just return without scaling
           return ciOutput }

        let widthScale = stackCropRect.width / ciOutput.extent.width
        let heightScale = stackCropRect.height / ciOutput.extent.height

        let scaleTransform = CGAffineTransform(scaleX: widthScale, y: heightScale)
        let translate = scaleTransform.translatedBy(x: -ciOutput.extent.minX, y: -ciOutput.extent.minY)
//      Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")
   //    NSLog("     translate \(translate) from \(stackCropRect)")
        let returnImage =  ciOutput.transformed(by: translate)
        return returnImage
    }


    override func outputImage() -> CIImage? {
        let thisOutput = super.outputImage()
        return thisOutput
        // need the transform for aspectFit to the parent extent.
//        if let newOutput = thisOutput {
////        let parentExtent = outputExtent()
//        let widthScale = parentExtent.width / newOutput.extent.width  //CGFloat
//        let heightScale = parentExtent.height / newOutput.extent.height
//
//        let scale = min(widthScale,heightScale)  // this is aspectFit
//                // aspectFill use max instead of min
//        let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
//            return newOutput.transformed(by: scaleTransform)
//        } else {
//            return thisOutput  // nil check else condition
//        }


    }

    override func setInput(image: CIImage?, source: String?) {
        super.setInput(image: image, source: source)

    }

    func attributeCropRect() -> CGRect {
        // answer the attributes filter rect
        if let thisFilterRect = cropAttribute?.filterRect {
            return thisFilterRect
        }
        else {
            return CGRect(x: 0, y: 0, width: RenderTargetSize.width, height: RenderTargetSize.height)
        }

    }

   
}
