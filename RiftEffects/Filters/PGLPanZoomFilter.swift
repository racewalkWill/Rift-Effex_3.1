//
//  PGLPanZoomFilter.swift
//  RiftEffects
//
//  Created by Will on 2/18/26.
//  Copyright © 2026 Will Loew-Blosser. All rights reserved.
//

import Foundation
import CoreImage
import simd
import UIKit
import os

    /// automatic  pan vary and zoom vary on the center and scale parms
class PGLPanZoomFilter: PGLScaleUpFrame {
    override class func localizedDescription(filterName: String) -> String {
        // custom subclasses should override
       return "Pans and Zooms the image in continous vary loops"
    }

    override class func displayName() -> String? {

        // FilterDescriptor will use the ciFilter.localizedName if this is nil.
        // where a ciFilter is used with different pglSourceFilter classes then this method should be implemented
        // by the subclass
        return kPanZoom
    }

   override func localizedName() -> String {
      return kPanZoom
    }

    // for the two parms
    // #setAnimationTimerDt
    // aSourceFilter.animate(attributeTarget: self)
    //   uses startAnimation(attributeTarget: attributeTarget)
    //   which in turn cslls
    //    startAnimationBasic(attributeTarget: attributeTarget)
    //    attributeTarget.setAnimationTimerDt(lengthSeconds: (Float(defaultDt) * 1000))

    func setPanZoomDefault() {
//        setNumberValue(newValue:1.940563 , keyName:"inputScale")

        if let scaleInputParm = attribute(nameKey: "inputScale") {
            startAnimation(attributeTarget: scaleInputParm)
            scaleInputParm.sliderMaxValue = 1.2
            scaleInputParm.setAnimationTimerDt(lengthSeconds: 50.0)
            // shorter values make faster motion

        }

        if let centerPointParm = attribute(nameKey: kCIInputCenterKey) as? PGLFilterAttributeVector {

                // change the filter's centerPoint to one of the random points
            setRandomParms()
            centerPointParm.setRandomVectorEndPoint()
            centerPointParm.performAction(nil)
            startAnimation(attributeTarget: centerPointParm)
            centerPointParm.setAnimationTimerDt(lengthSeconds: 60.0)
        }



    }

    override func setDefaults() {
        super.setDefaults()
        setPanZoomDefault()



    }

    override func setRandomParms() {
        centerPoint = randomCenterPoint()
    }

    func randomCenterPoint() -> CGPoint {
        var center: CGPoint = .zero
        let x: CGFloat = CGFloat.random(in: 0.0...1.0)
        let y: CGFloat = CGFloat.random(in: 0.0...1.0)
        let normalizedCenter = CGPoint(x: x, y: y)

        if let myInputImage = inputImage() {
            let inputWidthReduced = (myInputImage.extent.size.width) - 50
            let inputHeightReduced = (myInputImage.extent.height) - 50
             center = CGPoint(x: normalizedCenter.x * inputWidthReduced,
                                 y: normalizedCenter.y * inputHeightReduced)
        } else {
            center = CGPoint( x: (TargetSize.width / 2 ), y: (TargetSize.height / 2)  )

        }
        NSLog(#function + String(describing: self) + " center = \(center) ")
        return center
    }

    
}
