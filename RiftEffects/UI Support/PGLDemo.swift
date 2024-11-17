//
//  PGLDemo.swift
//  Surreality
//
//  Created by Will on 1/23/21.
//  Copyright © 2021 Will Loew-Blosser. All rights reserved.
//

import Foundation
import Photos
import UIKit
import os

@MainActor
class PGLDemo {
        // create random groups of image/filters
        // pull images from 'Favorites' album
        // supports PGLStackController Random button
        // supports Test classes

    static let NoRandomChildStackPercentage = 70  // integer 0 to 100
                                                  // percentage to control how often a child stack is added in the Random function
                                                  // 100 means child stack is never added
    static var RandomImageList: PGLImageList?
        // interacts with PGLRandomFilter to hold user images for random consturction
    static let MaxListSize = 6
    let NumOfFilters = 5

    static var FavoritesAlbumList: PGLAlbumSource?
    var appStack: PGLAppStack!
    let saveOutputToPhotoLib = false
    static var CurrentDemoGroup = 0
    static var Category1Index = 0


    static let TransistionFilters =  PGLFilterCategory("CICategoryTransition")!.filterDescriptors
    static let StylizeFilters =  PGLFilterCategory("CICategoryStylize")!.filterDescriptors
    static let DistortFilters = PGLFilterCategory("CICategoryDistortionEffect")!.filterDescriptors
    static let GeometryFilters = PGLFilterCategory("CICategoryGeometryAdjustment")!.filterDescriptors
    static let GradientFilters = PGLFilterCategory("CICategoryGradient")!.filterDescriptors
    static let SharpenFilters = PGLFilterCategory("CICategorySharpen")!.filterDescriptors
    static let BlurFilters = PGLFilterCategory("CICategoryBlur")!.filterDescriptors
    static let CompositeFilters = PGLFilterCategory("CICategoryCompositeOperation")!.filterDescriptors
    static let HalfToneFilters = PGLFilterCategory("CICategoryHalftoneEffect")!.filterDescriptors
    static let ColorAdjFilters = PGLFilterCategory("CICategoryColorAdjustment")!.filterDescriptors
    static var ColorEffectFilters = PGLFilterCategory("CICategoryColorEffect")!.filterDescriptors
    static let TileFilters = PGLFilterCategory("CICategoryTileEffect")!.filterDescriptors
    static let GeneratorFilters = PGLFilterCategory("CICategoryGenerator")!.filterDescriptors


    static let SingleFilterGroups = [BlurFilters,ColorAdjFilters, ColorEffectFilters,StylizeFilters, DistortFilters, GeometryFilters,SharpenFilters, HalfToneFilters , TileFilters ]
        // ,GeneratorFilters, GradientFilters TileFilters
    static let GeneratorGroups = [GeneratorFilters, GradientFilters]
    static let CompositeGroups = [CompositeFilters, TransistionFilters]

    var setInputToPrior = false
    var iPhoneCompact = true


        // MARK: Demo
    func fetchFavoritesList(onImageParm: PGLFilterAttribute) ->  PGLAlbumSource? {

        if PGLDemo.FavoritesAlbumList == nil {
            let userFavorites = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumFavorites , options: nil)


            if let theFavoriteAlbum = userFavorites.firstObject {
                let fetchResultAssets = PHAsset.fetchAssets(in: theFavoriteAlbum , options: nil)
                let theInfo =  PGLAlbumSource(targetAttribute: onImageParm, theFavoriteAlbum,fetchResultAssets)
                    //                                          init(_ assetAlbum: PHAssetCollection, _ result: PHFetchResult<PHAsset>? ))
                    // init(_ assetAlbum: PHAssetCollection, _ result: PHFetchResult<PHAsset>? )
                PGLDemo.FavoritesAlbumList = theInfo
            }
        }
        return PGLDemo.FavoritesAlbumList

    }

    func addFiltersTo(stack: PGLFilterStack) {
            // put NumOfFilters random filters on the stack
            // filters from random groups in singleFilterGroups


            //        for aGroup in PGLDemo.SingleFilterGroups {
        for _ in 0..<NumOfFilters {
            let groupIndex = Int.random(in: 0 ..< PGLDemo.SingleFilterGroups.count)
            let aGroup = PGLDemo.SingleFilterGroups[groupIndex]
            let aFilterIndex = Int.random(in: 0 ..< aGroup.count)
            guard let thisFilter = aGroup[aFilterIndex].pglSourceFilter() else {
                continue
            }
            thisFilter.setDefaults()
            Logger(subsystem: LogSubsystem, category: LogCategory).notice("addFiltersTo \(thisFilter.localizedName()) \(String(describing: thisFilter.filterName))")
            stack.appendFilter(thisFilter)
                // will parmState to inputPriorState if there is prior input
            setImageInputs(thisFilter)
            thisFilter.setRandomParms()
        }
    }

    func setDemoImageInputs(imageParm: PGLFilterAttribute) {
            // creates an imageList for the targetAttribute
            //use up to PGLDemo.MaxListSize images if a transition filter
            // otherwise just one image

        if PGLDemo.RandomImageList == nil {
            setRandomImagesFromFavorites(imageParm: imageParm)
        }
        else {
                // use images from the global PGLDemo.RandomImageList
            if imageParm.inputParmType() == ImageParm.missingInput {
                guard let newbieList = PGLDemo.RandomImageList?.clone(toParm: imageParm)
                else {return }
                    // now prune down  the newbie list if needed
                newbieList.randomPrune(imageParm: imageParm)
                imageParm.setImageCollectionInput(cycleStack: newbieList)
            }

        }



    }

    func setRandomImagesFromFavorites(imageParm: PGLFilterAttribute) {
        guard let favoriteAlbumSource = fetchFavoritesList(onImageParm: imageParm) else
        {
            DispatchQueue.main.async {
                    // put back on the main UI loop for the user alert
                let alert = UIAlertController(title: "Favorites Album", message: "Favorites is empty. Add or select images for random filter inputs.", preferredStyle: .alert)

                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
                    Logger(subsystem: LogSubsystem, category: LogCategory).error("PGLDemo #setInputTo Favorites album is empty")
                }))
                let myAppDelegate =  UIApplication.shared.delegate as! AppDelegate
                myAppDelegate.displayUser(alert: alert)
            }
            return
        }
        favoriteAlbumSource.filterParm = imageParm
        let favoriteAssets = favoriteAlbumSource.assets() // converts to PGLAsset
                                                          // mix it up with photos

        var selectedAssets = [PGLAsset]()
        var allowedAssetCount = 1
        if imageParm.isTransitionFilter
        { allowedAssetCount = PGLDemo.MaxListSize }
        let maxIndex = favoriteAssets!.count
        if maxIndex == 0 {
                // may be limited access to photo lib
            return
        }

            // ensure an image is only picked once.
        var pickedIndexes = [Int]()
        let maxLoopCount = allowedAssetCount * 2
            // stop at some point
        var whileLoopCount = 0
        while (selectedAssets.count <= allowedAssetCount) && (whileLoopCount <= maxLoopCount) {
            let randomIndex = Int.random(in: 0 ..< maxIndex)
            if pickedIndexes.contains(randomIndex) {
                    // skip to next  loop for new random
                continue }
            pickedIndexes.append(randomIndex)
            selectedAssets.append(favoriteAssets![randomIndex])
            whileLoopCount += 1
        }

        let userSelectionInfo = PGLUserAssetSelection(assetSources: favoriteAlbumSource)
        for anAsset in selectedAssets {
            Logger(subsystem: LogSubsystem, category: LogCategory).debug("parm = \(String(describing: imageParm.attributeName)) added local id = \(anAsset.localIdentifier)")
            userSelectionInfo.addSourceToSelection(asset: anAsset)
        }

        userSelectionInfo.setUserPick()
    }


    func mightAddChildStack(attribute: PGLFilterAttribute) -> Bool {
            // use childStack infrequently..
            // need a guard to usually return false without change
            // if childStack added then return true
            // random 1 in 10 chance to addChildStack..
        let skipAddChild = Int.random(in: 1...100) < PGLDemo.NoRandomChildStackPercentage
        if skipAddChild { return false }

        Logger(subsystem: LogSubsystem, category: LogCategory).debug("adding ChildStack at \(String(describing: attribute.attributeName))")
        guard let imageAttribute = attribute as? PGLFilterAttributeImage
        else { return false }
        appStack.addChildStackTo(parm: imageAttribute)
        let childStack = appStack.viewerStack // the new childStack

        addFiltersTo(stack: childStack)
        return true
    }

    fileprivate func setImageInputs(_ targetFilter: PGLSourceFilter) {
        let imageAttributesNames = targetFilter.imageInputAttributeKeys

        for anImageAttributeName in imageAttributesNames {
            guard let thisAttribute = targetFilter.attribute(nameKey: anImageAttributeName) else { continue }
            if thisAttribute.inputParmType() == ImageParm.missingInput {

                let newChildAdded = mightAddChildStack(attribute: thisAttribute)
                if !newChildAdded {
                    setDemoImageInputs(imageParm: thisAttribute) // the six images from favorites

                }
            }
        }
    }

        // MARK: Random
    func generateRandomStack( thisAppStack: PGLAppStack    ) {


        templateDemoSetup( currentAppStack: thisAppStack)
        var firstRandomFilter: PGLSourceFilter

        if PGLDemo.CurrentDemoGroup >= PGLDemo.CompositeGroups.count {
                // keeps moving forward each time random button is clicked
                // clears back to zero if app restarts
            PGLDemo.CurrentDemoGroup = 0
        }

        let group1 = PGLDemo.CompositeGroups[PGLDemo.CurrentDemoGroup]
        let targetStack = appStack.viewerStack // appStack.outputFilterStack()
        firstRandomFilter = group1[PGLDemo.Category1Index].pglSourceFilter()!

        if PGLDemo.Category1Index < (group1.count - 1 ){

            addFiltersTo(stack: targetStack)

            targetStack.stackName = "Random Filters"
                //was  firstRandomFilter.filterName + "+ various filters"
            targetStack.stackType = targetStack.stackName
            if saveOutputToPhotoLib {
                targetStack.exportAlbumName = "Random" }
            else { targetStack.exportAlbumName = nil }

                // set the stack with the title, type, exportAlbum for save
            Logger(subsystem: LogSubsystem, category: LogCategory).notice("PGLDemo multipleInputTransitionFilters \(targetStack.stackName)")
                //                targetStack.saveStackImage()
                // confirm that output is saved and the coreData has saved

            PGLDemo.Category1Index += 1

            PGLDemo.CurrentDemoGroup += 1
                // increment
        } else {
            PGLDemo.Category1Index = 0 // reset
        }
        templateDemoCompletion(startingDemoFilter: firstRandomFilter)
    }

       

        // MARK: Setup

    func templateDemoSetup( currentAppStack: PGLAppStack) {
        appStack = currentAppStack
        if appStack.showFilterImage {
                // turn off the single filter view
            appStack.toggleShowFilterImage() }
        setInputToPrior = appStack.viewerStack.stackHasFilter()
    }

    func templateDemoCompletion( startingDemoFilter: PGLSourceFilter ) {

        appStack.viewerStack.activeFilterIndex = 0
        if setInputToPrior {
            startingDemoFilter.setInputImageParmState(newState: ImageParm.inputPriorFilter)
        }

        let updateFilterNotification = Notification(name:PGLCurrentFilterChange)
        NotificationCenter.default.post(name: updateFilterNotification.name, object: nil, userInfo: ["sender" : self as AnyObject])
            // triggers PGLImageController to set view.isHidden to false
            // show the new results !

        let goToStack = Notification(name: PGLLoadedDataStack)
        NotificationCenter.default.post(goToStack)


    }



    fileprivate func addDemoFilterWithImages(_ filter0: PGLSourceFilter?, _ targetStack: PGLFilterStack, _ appStack: PGLAppStack ) {

        if filter0 == nil {
            return
        }
        targetStack.appendFilter(filter0!)
        
        guard let imageKeys = filter0?.imageInputAttributeKeys else { return }

        for anImageParm in imageKeys {
            let thisImageAttribute = filter0?.attribute(nameKey: anImageParm)
            appStack.targetAttribute = thisImageAttribute
            if thisImageAttribute?.inputParmType() == ImageParm.missingInput {
                setDemoImageInputs(imageParm: thisImageAttribute!)
            }
        }


    }

    func createSequenceFilter() -> PGLSequencedFilters {
        let theDescriptor = PGLFilterDescriptor(kPSequencedFilter, PGLSequencedFilters.self)

        guard let seqFilter = theDescriptor?.pglSourceFilter() as? PGLSequencedFilters
        else {   fatalError("Did not create SequencedFilters" ) }
        return seqFilter
    }

        //MARK: Templates

    func blendTemplate(appStack: PGLAppStack) {
            // set better parm values

        let filterNames = ["CIDissolveTransition","CIBumpDistortion", "CIBlendWithMask", "CIRadialGradient", "CIDissolveTransition" ]
        templateDemoSetup( currentAppStack: appStack)

        let targetStack = appStack.viewerStack
        if let imageFilter = targetStack.demoCreateFilter(ciFilterString: filterNames[0]) {
            imageFilter.setDefaults()

            let bumpFilter = targetStack.demoCreateFilter(ciFilterString: filterNames[1])
            let blendMaskFilter = targetStack.demoCreateFilter(ciFilterString: filterNames[2])
            let gradientFilter = targetStack.demoCreateFilter(ciFilterString: filterNames[3])
            let dissolveFilter = targetStack.demoCreateFilter(ciFilterString: filterNames[4])

            addDemoFilterWithImages(blendMaskFilter,  targetStack, appStack)

            // create child stack of images and bump
            // add to background image
            guard let backgroundImageAttribute = blendMaskFilter?.attribute(nameKey: kCIInputBackgroundImageKey)
            else { return }
        appStack.addChildStackTo(parm: backgroundImageAttribute)
        let childStack = appStack.viewerStack // the new childStack


        addDemoFilterWithImages(imageFilter,  childStack, appStack)


        addDemoFilterWithImages(bumpFilter, childStack, appStack)

            // add radial gradient as mask

        guard let maskImageTarget = blendMaskFilter?.attribute(nameKey: kCIInputMaskImageKey) as? PGLFilterAttributeImage
        else { return  }
        appStack.addChildStackTo(parm: maskImageTarget)
        let maskChildStack = appStack.viewerStack // the new childStac
        addDemoFilterWithImages(gradientFilter, maskChildStack, appStack)

        if let blendInputImage = blendMaskFilter?.attribute(nameKey: kCIInputImageKey) as? PGLFilterAttributeImage {
            appStack.addChildStackTo(parm: blendInputImage)
            let blendChildStack = appStack.viewerStack
            // set source images for the dissolve
            setDemoImageInputs(imageParm: (dissolveFilter?.attribute(nameKey: kCIInputImageKey))!)
            addDemoFilterWithImages(dissolveFilter,  blendChildStack, appStack)
        }

            // set up blend demo parms
            // values from LogParmValues = true and review of the log on iPad
            //            CIBumpDistortion setVectorValue(newValue:keyName:)( [1110 848] , inputCenter )
            //            CIBumpDistortion setNumberValue(newValue:keyName:)( 473.0233 , inputRadius )
            //            CIBumpDistortion setNumberValue(newValue:keyName:)( 0.9302326 , inputScale )
            //            CIRadialGradient setVectorValue(newValue:keyName:)( [1149 892] , inputCenter )
            //            CIRadialGradient setNumberValue(newValue:keyName:)( 483.7209 , inputRadius0 )
            //            CIRadialGradient setNumberValue(newValue:keyName:)( 223.2558 , inputRadius1 )
            // values for iPhone 14 Pro
            //            CIBumpDistortion setVectorValue(newValue:keyName:)( [780 570] , inputCenter )
            //            CIRadialGradient setVectorValue(newValue:keyName:)( [995 667] , inputCenter )
            let  bumpInputCenter = if iPhoneCompact {CIVector(x: 780, y: 570)} else {CIVector(x: 995, y: 667)}
            let   radialInputCenter =  if iPhoneCompact {CIVector(x: 995, y: 667)} else {CIVector(x: 1149, y: 892)}

            bumpFilter?.setVectorValue(newValue: bumpInputCenter, keyName: "inputCenter")
            bumpFilter?.setNumberValue(newValue: 473.0233, keyName: "inputRadius")
            bumpFilter?.setNumberValue(newValue: 0.9302326, keyName: "inputScale")
            gradientFilter?.setVectorValue(newValue: radialInputCenter, keyName: "inputCenter")
            gradientFilter?.setNumberValue(newValue: 483.7209, keyName: "inputRadius0")
            gradientFilter?.setNumberValue(newValue: 223.2558, keyName: "inputRadius1")

        for aMultipleInputFilter in ([imageFilter, dissolveFilter]) {
            aMultipleInputFilter?.setTimerDt(lengthSeconds: 3.0)
            _ = aMultipleInputFilter?.notifyTransitionsExist()
        }

        templateDemoCompletion( startingDemoFilter: imageFilter)
    }
}

    func edgeTemplate(appStack: PGLAppStack ) {
        // this template needs to start with empty stack
        // remove any filters in the stack
        appStack.viewerStack.removeAllFilters()

        let filterNames = [ "CIEdges", "CIEdgeWork", "CIGaborGradients", "CICannyEdgeDetector"  ]

        templateDemoSetup( currentAppStack: appStack)


        let targetStack = appStack.viewerStack
        let edgeSequence = createSequenceFilter()
        edgeSequence.addChildSequenceStack(appStack: appStack)
        addDemoFilterWithImages(edgeSequence,  targetStack, appStack)

        
        for filterName in filterNames {
            if let anEdgeFilter = targetStack.demoCreateFilter(ciFilterString: filterName)
            {
                edgeSequence.filterSequence()?.appendFilter(anEdgeFilter)
            }

        }
        templateDemoCompletion( startingDemoFilter: edgeSequence)
//        targetStack.postTransitionFilterAdd() // makes the redraws run
//        targetStack.postCurrentFilterChange() // makes DoNotDraw =

    }

    func toneTemplate(appStack: PGLAppStack ) {
        let filterNames = ["CIDissolveTransition","CIToneCurve" ]
        templateDemoSetup( currentAppStack: appStack)
        let targetStack = appStack.viewerStack
        if let imageFilter = targetStack.demoCreateFilter(ciFilterString: filterNames[0]) {
            imageFilter.setDefaults()
            addDemoFilterWithImages(imageFilter,  targetStack, appStack)
            let toneFilter = targetStack.demoCreateFilter(ciFilterString: filterNames[1])


            addDemoFilterWithImages(toneFilter, targetStack, appStack)
            imageFilter.setTimerDt(lengthSeconds: 3.0)
            _ = imageFilter.notifyTransitionsExist()

                // iPhone tone curve points - to observe set LogParmValues = true
                //            CIToneCurve setVectorValue(newValue:keyName:)( [0.489 0.179] , inputPoint1 )
                //            CIToneCurve setVectorValue(newValue:keyName:)( [0.46 0.488] , inputPoint2 )
                //            CIToneCurve setVectorValue(newValue:keyName:)( [1.023 0.512] , inputPoint3 )
            toneFilter?.setVectorValue(newValue: CIVector(x: 0.489, y: 0.179), keyName: "inputPoint1")
            toneFilter?.setVectorValue(newValue: CIVector(x: 0.46, y: 0.488), keyName: "inputPoint2")
            toneFilter?.setVectorValue(newValue: CIVector(x: 1.023, y: 0.512), keyName: "inputPoint3")
            templateDemoCompletion( startingDemoFilter: imageFilter)

        }
    }

    func kaleidoscopeTemplate(appStack: PGLAppStack )  {
        let filterNames = ["CIDissolveTransition", "CIColorBurnBlendMode","CIGaussianBlur", "CIKaleidoscope" ]
        templateDemoSetup( currentAppStack: appStack)
        let targetStack = appStack.viewerStack
        if let imageFilter = targetStack.demoCreateFilter(ciFilterString: filterNames[0]) {
            imageFilter.setDefaults()
            addDemoFilterWithImages(imageFilter,  targetStack, appStack)
            let colorBurnFilter = targetStack.demoCreateFilter(ciFilterString: filterNames[1])


            addDemoFilterWithImages(colorBurnFilter, targetStack, appStack)
            imageFilter.setTimerDt(lengthSeconds: 3.0)
            _ = imageFilter.notifyTransitionsExist()

            let kaleidoscopeFilter = targetStack.demoCreateFilter(ciFilterString: filterNames[3])

            
            addDemoFilterWithImages(kaleidoscopeFilter, targetStack, appStack)

            // add child stack to color burn with the gaussian blur and another kaleidoscope

            guard let colorBurnBackgroundAttribute = colorBurnFilter?.attribute(nameKey: kCIInputBackgroundImageKey) else { return  }
            appStack.addChildStackTo(parm: colorBurnBackgroundAttribute )
            let childStack = appStack.viewerStack

            let kaleidoscopeFilter2 = childStack.demoCreateFilter(ciFilterString: filterNames[3])
            addDemoFilterWithImages(kaleidoscopeFilter2,  childStack, appStack)


            let gaussianBlurFilter = childStack.demoCreateFilter(ciFilterString: filterNames[2])
            addDemoFilterWithImages(gaussianBlurFilter,  childStack, appStack)

            let kaleidoscope1Center1 = if iPhoneCompact {CIVector(x: 627 , y: 517)} else {CIVector(x: 882, y: 782)}
            let kaleidoscope1Center2 = if iPhoneCompact {CIVector(x: 595, y: 432)} else {CIVector(x: 932, y: 623)}

            kaleidoscopeFilter?.setVectorValue(newValue: kaleidoscope1Center1, keyName: kCIInputCenterKey)
            kaleidoscopeFilter2?.setVectorValue(newValue: kaleidoscope1Center1, keyName: kCIInputCenterKey)

            kaleidoscopeFilter?.setNumberValue(newValue: 5, keyName: "inputCount")
            kaleidoscopeFilter2?.setNumberValue(newValue: 11, keyName: "inputCount")

            kaleidoscopeFilter?.setNumberValue(newValue: 0.1461, keyName: "inputAngle")
            kaleidoscopeFilter2?.setNumberValue(newValue: 0.8036, keyName: "inputAngle")

            templateDemoCompletion( startingDemoFilter: imageFilter)
        }

    }

}
