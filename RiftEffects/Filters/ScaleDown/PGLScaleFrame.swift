//
//  PGLScaleFrame.swift
//  RiftEffects
//
//  Created by Will on 11/27/23.
//  Copyright © 2023 Will Loew-Blosser. All rights reserved.
//

import Foundation
import CoreImage
import simd
import UIKit
import os


/// scale a stack output to a smaller rectangle
/// position scaledDown image in composite blackBackgroud
///  holds a Lanzcos filter to downsize
///   answers composite black in view size with image downsized and positioned
class PGLScaleDownFrame: PGLSourceFilter,  PGLCenterPoint {
    // return inputAttribute scaled down to the cropAttribute
    // Lanczos Scale Filter does this already.
    // use this frame for positioning at kCIInputCenterKey
    // position only if the centerPoint is changed by the user

    var shouldMoveCenter = false
    let opaqueBackground: CIImage = CIImage.black // CIImage.clear
    var addBackground: Bool = true

    /// The coordinate space `centerPoint` is expressed in. PGLScaleDownFrame has two roles:
    /// (1) a regular "Reduce to a smaller frame" stack filter, whose centerPoint comes from
    /// the attribute UI and is canonical (FilterCanvasSize-relative) like every other vector
    /// parm; (2) Renderer/PGLRenderOnAirPlay's internal pinch-zoom/pan filter, whose
    /// centerPoint is set directly (never through the attribute) in live drawable-pixel
    /// coordinates. Renderer.initZoomPanFilter()/PGLRenderOnAirPlay set this to their own
    /// live size right after creating that instance, so outputImageBasic()'s canvas->live
    /// conversion below becomes a no-op (identity) for role (2) while still converting
    /// correctly for role (1).
    var workingSize: CGSize = FilterCanvasSize

    var centerPoint: CGPoint = CGPoint(x: FilterCanvasSize.width/2, y: FilterCanvasSize.height/2) {
        didSet {
            shouldMoveCenter = true
        }
    }
    var fullScreenRect: CGRect { get
    {   return CGRect(x: 0, y: 0, width: RenderTargetSize.width, height: RenderTargetSize.height)

        }
    }
/// add the centerPoint attribute to other Lanczos Scale attributes
    required init?(filter: String, position: PGLFilterCategoryIndex) {
        super.init(filter: filter, position: position)
        attributes.append(self.centerPointAttribute())
        //  hasAnimation = true
    }

    override class func localizedDescription(filterName: String) -> String {
        // custom subclasses should override
       return NSLocalizedString("Reduce to a smaller frame", comment: "Scale Frame custom filter description")
    }

    class func initZoomPanFilter() -> PGLScaleDownFrame {
        let zoomDesc = PGLFilterDescriptor("CILanczosScaleTransform", PGLScaleDownFrame.self)!
        // see also  let zoomDesc = PGLFilterDescriptor("CIMaximumScaleTransform", PGLScaleUpFrame.self)!
        let zoomFilter = zoomDesc.pglSourceFilter() as! PGLScaleDownFrame
        return zoomFilter
    }

    func defaultCenterPoint() -> CGPoint {
        CGPoint(x: workingSize.width/2, y: workingSize.height/2)
    }

    /// defines centerPoint for the LanczosScale rendering
    func centerPointAttribute() -> PGLFilterAttributeVector {
        let inputDict: [String:Any] = [
            "CIAttributeIdentity" : [200, 200],
            "CIAttributeDefault" : [200, 200],
            "CIAttributeType" : kCIAttributeTypePosition,
            "CIAttributeDisplayName" : "Center" ,
            "kCIAttributeDescription": "Position of the frame",
            "CIAttributeClass":  "CIVector"
        ]
        let newVectorAttribute = PGLFilterAttributeVectorUI(pglFilter: self, attributeDict: inputDict, inputKey: kCIInputCenterKey)
        return newVectorAttribute!
    }
    override func outputImageBasic() -> CIImage? {
//        guard let scaledImage = localFilter.outputImage else { return CIImage.empty() }
        var scaledImage = super.outputImageBasic()
        if scaledImage == nil
            { return CIImage.empty() }
        if shouldMoveCenter {
            // centerPoint is workingSize-relative; positionOutput/fullScreenRect operate in
            // live RenderTargetSize pixels. This is identity when workingSize == RenderTargetSize
            // (the internal zoom/pan filter role, kept in sync by its owner) and a real
            // conversion when workingSize == FilterCanvasSize (the regular attribute-UI role).
            let liveCenter = centerPoint.applying(CGAffineTransform(
                scaleX: workingSize.width > 0 ? RenderTargetSize.width / workingSize.width : 1,
                y: workingSize.height > 0 ? RenderTargetSize.height / workingSize.height : 1))
            scaledImage = positionOutput(ciOutput: scaledImage!, inFrame: fullScreenRect, newCenterPoint: liveCenter)
        }
        // Blend the image over an opaque background image.
        // This is needed if the image is smaller than the view, or if it has transparent pixels.
        if addBackground {
            return scaledImage?.composited(over: self.opaqueBackground) ?? CIImage.empty()
        } else {
            return scaledImage ?? CIImage.empty()
        }
    }

    func positionOutput(ciOutput: CIImage, inFrame: CGRect, newCenterPoint: CGPoint ) -> CIImage {

        let iRect: CGRect = ciOutput.extent
        let imageCenter = CGPoint(x: iRect.midX, y: iRect.midY)
        let shiftX = newCenterPoint.x - imageCenter.x
        let shiftY =  newCenterPoint.y - imageCenter.y
        let ciOutputImage = ciOutput.transformed(by: CGAffineTransform(translationX: shiftX, y: shiftY))

        return ciOutputImage
     }

    /// set center point
    ///  cifilter does not hold the center point 
    override func setVectorValue(newValue: CIVector, keyName: String) {
//        logParm(#function, newValue.debugDescription, keyName)
//        shouldMoveCenter = true
        logParm(#function, newValue.debugDescription, keyName)
        centerPoint = CGPoint(x: newValue.x, y: newValue.y)
        postImageChange()
    }

    override func valueFor( keyName: String) -> Any? {
        if keyName == kCIInputCenterKey {
            return centerPoint
        } else {
           return super.valueFor(keyName: keyName)
        }
    }

}
