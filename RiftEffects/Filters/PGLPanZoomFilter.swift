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


    let zoomMaxFactor: Float = 1.2
    let zoomMinFactor: Float = 0.8

    // for setAnimationTimerDt
    // shorter is faster movement
    var panAnimation: Float = 100.0
    var zoomAnimation: Float = 60.0
    var panFactor: Double = 1.15     // change to tuple of min,max
    var zoomFactor: Float = 1.40  // change to tuple of min,max


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

    func setPanZoomDefault(pan: PanDirection = .panNone, zoom: ZoomDirection = .zoomNone) {
//        setNumberValue(newValue:1.940563 , keyName:"inputScale")
        setDefaults() // back to start
        NSLog(#function + String(describing: self))
        guard let scaleInputParm = attribute(nameKey: "inputScale")
            else    { return }

        scaleInputParm.set(1.5)
        if zoom != .zoomNone {

             //   startAnimation(attributeTarget: scaleInputParm)
//            scaleInputParm.attributeValueDelta = 2.0
                startAnimationBasic(attributeTarget: scaleInputParm)
                scaleInputParm.sliderMaxValue = zoomMaxFactor //allowed range is 0.1 - 10.0

            // use startMovement to set the lengthSeconds at the time it comes on screen
               // scaleInputParm.setAnimationTimerDt(lengthSeconds: zoomAnimation)
                // shorter values make faster motion

                //zoomaAnimation sets an initial attributeValueDelta
                // slow it down even more
                if let delta = (scaleInputParm.attributeValueDelta) {
                        // zoom.rawValue is -1, 0 , or +1
                    NSLog(#function + String(describing: self) + " delta \(String(describing: delta))")
                        let newDelta = (delta * zoom.rawValue) / 2
                    NSLog(#function + String(describing: self) + " new delta \(String(describing: newDelta))")
                        scaleInputParm.attributeValueDelta =  newDelta
                    }

        }
        guard let  centerPointParm =  attribute(nameKey: kCIInputCenterKey) as? PGLFilterAttributeVector
            else    { return }
        if   pan != .panNone  {
            // starting from frame center
            centerPoint = CGPoint( x: (TargetSize.width / 2 ), y: (TargetSize.height / 2) )

                    // change the filter's centerPoint to one of the random points
                    // setRandomParms()
                    //            centerPointParm.setRandomVectorEndPoint()

                    // centerPointParm.performAction(nil)
                    //  vectorPerformAction callse setRandomVectorEndPoint

                    // startAnimation(attributeTarget: centerPointParm)
                //setPanOffset(pan: pan)
//                setRandomParms() // only the centerPoint
                centerPointParm.setVectorStartPoint()
                centerPointParm.setRandomVectorEndPoint()
                centerPointParm.varyState = .VaryPt1Pt2 // move to next state for both
                centerPointParm.varyStepCounter = 0
                if centerPointParm.incrementDirection < 0 {
                    // make it count up from zero
                    centerPointParm.incrementDirection = centerPointParm.incrementDirection * -1
                    }
                // start the animation when the dissolve is starting to bring it on screen
                startAnimationBasic(attributeTarget: centerPointParm)

                // use startMovement to set the lengthSeconds at the time it comes on screen
               // centerPointParm.setAnimationTimerDt(lengthSeconds: panAnimation)

            }

    }

    func startMovement() {
            // use startMovement to set the lengthSeconds at the time it comes on screen
               // scaleInputParm.setAnimationTimerDt(lengthSeconds: zoomAnimation)
                // shorter values make faster motion

                //zoomAnimation sets an initial attributeValueDelta

        guard let scaleInputParm = attribute(nameKey: "inputScale")
            else    { return }

        scaleInputParm.setAnimationTimerDt(lengthSeconds: zoomAnimation)

        guard let  centerPointParm =  attribute(nameKey: kCIInputCenterKey) as? PGLFilterAttributeVector
            else    { return }
        centerPointParm.setAnimationTimerDt(lengthSeconds: panAnimation)

    }

    func stopMovement() {
        guard let scaleInputParm = attribute(nameKey: "inputScale")
            else    { return }
        scaleInputParm.setAnimationTimerDt(lengthSeconds: 0)

        guard let  centerPointParm =  attribute(nameKey: kCIInputCenterKey) as? PGLFilterAttributeVector
            else    { return }
        centerPointParm.setAnimationTimerDt(lengthSeconds: 0)
    }

    func setPanOffset(pan: PanDirection) {
        // center point moves from default
        let centerCurrentX: Double = Double (centerPoint.x)
        let centerCurrentY  =  (centerPoint.y)

        if pan != .panNone {
            // pan is -1, or +1
            let newCenterX = centerCurrentX * panFactor * pan.rawValue
            centerPoint = CGPoint(x: newCenterX, y: centerCurrentY)
        }

    }

    func setZoomInStart() {
//        let scaleCurrent: CGFloat = inputScale
//        
//        let newScale: CGFloat = scaleCurrent * zoomFactor
//        
//        setNumberValue(newValue: newScale, keyName:"inputScale")    
    }

//    override func setDefaults() {
//        super.setDefaults()
//        setPanZoomDefault()
//
//
//
//    }

    override func setRandomParms() {
        centerPoint = randomCenterPoint()
    }

    func randomCenterPoint() -> CGPoint {
        // default to center
        var center: CGPoint = CGPoint( x: (TargetSize.width / 2 ), y: (TargetSize.height / 2) )

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
