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

    var currentFrame: Int = 0
    var effectFrames: Int = 0
    var dissolveRunning = false
    let dissolveSeconds: Double = 0.5
    let framesPerSecond: Double = 60.0

    var dissolveFrames: Int!  //dissolveSeconds * framesPerSecond // 60 fps
    var dissolveDeltaPerFrame: Double! // dissolveSeconds / dissolveFrames

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
            // let framesPerSec: Float = 60.0 // later read actual framerate from UI
        effectFrames = Int(60.0 * 10) // 10 seconds per image
        dissolveFrames = Int(dissolveSeconds * framesPerSecond) // 60 fps
        dissolveDeltaPerFrame = dissolveSeconds / (dissolveSeconds * framesPerSecond)

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
            // called on every frame
            // two timing periods measured in frames
            // dissolveLength - frames of dissolve overlapping the panZoom filters
            //  effectLength  - the panZoom filter visible frames.
            //   dissolveLength is a subpart of the effectLength
            // two internal panZoom filters panImageFilter, panTargetFilter
            // send tick to visible panZoom filter to animate pan/zoom
            // during dissolve both panZoom filters get animation tick
            // increment to new image at completion of dissolve with the off screen filter
            // ui length slider sets movement length. dissolveLength is fixed ~0.5secs

            // measure in number of frames and increment on the target frame count
            //
            // see https://developer.apple.com/documentation/coreimage/customizing_image_transitions

            //       NSLog("PGLTransitionFilter #addFilterStepTime ")
            //        enum AttributeKey: String {
            //            case kCIInputImageKey
            //            case kCIInputTargetImageKey
            //        }
        var currentPanZoom: PGLScaleUpFrame?
        var nextPanZoom: PGLScaleUpFrame?
        var dissolveNextAttribute = attribute(nameKey: kCIInputTargetImageKey)
            // initially kCIInputTargetImageKey is offscreen
            // initially the kCIInputImageKey is the currentDisplay

        if (effectFrames == 0) {
                // no dissolve set
            return
        }

        currentFrame += 1
        if  currentFrame >= effectFrames {
                // need to start next loop
            currentFrame = 0
            dissolveRunning = true
//            NSLog(#function + String(describing: self) + " dissolveRunning to TRUE")
        }

        if dissolveRunning {
            if transitionFilterStepTime < 0.0 {

                transitionFilterStepTime = 0.0
                dissolveRunning = false
//                NSLog(#function + String(describing: self) + " dissolveRunning to FALSE case <=0.0")
                currentPanZoom = panImageFilter
                nextPanZoom = panTargetFilter
                dissolveDeltaPerFrame = abs( dissolveDeltaPerFrame) // make it positive
//                NSLog(#function + String(describing: self) + " change dissolveDeltaPerFrame \(dissolveDeltaPerFrame)")
                    // set to positive to increment
                    // increment image of offscreen effect
                dissolveNextAttribute = attribute(nameKey: kCIInputTargetImageKey)
                if (dissolveNextAttribute != nil) {
                    incrementOnAttribute(attribute: dissolveNextAttribute!)
//                    NSLog(#function + String(describing: self) + " kCIInputTargetImageKey increment")
                }
            }
            if  transitionFilterStepTime > 1.0 {
                transitionFilterStepTime = 1.0
                dissolveRunning = false
//                NSLog(#function + String(describing: self) + " dissolveRunning to FALSE case >1.0")
                currentPanZoom = panTargetFilter
                nextPanZoom = panImageFilter
                dissolveDeltaPerFrame = -1 * dissolveDeltaPerFrame
//                NSLog(#function + String(describing: self) + " change dissolveDeltaPerFrame \(dissolveDeltaPerFrame)")
                    // set negative to decrement
                dissolveNextAttribute = attribute(nameKey: kCIInputImageKey)
                if (dissolveNextAttribute != nil) {
                    incrementOnAttribute(attribute: dissolveNextAttribute!)
//                    NSLog(#function + String(describing: self) + " kCIInputImageKey increment")
                }
            }
                // move the dissolve ahead
            transitionFilterStepTime += dissolveDeltaPerFrame
            let inputTime = simd_smoothstep(0, 1, transitionFilterStepTime)
            localFilter.setValue(inputTime, forKey: kCIInputTimeKey)
//            NSLog(#function + String(describing: self) + " dissolve inputTime set to \(inputTime)")

        } // end dissolveRunning = true

        currentPanZoom?.addFilterStepTime()
        if dissolveRunning {
                // both filters need to animate during dissolve
            nextPanZoom?.addFilterStepTime()
        }

    }

    override func setTimerDt(lengthSeconds: Float) {

        let framesPerSec: Float = 60.0 // later read actual framerate from UI
        effectFrames = Int(framesPerSec * lengthSeconds)

        logParm(#function, lengthSeconds.debugDescription, self.localizedName())

    }

    func incrementOnAttribute(attribute: PGLFilterAttribute) {
        // set the next image as the input to the matching panFilter
        // is it target or input attribute of the dissolve
        var changeTarget: PGLScaleUpFrame

        let isInputTarget = (attribute.attributeName == kCIInputImageKey)
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
//            NSLog(#function + String(describing: self) + "changing image " + String(describing: attribute.attributeName ))

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

  override  func setUserPick(attribute: PGLFilterAttribute, imageList: PGLImageList) {
      // put the first images into the panZoom for initial display

      super.setUserPick(attribute: attribute, imageList: imageList)

      var dissolveNextAttribute = self.attribute(nameKey: kCIInputImageKey) as? PGLFilterAttributeImage

      if (dissolveNextAttribute != nil) {
          incrementOnAttribute(attribute: dissolveNextAttribute!)
      }

       dissolveNextAttribute = self.attribute(nameKey: kCIInputTargetImageKey) as? PGLFilterAttributeImage

      if (dissolveNextAttribute != nil) {
          incrementOnAttribute(attribute: dissolveNextAttribute!)
      }


    }



}
