//
//  PGLCenterScaler.swift
//  RiftEffects
//
//  Created by Will on 5/15/24.
//  Copyright © 2024 Will Loew-Blosser. All rights reserved.
//

import Foundation
import CoreImage

    /// holder of pair of the image and the scaler transform to center
struct PGLImageScaler {
    var image: CIImage
    var centerScaler: PGLCenterScaler?
        // may be nil !! if the image was already scaled

    func useAspectFill() {
        centerScaler?.setAspectFillTransform(imageExtent: image.extent)
    }

    func useAspectFit() {
        
    }
}

///  one centerScaler for each image - images are different sizes
///   uses Global TargetSize for  center and size transform
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
        // based upon the Renderer #drawBasicCentered( in view: MTKView)

            // let dSize = view.drawableSize
            let dSize = TargetSize

            let backBounds = CGRect(x: 0, y: 0, width: dSize.width, height: dSize.height)

//            if imageExtent.isInfinite {
//                iRect = dSize
//            }

            let shiftX = round((backBounds.size.width + imageExtent.origin.x - imageExtent.size.width) * 0.5)
            let shiftY = round((backBounds.size.height + imageExtent.origin.y - imageExtent.size.height) * 0.5)

        aspectFitCenter = CGAffineTransform(translationX: shiftX, y: shiftY)
        displayTransform = aspectFitCenter ?? CGAffineTransform.identity
        }

    func setAspectFillTransform (imageExtent: CGRect) {
        // based upon the PGLImageList #scaleToFrame(ciImage, newSize) transform

        let newSize = TargetSize
        let xTransform:CGFloat = 0.0 - imageExtent.origin.x
        let yTransform:CGFloat = 0.0  - imageExtent.origin.y
        //move to zero
        let translateToZeroOrigin = CGAffineTransform.init(translationX: xTransform, y: yTransform)


        let xScale = newSize.width / imageExtent.width
        let yScale =  newSize.height / imageExtent.height
        let scaleTransform = CGAffineTransform.init(scaleX: xScale, y: yScale)

        displayTransform = translateToZeroOrigin.concatenating(scaleTransform)
    }

    func displayTransform(image: CIImage) -> CIImage {
        return image.transformed(by: displayTransform ?? CGAffineTransform.identity)
    }

    
}
