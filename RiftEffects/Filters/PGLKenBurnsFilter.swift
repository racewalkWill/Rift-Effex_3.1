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
    var panImageFilter: PGLPanZoomFilter // kCIInputImageKey
    var panTargetFilter: PGLPanZoomFilter //kCIInputTargetImageKey

    var currentFrame: Int = 0
    var effectFrames: Int = 0
    var dissolveRunning = false
    let dissolveSeconds: Double = 0.8
    let framesPerSecond: Double = 60.0

    var dissolveFrames: Int!  //dissolveSeconds * framesPerSecond // 60 fps
    var dissolveDeltaPerFrame: Double! // dissolveSeconds / dissolveFrames



    required init?(filter: String, position: PGLFilterCategoryIndex) {
            //        let dissolveDescriptor = PGLFilterDescriptor("CIDissolveTransition" , PGLTransitionFilter.self)!
            // "CIDissolveTransition" : [  PGLTransitionFilter.self  ],
            // add to the CIFilterToPGLFilter.Map

        let panImageDescriptor = PGLFilterDescriptor("CIMaximumScaleTransform", PGLPanZoomFilter.self)!

        let panBackgroundDescriptor = PGLFilterDescriptor("CIMaximumScaleTransform", PGLPanZoomFilter.self)!
            // on UI select of a linear attribute then 2 subcells of 2 values

            //        dissolveFilter = dissolveDescriptor.pglSourceFilter() as! PGLTransitionFilter
        panImageFilter = panImageDescriptor.pglSourceFilter() as! PGLPanZoomFilter
        panTargetFilter =  panBackgroundDescriptor.pglSourceFilter() as! PGLPanZoomFilter

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
//            NSLog("\(#function): KenBurnsFilter parm missing input")
            return CIImage.empty()

        }

       guard let imagePan = panImageFilter.outputImageBasic()
        else {
           NSLog("\(#function): no imagePan")
           return CIImage.empty()}
        guard let backgroundPan = panTargetFilter.outputImageBasic()
        else {
            NSLog("\(#function): no imagePan")
            return CIImage.empty()
        }


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

        var dissolveNextAttribute = attribute(nameKey: kCIInputTargetImageKey)
            // initially kCIInputTargetImageKey is offscreen
            // initially the kCIInputImageKey is the currentDisplay
        var currentPanZoom: PGLPanZoomFilter?
        var nextPanZoom: PGLPanZoomFilter?

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
//        if currentFrame >= (effectFrames - 5) {
//            // getting close to starting the dissolve
//            // start the movement
//            // currentPanZoom?.startMovement()
//            nextPanZoom?.startMovement()
//        }

        if dissolveRunning {
            if transitionFilterStepTime < 0.0 {

                transitionFilterStepTime = 0.0
                dissolveRunning = false
//                NSLog(#function + String(describing: self) + " dissolveRunning to FALSE case <=0.0")
                currentPanZoom = panImageFilter
                nextPanZoom = panTargetFilter
                dissolveDeltaPerFrame = abs( dissolveDeltaPerFrame) // make it positive
                NSLog(#function + String(describing: self) + " change dissolveDeltaPerFrame \(String(describing: dissolveDeltaPerFrame))")
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
                NSLog(#function + String(describing: self) + " change dissolveDeltaPerFrame \(String(describing: dissolveDeltaPerFrame))")
                    // set negative to decrement
                dissolveNextAttribute = attribute(nameKey: kCIInputImageKey)
                if (dissolveNextAttribute != nil) {
                    incrementOnAttribute(attribute: dissolveNextAttribute!)
//                    NSLog(#function + String(describing: self) + " kCIInputImageKey increment")
                }
            }

//            currentPanZoom?.startMovement()
//            nextPanZoom?.stopMovement()
                // move the dissolve ahead
            transitionFilterStepTime += dissolveDeltaPerFrame
            let inputTime = simd_smoothstep(0, 1, transitionFilterStepTime)
            localFilter.setValue(inputTime, forKey: kCIInputTimeKey)
//            NSLog(#function + String(describing: self) + " dissolve inputTime set to \(inputTime)")

        } // end dissolveRunning = true

        currentPanZoom?.addFilterStepTime()
            // if dissolve is not running then the off screen panZoom is not
            // stepped forward !
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
        var changeTarget: PGLPanZoomFilter

        let isInputTarget = (attribute.attributeName == kCIInputImageKey)
        if isInputTarget {
             changeTarget = panImageFilter
        } else {
            changeTarget = panTargetFilter
        }
        let dissolveImageList = attribute.inputCollection

        if let nextImage = dissolveImageList?.increment() {
            changeTarget.setImageValue(newValue: nextImage, keyName: kCIInputImageKey)
            changeTarget.setInputImageParmState(newState: .inputPhoto)

            let panDirection = PanDirection.random()
            let zoomDirection  = ZoomDirection.random()
                // zoom is either .none or .zoomIn..
                // .zoomOut is commented out
            changeTarget.setPanZoomDefault(panDirection: panDirection ,  zoomDirection: zoomDirection)
        }
        else {
            NSLog("incrementOnAttribute NO next Image assigned for next panZoom")
        }

//            NSLog(#function + String(describing: self) + "changing image " + String(describing: attribute.attributeName ))
        }


    fileprivate func setImageInPanZoom(panZoom: PGLPanZoomFilter,aPickedImage: CIImage) {
        panZoom.setImageValue(newValue: aPickedImage, keyName: kCIInputImageKey)
        panZoom.setInputImageParmState(newState: .inputPhoto)

        let panDirection = PanDirection.random()
        let zoomDirection  = ZoomDirection.random()

        panZoom.setPanZoomDefault(panDirection: panDirection ,  zoomDirection: zoomDirection)
    }
    
    override  func setUserPick(attribute: PGLFilterAttribute, imageList: PGLImageList) {
      // put the first images into the panZoom for initial display

      super.setUserPick(attribute: attribute, imageList: imageList)

      let dissolveImageList = imageList

      let startImage = dissolveImageList.getCurrentImage()

      if startImage != CIImage.empty() {
          setImageInPanZoom(panZoom: panImageFilter, aPickedImage: startImage)
          loadNextImageForPanTarget(dissolveImageList: dissolveImageList)
        }
        else {
            NSLog("setUserPick: startImage not ready, waiting for onImageReady")
            let currentPosition = dissolveImageList.position
            guard currentPosition < dissolveImageList.imageAssets.count else { return }
            let currentAsset = dissolveImageList.imageAssets[currentPosition]
            currentAsset.onImageReady = { [weak self] _ in
                guard let self = self else { return }
                if let scaledImage = currentAsset.imageAtTargetSize() {
                    self.setImageInPanZoom(panZoom: self.panImageFilter, aPickedImage: scaledImage)
                }
                self.loadNextImageForPanTarget(dissolveImageList: dissolveImageList)
            }
        }

    }

    fileprivate func loadNextImageForPanTarget(dissolveImageList: PGLImageList) {
        if let nextImage = dissolveImageList.increment() {
            setImageInPanZoom(panZoom: panTargetFilter, aPickedImage: nextImage)
        } else {
            let nextPosition = dissolveImageList.position
            guard nextPosition < dissolveImageList.imageAssets.count else { return }
            let nextAsset = dissolveImageList.imageAssets[nextPosition]
            nextAsset.onImageReady = { [weak self] _ in
                guard let self = self else { return }
                if let scaledImage = nextAsset.imageAtTargetSize() {
                    self.setImageInPanZoom(panZoom: self.panTargetFilter, aPickedImage: scaledImage)
                }
            }
        }
    }

//    override func setImageValue(newValue: CIImage, keyName: String) {
//        // how to know that photo asset just set the list after read from library
//        // only on the first read  in setUserPick
//        // after that the normal time cycle will update from the filter list
//        // to the panZoomfilters
//        // the panZoomFilters then supply the processed image for the dissolve
//
//        super.setImageValue(newValue: newValue, keyName: keyName)
//
//    }



}
