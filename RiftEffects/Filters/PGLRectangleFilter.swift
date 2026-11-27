//
//  PGLRectangleFilter.swift
//  RiftEffects
//
//  Created by Will on 2/12/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//

import UIKit
import os

/// How a rectangle filter (crop) shows its output in the stack.
enum PGLRectangleOutputScaling {
    /// uniform scale to fit the render area, centered - no distortion in any orientation
    case zoomToFit
    /// separate x and y scale to fill the render area - distorts with the view shape
    case stretchToFill
}

class PGLRectangleFilter : PGLSourceFilter {
    // applies CIImage level methods to the image output

    /// one switch for all rectangle filters - zoomToFit chosen 2026-11-26, stretchToFill is
    /// the earlier behavior
    static let outputScaling = PGLRectangleOutputScaling.zoomToFit
    //static let outputScaling = PGLRectangleOutputScaling.stretchToFill
    
    /// where #scaleOutput drew the output this frame - nil when not scaled (infinite extent,
    /// or a subclass that does not scale)
    var scaledOutputRect: CGRect?

    /// true while the rectangle overlay is open - see PGLImageController #showRectView.
    /// A filter that scales its output shows its uncropped input while editing, so the overlay
    /// (mapped onto the input image) is drawn over the same picture it edits.
    var isEditingRect = false {
        didSet {
            if oldValue != isEditingRect {
                NotificationCenter.default.post(name: PGLRedrawFilterChange, object: nil, userInfo: ["filterHasChanged" : true as AnyObject])
            }
        }
    }

    /// false for subclasses whose output is already in the input's space (they do not scale
    /// their output) or that need their effect visible while the rect is placed
    var showsInputWhileEditing: Bool {
        return true
    }

    /// passing the input through while editing - the output is shown unscaled
    func isShowingInputForEditing() -> Bool {
        return isEditingRect && showsInputWhileEditing
    }



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
       let outputExtent = ciOutput.extent
       if isShowingInputForEditing() || outputExtent.isInfinite || outputExtent.isEmpty {
           // ciClamp filter output is always infinite extent
           // just return without scaling
           scaledOutputRect = nil
           return ciOutput }

        let drawnRect = PGLRectangleFilter.scaledRect(for: outputExtent, in: stackCropRect)
        let widthScale = drawnRect.width / outputExtent.width
        let heightScale = drawnRect.height / outputExtent.height
        let transform = CGAffineTransform(translationX: -outputExtent.minX, y: -outputExtent.minY)
            .concatenating(CGAffineTransform(scaleX: widthScale, y: heightScale))
            .concatenating(CGAffineTransform(translationX: drawnRect.minX, y: drawnRect.minY))
        scaledOutputRect = drawnRect
        return ciOutput.transformed(by: transform)
    }

    /// the rect the output extent is scaled into - see PGLRectangleFilter.outputScaling
    static func scaledRect(for outputExtent: CGRect, in stackCropRect: CGRect) -> CGRect {
        switch outputScaling {
            case .stretchToFill:
                return stackCropRect
            case .zoomToFit:
                let scale = min(stackCropRect.width / outputExtent.width, stackCropRect.height / outputExtent.height)
                let fitWidth = outputExtent.width * scale
                let fitHeight = outputExtent.height * scale
                return CGRect(x: stackCropRect.minX + (stackCropRect.width - fitWidth) * 0.5,
                              y: stackCropRect.minY + (stackCropRect.height - fitHeight) * 0.5,
                              width: fitWidth, height: fitHeight)
        }
    }

    /// the next filter maps its parms onto the scaled output, not onto this filter's input
    override func outputReferenceRect() -> CGRect? {
        return scaledOutputRect ?? parmReferenceRect()
    }


    override func outputImage() -> CIImage? {
        let thisOutput = super.outputImage()
        if isShowingInputForEditing(),
           let filterOutput = thisOutput, !filterOutput.extent.isInfinite,
           let inputImage = localFilter.value(forKey: kCIInputImageKey) as? CIImage {
            // editing the rect - show the uncropped input. An infinite output (CIClamp) is
            // not scaled, so it is already in the input's space and shows as is.
            return inputImage
        }
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
