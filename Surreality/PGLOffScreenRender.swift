//
//  PGLOffScreenRender.swift
//  Surreality
//
//  Created by Will on 8/15/20.
//  Copyright © 2020 Will Loew-Blosser. All rights reserved.
//

import Foundation
import UIKit

class PGLOffScreenRender {
    var offScreenContext = CIContext.init(options: nil)

    func getOffScreenHEIF(filterStack: PGLFilterStack) -> Data? {
        // create second context for off screen rendering of UIImage
//        CIContext * context = [CIContext contextWithOptions:nil];
//        CGImageRef outputCGImage = [context createCGImage:outputCIImage fromRect:[outputCIImage extent]];
//        UIImage * outputImage = [UIImage imageWithCGImage:outputCGImage];
//        CGImageRelease(outputCGImage);
//
//        return outputImage;



         let ciOutput = filterStack.stackOutputImage(false)
            let outputRect = (ciOutput.extent)
//            let clampedOutput = ciOutput.clamped(to: outputRect)
            NSLog("PGLOffScreenRender getOffScreenHEIF outputRect = \(outputRect)")
            let rgbSpace = CGColorSpaceCreateDeviceRGB()
            let options = [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 1.0 as CGFloat]
            let heifData =  offScreenContext.heifRepresentation(of: ciOutput, format: .RGBA8, colorSpace: rgbSpace, options: options)

            return heifData




    }

    func captureUIImage(filterStack: PGLFilterStack) -> UIImage? {
         let ciOutput = filterStack.stackOutputImage(false)
          let currentRect = filterStack.cropRect
          NSLog("Renderer #captureImage currentRect = \(currentRect)")
          let croppedOutput = ciOutput.cropped(to: currentRect)
          guard let currentOutputImage = offScreenContext.createCGImage(croppedOutput, from: croppedOutput.extent) else { return nil }



          NSLog("PGLOffScreenRender #captureImage croppedOutput.extent = \(croppedOutput.extent)")

          return UIImage( cgImage: currentOutputImage, scale: UIScreen.main.scale, orientation: .up)
          // kaliedoscope needs down.. portraits need up.. why.. they both look .up in the imageController


    }


}
