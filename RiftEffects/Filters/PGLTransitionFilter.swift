//
//  PGLTransitionFilter.swift
//  Glance
//
//  Created by Will on 1/24/19.
//  Copyright © 2019 Will. All rights reserved.
//

import Foundation
import CoreImage
import simd

class PGLTransitionFilter: PGLRectangleFilter {
    // Subclass of cropFilter to use the interface for rectangle extents for parms that are rectangles.
    // see rectangle parms in CIClamp CISwipeTransition CIFlashTransition
    //          CICopyMachineTransition  CIRippleTransition etc..
    // see CIFilter class func pglClassMap()
//    pglFilterClassDict:[String: PGLSourceFilter.Type] =
//    ["CICrop": PGLCropFilter.self ,
//    "FaceFilter": PGLDetectorFilter.self,
//    "CIDissolveTransition" : PGLTransitionFilter.self ,
//    ....
//      the CIFilter works with this PGLSourceFilter to trigger
    // PGLFilterCategory static func getFilterDescriptor

    var transitionFilterStepTime = 0.0
    var isRandomTime: Bool = false


    /// can pause or go if there are multiple inputs for transition
    ///  several parms can have one input or at least one parm has multiple inputs
//    var hasMultipleTransitionInputs =  false

    required init?(filter: String, position: PGLFilterCategoryIndex) {
        super.init(filter: filter, position: position)
            //        hasAnimation = true
        // set animation to true when there are multiple inputs or parms are animated
    }

    override func scaleOutput(ciOutput: CIImage, stackCropRect: CGRect) -> CIImage {
            // empty implementation answers the input
            // subclassses such as PGLRectangleFilter which crops implement
            // only the superclass PGLRectangle needs this method..
        
            return ciOutput
        }

    override func addFilterStepTime() {
        // PGLTransitionFilters do not increment or send time to the
        // detectors.. They are incrementing imageList inputs
        // stepTime for transition Filters range is 0 - 1.0
        // does not go below zero
        // see https://developer.apple.com/documentation/coreimage/customizing_image_transitions

//       NSLog("PGLTransitionFilter #addFilterStepTime ")
        for parm in animationAttributes {
            parm.addAnimationStepTime()
            }

        var nextAttribute: PGLFilterAttribute?
        var doIncrement = false
        if (transitionFilterStepTime >= 1.0)   {
            transitionFilterStepTime = 1.0 // bring it back in range
            doIncrement = true
            dt = dt * -1 // past end so toggle
            // this has animation
            // get the input collection
           nextAttribute = getInputImageAttribute() //kCIInputTargetImageKey
        }
        else if (transitionFilterStepTime <= 0.0) {
            transitionFilterStepTime = 0.0 // bring it back in range
            doIncrement = true
            dt = dt * -1 // past end so toggle
            if  isRandomTime {
                // new dt has to be positive
//                NSLog("PGLTransitionFilter #addFilterStepTime calling setRandomTimerDt")
                   setRandomTimerDt()
               }

            nextAttribute = attribute(nameKey: kCIInputTargetImageKey  ) //kCIInputImageKey
        }
        if doIncrement {

            nextAttribute?.increment()
                // advances to the next image in the input imageList
        }

        // go back and forth between 0 and 1.0
        // toggle dt either neg or positive
        transitionFilterStepTime += dt
        let inputTime = simd_smoothstep(0, 1, transitionFilterStepTime)

        // dissolve specific
        localFilter.setValue(inputTime, forKey: kCIInputTimeKey)

        /// call super for other vary attributes
        updateImageVideoFrames()

    }
    func setRandomTimerDt() {
        // allowed range is 0.2 to 10 sec Positive number
        let newRandomeRate: Float = Float.random(in: 0.1...7)
//        NSLog("PGLTransitionFilter #setRandomTimerDt new lengthSeconds = \(newRandomeRate)")
        setTimerDt(lengthSeconds: newRandomeRate )
    }

        /// set the dt (deltaTime) for use by addStepTime() on each frame
    override func setTimerDt(lengthSeconds: Float) {
        // Super class does not use this
        // timer is 0..1 range
        // dt should be the amount of change to add to the input time
        // to make the dissolve in lenghtSeconds total. This is also the incrment time
        // from one image to another.
        userLengthSeconds = lengthSeconds
        let framesPerSec: Float = 60.0 // later read actual framerate from UI
        let varyTotalFrames = framesPerSec * lengthSeconds

        let attributeValueRange = 1.0 // transition range is 0..1
        if varyTotalFrames > 0.0 {
            // division by zero is nan
//            NSLog("setTimerDt old \(dt)")
            dt = attributeValueRange / Double(varyTotalFrames)
//            NSLog("setTimerDt NEW        \(dt)")
        }

        logParm(#function, lengthSeconds.debugDescription, self.localizedName())

    }

    override func setImageListClone(imageList: PGLImageList, sourceKey: String) {
        // PGLTransitionFilter subclass will  clone cycleStack to other parms
        // set source and clone to odd/even increments.. one increments on odd elements, the other even
        // assumes a transition filter has at least two image input parms

        // only clone when setting the first image input
        let myImageKeys = imageInputAttributeKeys
        if myImageKeys.first != sourceKey { return}
        
        if imageList.nextType == NextElement.odd { return }
            // stop.. don't make a further clone. Even stack clones odd stack and stops
        
        if let nextImageParmKey = (imageInputAttributeKeys.first { (aParmKey: String) -> Bool in
            aParmKey != sourceKey })
            {
                if let nextImageAttribute = attribute(nameKey: nextImageParmKey) {
//                    NSLog("PGLTransitionFilter setImageListClone(cycleStack: nextImageAttribute = \(nextImageAttribute)")
                    if nextImageAttribute .isSingluar() {
//                        NSLog("PGLTransitionFilter setImageListClone(cycleStack: nextImageAttribute isSingluar - return")
                        return // don't clone
                    } else {
                        if nextImageAttribute.hasImageInput()  ?? false {
                        // change the inputCollection.nextType to each state
                        // don't do a clone
                            imageList.nextType = NextElement.each
                            nextImageAttribute.setToIncrementEach()
//                            NSLog("PGLTransitionFilter does not clone a rotation - increments each input #setImageListClone(cycleStack: PGLImageList, sourceKey: String) {")
//                            _ = notifyTransitionsExist()
                            return
                        }
//                        NSLog("PGLTransitionFilter setImageListClone(cycleStack:  else branch on noImageInput")
                    }

                NSLog("PGLTransitionFilter setImageListClone(cycleStack:  cycleStack.cloneEven")
                let nextParmList = imageList.cloneEven(toParm: nextImageAttribute)
                    // sets this cycleStack to odd numbered increments.
                nextImageAttribute.setImageCollectionInput(cycleStack: nextParmList)
                nextImageAttribute.setImageParmState(newState: .inputPhoto)

//                     NSLog("PGLTransitionFilter setImageListClone(cycleStack: evenStack set to nextImageAttribute input")
                }
        }

    }


    func removeTransitionCounts() {
        // when transition filter is removed from a stack
        // subtract from the PGLNeedsRedraw
        guard let myImageParms = imageParms() else { return }
        for anImageParm in myImageParms {
            anImageParm.removeTransitionCounts()
        }
    }
    func addTransitionCounts() {
        // when transition filter is added to a stack
        // add to the PGLNeedsRedraw transition count
        guard let myImageParms = imageParms() else { return }
        for anImageParm in myImageParms {
            anImageParm.addTransitionCounts()
        }
    }
}

