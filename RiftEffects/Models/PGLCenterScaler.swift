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
}

///  one centerScaler for each image - images are different sizes
///   uses Global TargetSize for  center and size transform
class PGLCenterScaler {
    var centerTransform: CGAffineTransform?
    var sizeTransform: CGAffineTransform?

    var displayTransform: CGAffineTransform?

    init(centerCIImage: CIImage) {
        let imageExtent = centerCIImage.extent // can be infinite
//        setSizeTransform(imageExtent: imageExtent)
        setCenterTransform(imageExtent: imageExtent)
//        displayTransform = centerTransform?.concatenating(sizeTransform ?? CGAffineTransform.identity) ?? CGAffineTransform.identity
        displayTransform = centerTransform ?? CGAffineTransform.identity
    }

    func setCenterTransform(imageExtent: CGRect) {
        // based upon the Renderer #drawBasicCentered( in view: MTKView)

            // let dSize = view.drawableSize
            let dSize = TargetSize

            let backBounds = CGRect(x: 0, y: 0, width: dSize.width, height: dSize.height)

//            if imageExtent.isInfinite {
//                iRect = dSize
//            }

            let shiftX = round((backBounds.size.width + imageExtent.origin.x - imageExtent.size.width) * 0.5)
            let shiftY = round((backBounds.size.height + imageExtent.origin.y - imageExtent.size.height) * 0.5)

        centerTransform = CGAffineTransform(translationX: shiftX, y: shiftY)
        }

    func setSizeTransform (imageExtent: CGRect) {
        // based upon the PGLImageList #scaleToFrame(ciImage, newSize) transform

        let newSize = TargetSize
        let xTransform:CGFloat = 0.0 - imageExtent.origin.x
        let yTransform:CGFloat = 0.0  - imageExtent.origin.y
        //move to zero
        let translateToZeroOrigin = CGAffineTransform.init(translationX: xTransform, y: yTransform)


        let xScale = newSize.width / imageExtent.width
        let yScale =  newSize.height / imageExtent.height
        let scaleTransform = CGAffineTransform.init(scaleX: xScale, y: yScale)

        sizeTransform = translateToZeroOrigin.concatenating(scaleTransform)
    }

    func centerAndScale(image: CIImage) -> CIImage {
        return image.transformed(by: displayTransform ?? CGAffineTransform.identity)
    }

    
}
