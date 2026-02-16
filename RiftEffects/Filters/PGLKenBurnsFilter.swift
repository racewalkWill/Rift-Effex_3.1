//
//  PGLKenBurnsFilter.swift
//  RiftEffects
//
//  Created by Will on 2/15/26.
//  Copyright © 2026 Will Loew-Blosser. All rights reserved.
//

import Foundation
import CoreImage
import simd
import UIKit
import os

/// Ken Burns style disssolve with slow pan, zoom on each image
class PGLKenBurnsFilter: PGLTransitionFilter {
    // use two MaximiumScaleTransformFilters input to Dissolve
    // inputImageList feeds each altenatively
    // alternate between with preset vary on pan, zoom
    // only increment imageList when offscreen

    override class func displayName() -> String? {
        return kKenBurnsDissolve
    }

//    var dissolveFilter: PGLTransitionFilter
        // dissolve is the output filter
    var panImageFilter: PGLScaleUpFrame // kCIInputImageKey
    var panTargetFilter: PGLScaleUpFrame //kCIInputTargetImageKey

    required init?(filter: String, position: PGLFilterCategoryIndex) {
//        let dissolveDescriptor = PGLFilterDescriptor("CIDissolveTransition" , PGLTransitionFilter.self)!
            // "CIDissolveTransition" : [  PGLTransitionFilter.self  ],
        // add to the CIFilterToPGLFilter.Map

        let panImageDescriptor = PGLFilterDescriptor("CIMaximumScaleTransform", PGLScaleUpFrame.self)!

        let panBackgroundDescriptor = PGLFilterDescriptor("CIMaximumScaleTransform", PGLScaleUpFrame.self)!
            // on UI select of a linear attribute then 2 subcells of 2 values

//        dissolveFilter = dissolveDescriptor.pglSourceFilter() as! PGLTransitionFilter
        panImageFilter = panImageDescriptor.pglSourceFilter() as! PGLScaleUpFrame
        panTargetFilter =  panBackgroundDescriptor.pglSourceFilter() as! PGLScaleUpFrame
        panImageFilter.setDefaults()
        panTargetFilter.setDefaults()

        super.init(filter: filter, position: position)
    }

    override class func localizedDescription(filterName: String) -> String {
        // custom subclasses should override
       return "Ken Burns Style dissolve"
    }

//    func incrementImageLists() {
//        // send increment to the image parm lists
//        for anImageParm in imageParms() ?? [PGLFilterAttributeImage]() {
//            _ = anImageParm.inputCollection?.increment()
//        }
//    }
    override  func outputImageBasic() -> CIImage? {
        // get input/output assigned with the panImage and panBackground
        // which is visible .. during dissolve both are visible
        // start using both for output

        // steps in the superClass implementation
        addFilterStepTime()  // if animation then move time forward
        updateImageVideoFrames()

        for anAttribute in attributes {
                    anAttribute.updateFromInputStack()
                }
        if hasImageParmMissingInput() {
            return CIImage.empty()

        }

        let imagePan = panImageFilter.outputImageBasic() ?? CIImage.empty()
       let backgroundPan = panTargetFilter.outputImageBasic() ?? CIImage.empty()

        // put the panZoom images into the dissolv filter
        self.setImageValue(newValue: imagePan, keyName: kCIInputImageKey)
        self.setImageValue(newValue: backgroundPan, keyName:kCIInputTargetImageKey)

        let outputImage = localFilter.outputImage
        return outputImage

    }

//    func updateInputs(detector: any PGLDetection) {
////        let theFaceImages = detector.featureImagePair()
//        self.setImageValue(newValue: theFaceImages.inputFeature, keyName: kCIInputImageKey)
//        self.setImageValue(newValue: theFaceImages.targetFeature, keyName:kCIInputTargetImageKey)
//    }

    override func addFilterStepTime() {
            // detectors.. They are incrementing imageList inputs
            // stepTime for transition Filters range is 0 - 1.0
            // does not go below zero
            // see https://developer.apple.com/documentation/coreimage/customizing_image_transitions

    //       NSLog("PGLTransitionFilter #addFilterStepTime ")
            var nextAttribute: PGLFilterAttribute?
            var doIncrement = false
            if (transitionFilterStepTime >= 1.0)   {
                transitionFilterStepTime = 1.0 // bring it back in range
                doIncrement = true
                dt = dt * -1 // past end so toggle
                // this has animation
                // get the input collection
               nextAttribute = getInputImageAttribute() //kCIInputImageKey
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
                // increment the input to the panFilter
                incrementOnAttribute(attribute: nextAttribute!)
                // super class does nextAttribute?.increment()
                    // advances to the next image in the input imageList
            }
        if nextAttribute == nil {
            NSLog("PGLTransitionFilter #addFilterStepTime nextAttribute is nil")
            nextAttribute = getInputImageAttribute() //kCIInputImageKey
            incrementOnAttribute(attribute: nextAttribute!)
        }

            // go back and forth between 0 and 1.0
            // toggle dt either neg or positive
            transitionFilterStepTime += dt
            let inputTime = simd_smoothstep(0, 1, transitionFilterStepTime)

            // dissolve specific
            localFilter.setValue(inputTime, forKey: kCIInputTimeKey)

            /// call super for other vary attributes


        }

    func incrementOnAttribute(attribute: PGLFilterAttribute) {
        // set the next image as the input to the matching panFilter
        // is it target or input attribute of the dissolve
        var changeTarget: PGLScaleUpFrame

        let isInputTarget = (attribute.attributeName == kCIInputTargetImageKey)
        if isInputTarget {
             changeTarget = panImageFilter
        } else {
            changeTarget = panTargetFilter
        }
        let dissolveImageList = attribute.inputCollection
//        let nextImage = isInputTarget ? dissolveImageList[0] : dissolveImageList[1]
        if let nextImage = dissolveImageList?.increment() {
             changeTarget.setImageValue(newValue: nextImage, keyName: kCIInputImageKey)
            changeTarget.setInputImageParmState(newState: .inputPhoto)

            //  setImageValue puts the image directly into the filter
            // ? setImageCollectionInput(cycleStack: imageList)
//            let listForNextImage = PGLImageList(image: nextImage)
//            changeTarget.setImageCollectionInput(cycleStack: listForNextImage)

        }


    }

//
//    override func setRandomTimerDt() {
//
//    }



}
