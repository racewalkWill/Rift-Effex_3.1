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

enum ZoomDirection: Float, CaseIterable  {
    case   zoomOut = -1
    case   zoomIn = 1
    case   zoomNone = 0

    static func random<G: RandomNumberGenerator>(using generator: inout G) -> ZoomDirection {
        return ZoomDirection.allCases.randomElement(using: &generator)!
        }
    static func random() -> ZoomDirection {
           var g = SystemRandomNumberGenerator()
           return ZoomDirection.random(using: &g)
       }
    }

enum PanDirection: Double, CaseIterable {
    case   panLeft = -1
    case   panRight = 1
    case   panNone = 0

    static func random<G: RandomNumberGenerator>(using generator: inout G) -> PanDirection {
        return PanDirection.allCases.randomElement(using: &generator)!
        }
    static func random() -> PanDirection {
           var g = SystemRandomNumberGenerator()
           return PanDirection.random(using: &g)
       }
}
    /// automatic  pan vary and zoom vary on the center and scale parms
class PGLPanZoomFilter: PGLScaleUpFrame {


    let zoomMaxFactor: CGFloat = 3.0
    let zoomMinFactor: CGFloat = 1.03

    // for setAnimationTimerDt
    // shorter is faster movement
    let panAnimation: Float = 20 // 100.0
//    let zoomAnimation: Float = 300 // 60.0
    var panFactor: Double = 1.15     // change to tuple of min,max
    var zoomFactor: Float = 1.40  // change to tuple of min,max


    override class func localizedDescription(filterName: String) -> String {
        // custom subclasses should override
       return NSLocalizedString("Pans and Zooms the image in continous vary loops", comment: "Pan Zoom custom filter description")
    }

    override class func displayName() -> String? {

        // FilterDescriptor will use the ciFilter.localizedName if this is nil.
        // where a ciFilter is used with different pglSourceFilter classes then this method should be implemented
        // by the subclass
        return NSLocalizedString("Pan Zoom", comment: "Pan Zoom filter display name")
    }

   override func localizedName() -> String {
      return NSLocalizedString("Pan Zoom", comment: "Pan Zoom filter display name")
    }

    override func setDefaults() {
        super.setDefaults()
        let defaultPoint = defaultCenterPoint()
        let defaultVector = CIVector(x: defaultPoint.x, y: defaultPoint.y)
        setVectorValue(newValue: defaultVector, keyName: kCIInputCenterKey)
//        zoomFactor = 1.40
//        panFactor = 1.15
    }
    // for the two parms
    // #setAnimationTimerDt
    // aSourceFilter.animate(attributeTarget: self)
    //   uses startAnimation(attributeTarget: attributeTarget)
    //   which in turn cslls
    //    startAnimationBasic(attributeTarget: attributeTarget)
    //    attributeTarget.setAnimationTimerDt(lengthSeconds: (Float(defaultDt) * 1000))

    func setZoomDelta(zoomDirection: ZoomDirection = .zoomNone) {
        // reset value from the setAnimationTimerDt
        // varyTotalFrames was set by the lengthSeconds
        // just use a fixed rate of change either zoom out, in or none
        let defaultZoomDivisor: Float = 4.0

        guard let scaleInputParm = attribute(nameKey: "inputScale")
            else    { return }

        let attributeValueRange = (scaleInputParm.sliderMaxValue ?? 100.0) - (scaleInputParm.sliderMinValue ?? 0.0)
            // some filters do not define max or min values..

            // for total frames to increment to value
        if (scaleInputParm.varyTotalFrames > 0 ) // check for zero division nan
        {
            let newDelta = (attributeValueRange / Float(scaleInputParm.varyTotalFrames)) / defaultZoomDivisor
            scaleInputParm.attributeValueDelta =  newDelta * zoomDirection.rawValue
                // zoomDirection values -1, 0, or +1
            // hasAnimation is now true with value in attributeValueDelta
            NSLog(#function + String(describing: self) + " new delta \(String(describing: scaleInputParm.attributeValueDelta))")
        }

    }
    func setPanZoomDefault(panDirection: PanDirection = .panNone, zoomDirection: ZoomDirection = .zoomNone) {
//        setNumberValue(newValue:1.940563 , keyName:"inputScale")
        setDefaults() // back to start

        NSLog(#function + String(describing: self))
        guard let scaleInputParm = attribute(nameKey: "inputScale")
            else    { return }

//        scaleInputParm.set(1.3)
        scaleInputParm.sliderMaxValue = Float(zoomMaxFactor) //allowed range is 0.1 - 10.0
        let startingScale = CGFloat.random(in: zoomMinFactor...zoomMaxFactor)
                // slightly zoomed to really zoomed in
        scaleInputParm.set(startingScale)
        if zoomDirection != .zoomNone {
            if !hasAnimation {
                startAnimation(attributeTarget: scaleInputParm)
            }
            setZoomDelta(zoomDirection: zoomDirection)
            scaleInputParm.varyStepCounter = 0
            scaleInputParm.varyTotalFrames = Int(60.0 * panAnimation * 2)
        }

        guard let  centerPointParm =  attribute(nameKey: kCIInputCenterKey) as? PGLFilterAttributeVector
            else    { return }
        if   panDirection != .panNone  {
            // starting from frame center
            centerPoint = CGPoint( x: (RenderTargetSize.width / 2 ), y: (RenderTargetSize.height / 2) )

                    // change the filter's centerPoint to one of the random points
                    // setRandomParms()
                    //            centerPointParm.setRandomVectorEndPoint()

                    // centerPointParm.performAction(nil)
                    //  vectorPerformAction callse setRandomVectorEndPoint

                    // startAnimation(attributeTarget: centerPointParm)
                //setPanOffset(pan: pan)
//                setRandomParms() // only the centerPoint
                centerPointParm.setRandomVectorStartPoint()
                centerPointParm.setRandomVectorEndPoint()
                centerPointParm.varyState = .VaryPt1Pt2 // move to next state for both
//                centerPointParm.varyStepCounter = 0
                // varyStepCounter is reset in the setRandomVectorStartPoint & EndPoint
                if centerPointParm.incrementDirection < 0 {
                    // make it count up from zero
                    centerPointParm.incrementDirection = centerPointParm.incrementDirection * -1
                    }
                // start the animation when the dissolve is starting to bring it on screen
//                startAnimation(attributeTarget: scaleInputParm)
                centerPointParm.setAnimationTimerDt(lengthSeconds: panAnimation * 2)
                // do not use the superclass animationTimerDt lenghtSeconcs

                    // make it bigger so it does not change direction in the middle
                    // when varyStepCounter goes larger the the varyTotalFrames then the direction flips

                animationAttributes.removeAll { $0 === centerPointParm }
                startAnimationBasic(attributeTarget: centerPointParm)

                // use startMovement to set the lengthSeconds at the time it comes on screen
               // centerPointParm.setAnimationTimerDt(lengthSeconds: panAnimation)

            }

    }
//   override func outputImageBasic() -> CIImage? {
//        let myOutput = super.outputImageBasic()
//       NSLog("PGLPanZoomFilter.outputImageBasic() myOutput: \(String(describing: myOutput))")
//        return myOutput
//    }


    override func setRandomParms() {
        centerPoint = randomCenterPoint()
    }

    func randomCenterPoint() -> CGPoint {
        // default to center
        var center: CGPoint = CGPoint( x: (RenderTargetSize.width / 2 ), y: (RenderTargetSize.height / 2) )

        let x: CGFloat = CGFloat.random(in: 0.0...1.0)
        let y: CGFloat = CGFloat.random(in: 0.0...1.0)
        let normalizedRandomPoint = CGPoint(x: x, y: y)

        if let myInputImage = inputImage() {
            let inputWidthReduced = (myInputImage.extent.size.width) / 2
            let inputHeightReduced = (myInputImage.extent.height) / 2
             center = CGPoint(x: normalizedRandomPoint.x * inputWidthReduced,
                                 y: normalizedRandomPoint.y * inputHeightReduced)
        }
        NSLog(#function + String(describing: self) + " center = \(center) ")
        return center
    }

    
}
