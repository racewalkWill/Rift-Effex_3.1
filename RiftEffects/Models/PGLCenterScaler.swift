//
//  PGLCenterScaler.swift
//  RiftEffects
//
//  Created by Will on 5/15/24.
//  Copyright © 2024 Will Loew-Blosser. All rights reserved.
//

import Foundation
import CoreImage

///  one centerScaler for each image - images are different sizes
///   uses Global RenderTargetSize for  center and size transform
@MainActor
class PGLCenterScaler {
    var aspectFitCenter: CGAffineTransform?
    var aspectFillSize: CGAffineTransform?

    var displayTransform: CGAffineTransform?


    init(centerCIImage: CIImage) {
        let imageExtent = centerCIImage.extent // can be infinite
        if FullScreenAspectFillMode {
            setAspectFillTransform(imageExtent: imageExtent)
        }
        else {
            setAspectFitTransform(imageExtent: imageExtent)
        }
    }

    func setAspectFitTransform(imageExtent: CGRect) {
        let dSize = RenderTargetSize

        let xTransform = 0.0 - imageExtent.origin.x
        let yTransform = 0.0 - imageExtent.origin.y
        let translateToZeroOrigin = CGAffineTransform(translationX: xTransform, y: yTransform)

        let xScale = dSize.width / imageExtent.size.width
        let yScale = dSize.height / imageExtent.size.height
        let uniformScale = min(xScale, yScale)
        let scaleTransform = CGAffineTransform(scaleX: uniformScale, y: uniformScale)

        let scaledWidth = imageExtent.size.width * uniformScale
        let scaledHeight = imageExtent.size.height * uniformScale
        let shiftX = round((dSize.width - scaledWidth) * 0.5)
        let shiftY = round((dSize.height - scaledHeight) * 0.5)
        let centerTransform = CGAffineTransform(translationX: shiftX, y: shiftY)

        displayTransform = translateToZeroOrigin
            .concatenating(scaleTransform)
            .concatenating(centerTransform)
        }

    func setAspectFillTransform (imageExtent: CGRect) {
        // based upon the PGLImageList #scaleToFrame(ciImage, newSize) transform

        let newSize = RenderTargetSize
        let xTransform:CGFloat = 0.0 - imageExtent.origin.x
        let yTransform:CGFloat = 0.0  - imageExtent.origin.y
        //move to zero
        let translateToZeroOrigin = CGAffineTransform.init(translationX: xTransform, y: yTransform)


        let xScale = newSize.width / imageExtent.width
        let yScale =  newSize.height / imageExtent.height
        let scaleTransform = CGAffineTransform.init(scaleX: xScale, y: yScale)

        displayTransform = translateToZeroOrigin.concatenating(scaleTransform)
    }

    func imageForTargetSize(image: CIImage) -> CIImage {
//        NSLog("PGLCenterScaler  displayTransform \(String(describing: displayTransform))")
        return image.transformed(by: displayTransform ?? CGAffineTransform.identity)
    }

    
}
