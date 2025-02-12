//
//  PGLDetector.swift
//  RiftEffects
//
//  Created by Will on 2/12/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//

import UIKit
import os

@MainActor
class PGLDetector: PGLDetection {
    // uses older CIDetectors.. see also the new PGLVisionDetector and the Vision framework

    // REDO below comment for new design
    // subclass of PGLSourceFilter to dispatch to a detector
    // +++++++++++++++
    // PGLDetectorFilter and FaceFilter are connected in PGLFilterDescriptor class var pglFilterClassDict
    //  with the key value pair of  "FaceFilter": PGLDetectorFilter.self
    //  PGLFaceFilter: CIFilter and has the registered name of "FaceFilter"
    // this design captures the image features when the input is set and holds the detector
    // both are expensive operations
    
    var viewCIContext: CIContext?
    var  detector: CIDetector?
    var  features = [PGLFaceBounds]() {
        didSet {  displayFeatures = features.indices }
        }
    var  displayFeatures: CountableRange<Int>?
    var localFilter: CIFilter?  // filter to produce outputs on the detected features  rename?
    var inputImage: CIImage?
    var oldInputImage: CIImage?
    var filterAttribute: PGLFilterAttribute?
    var targetInputAttribute: PGLFilterAttributeImage?
    var targetInputTargetAttribute: PGLFilterAttributeImage?

    // animation
    var inputTime = 0.0 // ranges -1.0 to +1.0 for animation
        // Double

    var currentFeatureIndex = 0
    // detector and features vars also used in CIFilterAbstract for the Bump and Face CI filter subclasses

    enum Direction: Int {
        case forward = 1
        case back = -1
    }
    // init
    required init(ciFilter: CIFilter?) {
        localFilter = ciFilter
        // requires setCIContext to function but needs to be sent later
    }

    func setCIContext(detectorContext: CIContext?) {
        // superclass has empty implementation

        if detectorContext != nil {
            detector = CIDetector.init(ofType: CIDetectorTypeFace, context: detectorContext!, options: [CIDetectorAccuracy:CIDetectorAccuracyHigh, CIDetectorTracking:true])
            viewCIContext = detectorContext!
        }
    }

    func releaseContext() {
        // release everything 
        detector = nil
        features = [PGLFaceBounds]()
        localFilter = nil
        inputImage = nil
        oldInputImage = nil

        viewCIContext?.clearCaches()
        viewCIContext = nil
    }

    func releaseTargetAttributes() {
        targetInputTargetAttribute = nil
        targetInputAttribute = nil
    }

    // MARK: animation


    func setInputTime(time: Double) {
        inputTime = time
    }

    func increment() {
          // 12/2/19 should have a dissolve on incremnent for smooth change to next feature
          // moves upward to features.count. then returns to start at zero
        nextFeature(to: Direction.forward)

      }
    
    func nextFeature(to: Direction) {
        // 12/2/19 should have a dissolve on incremnent for smooth change to next feature
        // moves upward to features.count. then returns to start at zero
        Logger(subsystem: LogSubsystem, category: LogCategory).debug("PGLDetector nextFeature start currentFeatureIndex = \(self.currentFeatureIndex) features.count = \(self.features.count)")
        currentFeatureIndex += to.rawValue
        if (currentFeatureIndex >= features.count) || (currentFeatureIndex < 0) {
            currentFeatureIndex = 0
        }
        Logger(subsystem: LogSubsystem, category: LogCategory).debug("PGLDetector nextFeature end currentFeatureIndex = \(self.currentFeatureIndex) features.count = \(self.features.count)")
//        setFeaturePoint()
    }

    // set features
    @MainActor func setFeaturePoint(){
        // put the center of the first feature into the point value of the attribute
        Logger(subsystem: LogSubsystem, category: LogCategory).debug("PGLDetector setFeaturePoint currentFeatureIndex = \(self.currentFeatureIndex) features.count = \(self.features.count)")
        if features.isEmpty {return }
        if currentFeatureIndex >= features.count {return}
        let mainFeature = features[currentFeatureIndex]
        let mainBox = mainFeature.boundingBox() ?? CGRect.zero
        let centerX = mainBox.midX
        let centerY = mainBox.midY
        let pointVector = CIVector(x:centerX, y: centerY)
        filterAttribute?.set( pointVector)
        Logger(subsystem: LogSubsystem, category: LogCategory).debug("PGLDetector setFeaturePoint = \(pointVector)")

    }

     func setInput(image: CIImage?, source: String?) {
//               NSLog("PGLDetector setInput")
        // called every imageUpdate by the PGLFilterStack->filter.setInput->detectors#setInput
            var resetNewFaces = false
            if let anInputImage = image {
                inputImage = anInputImage
                if oldInputImage === inputImage {
//                    NSLog("PGLDetector no action same image setInput")
                    return } // don't process twice


//                localFilter?.setDefaults()
//                localFilter?.setValue(inputImage, forKey: kCIInputImageKey)
                oldInputImage = inputImage
                
                let newCIFeatures = detector?.features(in: anInputImage) ?? [CIFaceFeature]()
                var newFaceBoxes = [PGLFaceBounds]()
                for aCIFeature in newCIFeatures {
                    newFaceBoxes.append(PGLFaceBounds(onVNFace: nil, onCIFace: aCIFeature as? CIFaceFeature))
                }
                features = [PGLFaceBounds]() // reset
                for aFeature in newFaceBoxes {

                     features.append(aFeature)
                        if aFeature.hasTrackingFrameCount() {
                            if aFeature.trackingFrameCount() <= 1 {
                                resetNewFaces = true
                            }
                        }

                }

        }
        if resetNewFaces { currentFeatureIndex = 0 }

    }

    func setOutputAttributes(wrapperFilter: PGLDissolveWrapperFilter) {
        // may not need to be type PGLDissolveWrapperFilter
        // as it just outputs  from input & target attributes
        targetInputAttribute = wrapperFilter.imageInputAttribute()
        targetInputTargetAttribute = wrapperFilter.imageTargetImageAttribute()


    }



    func featureImagePair() ->(inputFeature: CIImage, targetFeature: CIImage) {
        // PGLDetector
        // used for the first setup of the dissolve wrapper
        // answers the internal filter output with two images for a dissolve
        // the dissolve uses inputImage and targetImage
        // current two features are used to set the input attrbute point
        // uses currentFeatureIndex. should increment on increment intervals
        let restoreIndex = currentFeatureIndex
        setFeaturePoint()
        let inputDissolveImage = localFilter?.outputImage
        nextFeature(to: Direction.forward) // moves featureIndex forward or back to zero for looping
        setFeaturePoint()
        let targetDissolveImage = localFilter?.outputImage
        currentFeatureIndex = restoreIndex
        return (inputDissolveImage ?? CIImage.empty(),targetDissolveImage ?? CIImage.empty())
    }

    func nextImage() -> CIImage {
        increment()
        setFeaturePoint()
        return localFilter?.outputImage ?? CIImage.empty()
    }

    func isEven() -> Bool {
        // answers true if the currentFeatureIndex is zero or an even number

        return currentFeatureIndex.isEven()

    }

    // MARK: Output
    func outputFeatureImages() -> [CIImage] {
        // answer a collection of images starting without features and then each feature highlighted.
        var answerImages = [CIImage]()
        guard inputImage != nil  // features are not highlighted
            else { return answerImages }

//        answerImages.append(startImage) // put the unaltered image first}

        if let myFaceFilter = localFilter as? PGLFilterCIAbstract {
            guard let myDisplayFeatures = self.displayFeatures
                else { return answerImages }
            myFaceFilter.features = features
            myFaceFilter.displayFeatures = myDisplayFeatures
            myFaceFilter.inputImage = inputImage
                // updateValue(value, forKey: kCIInputImageKey)
            for i in myDisplayFeatures {
                myFaceFilter.inputFeatureSelect = i
                if let thisFeatureImage = myFaceFilter.outputImage {
                    answerImages.append(thisFeatureImage)
                }
            }
        } else {
            // not a PGLFilterCIAbstract..which has features set by the detector
             // here set the the attribute to the feature point and output an image
            let restoreIndex = currentFeatureIndex
            for i in 0..<features.count {
                currentFeatureIndex = i
                setFeaturePoint()
                answerImages.append((localFilter?.outputImage)!)
            }
            currentFeatureIndex = restoreIndex

            
        }

        return answerImages
    }


}
