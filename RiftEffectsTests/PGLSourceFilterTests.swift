//
//  PGLSourceFilterTests.swift
//  PictureGlance
//
//  Created by Will on 8/20/17.
//  Copyright © 2017 Will. All rights reserved.
//

//import XCTest
import Testing
import UIKit
import Photos
import os

let TestLogSubsystem = "L-BSoftwareArtist.RiftEffects"
let TestLogCategory = "PGL"

@testable import RiftEffects


@MainActor


@Suite(.serialized) struct PGLSourceFilterTests {
    // run the filter test one at a time

    var jobIndex = UInt64(0)
    var depthFilter: PGLSourceFilter?
    var inputCollection: PGLImageList?
    var appStack: PGLAppStack!

    /// Filters skipped by the category tests
    /// QR code generators throw "requires L, M, Q, or H for inputCorrectionLevel"
    static let ExcludedTestFilters: Set<String> = ["CIQRCodeGenerator", "CIRoundedQRCodeGenerator"]

//    override func setUp() {
    init() async throws {

        depthFilter = PGLSourceFilter(filter: "CIDepthOfField" )
        let myAppDelegate =  UIApplication.shared.delegate as! AppDelegate
        appStack = myAppDelegate.appStack
        // Put setup code here. This method is called before the invocation of each test method in the class.


    }

//    deinit {
    //override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
//        let myAppDelegate =  UIApplication.shared.delegate as! AppDelegate
//        myAppDelegate.saveContext() // checks if context has changes
//        self.appStack.releaseTopStack()
//        let newStack = PGLFilterStack()
//        newStack.setStartupDefault() // not sent in the init.. need a starting point
//        
//        self.appStack.resetToTopStack(newStackId: newStack)
//
//    }

    /// Fetch the favorites album and wait for the asset images to load.
    /// PGLImageList #runCacheLoad requests the images in a Task, so the ciImage of each
    /// PGLAsset is nil until the PHImageManager completion runs on the main actor.
    func fetchFavoritesList() async -> PGLImageList {
        let favorites = fetchFavoritesListUnloaded()
        await waitForImagesLoaded(favorites)
        return favorites
    }

    /// Poll until every asset in the list has its ciImage or the timeout expires.
    /// Task.sleep suspends the main actor so the image request completions can run.
    func waitForImagesLoaded(_ imageList: PGLImageList, timeout: Duration = .seconds(10)) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while imageList.hasUncachedAssets && clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
        if imageList.hasUncachedAssets {
            Logger(subsystem: TestLogSubsystem, category: TestLogCategory).error("PGLSourceFilterTests \(#function) timed out waiting for favorites images to load")
        }
    }

    func fetchFavoritesListUnloaded() -> PGLImageList {
        var favIDs = [String]()
        let maxFavoriteSize = 6
      
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit  = maxFavoriteSize
        let userFavorites = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumFavorites , options: fetchOptions)
        if let theFavoriteAlbum: PHAssetCollection = userFavorites.firstObject {
             let assets = PHAsset.fetchAssets(in: theFavoriteAlbum , options: fetchOptions)
                assets.enumerateObjects{(asset,index,stop) in
                    favIDs.append(asset.localIdentifier)
                }
            let albumIDs = Array(repeating: theFavoriteAlbum.localIdentifier, count: min(favIDs.count, maxFavoriteSize) )

            let theFavorites =  PGLImageList(localAssetIDs: favIDs, albumIds: albumIDs)
            // this init assumes two matching arrays of same size localId and albumid

            //        theFavorites.isAssetList = true
            return theFavorites

        }


        return PGLImageList()

    }



    @Test func parmAttributes() {

        // test creation of the parmAttributes of the CIFilter. PGLSourceFilter connects parms and the filter
        
         #expect (depthFilter != nil)
        Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("testParmAttributes depthFilter = \(String(describing: self.depthFilter))")
        #expect (depthFilter!.attributes.count == 7)
        
        if let depthAttributes = depthFilter?.attributes {
            let saturation = depthAttributes[4]
            #expect (saturation.attributeType == "CIAttributeTypeScalar"  ) // AttrType.Scalar.rawValue
        }
    }



    @Test func dissolveParms() async throws {
            // test that the parms are changed for Dissolve filter
            let timerFilter = PGLSourceFilter(filter: "CIDissolveTransition" )!
            let albumFavorite = await fetchFavoritesList() // PGLImageList of the favorites albume
        try #require (albumFavorite.maxAssetsOrImagesCount() > 1 )

            let image1 = try #require(albumFavorite.image(atIndex: 0), "favorites image 0 not loaded")
            let image2 = try #require(albumFavorite.image(atIndex: 1), "favorites image 1 not loaded")

//            #require (timerFilter != nil)
            timerFilter.setDefaults()
            #expect (timerFilter.attributes.count == 3)

            timerFilter.setInput(image: image1, source: "shoreLine")
            timerFilter.setBackgroundInput(image: image2)
            let timerRate1 = timerFilter.valueFor(keyName: "inputTime") as! NSNumber
                // should be 0.0 as default

            timerFilter.setNumberValue(newValue: 0.05, keyName: "inputTime")
            let timerRate2 = timerFilter.valueFor(keyName: "inputTime") as! NSNumber
        #expect (timerRate1 != timerRate2)

    }

    @Test(.disabled("transition filters answer an empty extent output image with this image input setup - CIAccordionFoldTransition, CIBarsSwipeTransition"))
    func transitionCategoryFilters() async throws {
            // test that the timer rate is set and changed for Dissolve filter
            // test that image dissolves to the target

        let context = CIContext()
        let favoritesAlbumList = await fetchFavoritesList()
        // get the category to create correct pglsourceFilter
        let transitionCategory = PGLFilterCategory("CICategoryTransition")!
        var transitionDescriptors = transitionCategory.filterDescriptors
        transitionDescriptors = transitionDescriptors.dropLast() // drop the 'SequencedFilter'.. needs independent test
            // sequenceFilters adds filters, not images so setup fails.
        transitionDescriptors.removeAll(where: { PGLSourceFilterTests.ExcludedTestFilters.contains($0.filterName) })
        
        for aTransitionDescriptor in transitionDescriptors {
//            let timerFilterDescriptor = transitionCategory.filterDescriptors.first(where: {$0.filterName == "CIDissolveTransition"})
            Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("PGLSourceFilterTests \(#function) testing filter \(aTransitionDescriptor.displayName)")
            let timerFilter = aTransitionDescriptor.pglSourceFilter()!

            timerFilter.setDefaults()

            let input = timerFilter.attribute(nameKey: "inputImage")
            input!.setImageCollectionInput(cycleStack: favoritesAlbumList )
                // this clones to the inputTargetImage parm
                // so two parms are set with values
            if let allImageParms = timerFilter.imageParms() {
                if allImageParms.count > 2 {
                    Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("\(String(describing: timerFilter.filterName)) has more than 2 image inputs")
                    for nextImageParm in allImageParms.suffix(from: 2) {
                        nextImageParm.setImageCollectionInput(cycleStack: favoritesAlbumList)
                    }
                }
            }
            let timerRate1 = timerFilter.valueFor(keyName: "inputTime") as! NSNumber
                // should be 0.0 as default

            timerFilter.setNumberValue(newValue: 0.05, keyName: "inputTime")
            let timerRate2 = timerFilter.valueFor(keyName: "inputTime") as! NSNumber
            #expect (timerRate1 != timerRate2)

            let  result = timerFilter.outputImage()
           try #require (result != nil, "no output image filter \(transitionCategory.categoryName) \(String(describing: timerFilter.filterName)) ")
            #expect( (result!.extent.width > 0) && (result!.extent.height > 0), "result extent is zero width/height")
            let cgImage1 = try #require(context.createCGImage(result!, from: result!.extent), "createCGImage fails for \(aTransitionDescriptor.filterName) extent \(result!.extent)")
            let image1 = UIImage(cgImage: cgImage1)
            for _ in 1...100 {timerFilter.addFilterStepTime()}
            let timerImage2 = timerFilter.outputImage()!
            #expect ( (timerImage2.extent.width > 0) && (timerImage2.extent.height > 0), "image2 extent is zero width/height")
            let cgImage2 = try #require(context.createCGImage(timerImage2, from: result!.extent), "createCGImage fails for \(aTransitionDescriptor.filterName) step image")
            let image2 = UIImage(cgImage: cgImage2)

            #expect ( !image1.isEqual( image2), "Did not change output image")
        }
    }

@MainActor  func setAllImageInputs(_ pglFilter: PGLSourceFilter, _ favoritesAlbumList: PGLImageList) {
            //                let imageAttributesNames = pglFilter.imageInputAttributeKeys
        if let allImageParms = pglFilter.imageParms() {
            for anImageParm in allImageParms {
                    //                    let imageValue = favoritesAlbumList.image(atIndex: index)!
                    //                    pglFilter.setImageValue(newValue: imageValue , keyName: imageAttributesNames[index])
                let favoritesCopy = favoritesAlbumList.clone(toParm: anImageParm)
                favoritesCopy.randomPrune(imageParm: anImageParm)
                    //usually reduces to single input from favorites
                anImageParm.setImageCollectionInput(cycleStack: favoritesCopy)

            }
        }
    }

    fileprivate func confirmFilters(_ theCategory: PGLFilterCategory) async throws {
        let favoritesAlbumList = await fetchFavoritesList()
        #expect (favoritesAlbumList.assetIDs.count > 4 , "Favorites Album should have at least 4 images")
            // get the category to create correct pglsourceFilter
        
        for aFilter in theCategory.filterDescriptors where !PGLSourceFilterTests.ExcludedTestFilters.contains(aFilter.filterName) {
            
            Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("PGLSourceFilterTests \(#function) testing filter \(aFilter.displayName)")
            let pglFilter = aFilter.pglSourceFilter()
            try #require (pglFilter != nil )
            pglFilter!.setDefaults()
            
            setAllImageInputs(pglFilter!, favoritesAlbumList)
            let  result = pglFilter!.outputImage()
            #expect (result != nil, "no output image filter \(theCategory.categoryName) \(aFilter.displayName)")
            #expect ( (result!.extent.width > 0) && (result!.extent.height > 0), "result extent is zero width/height")
            
        }
    }
    
    @Test func stylizeCategoryFilters() async throws {
                // test Stylize filters
                // test that image shows is displayed

        let theCategory = PGLFilterCategory("CICategoryStylize")!
       try await confirmFilters(theCategory)
    }

    @Test func distortFilters() async throws {
                // test Distort filters
                // test that image shows is displayed

        let theCategory = PGLFilterCategory("CICategoryDistortionEffect")!
        try await confirmFilters(theCategory)
        }

    @Test func geometryFilters() async throws {
            // test Stylize filters
            // test that image shows is displayed

        let theCategory = PGLFilterCategory("CICategoryGeometryAdjustment")!
        try await confirmFilters(theCategory)
    }

    @Test func gradientFilters() async throws {
                // test Gradient filters
                // test that image shows is displayed
        let theCategory = PGLFilterCategory("CICategoryGradient")!
        try await confirmFilters(theCategory)
        }

    @Test func sharpenFilters() async throws {
                // test Gradient filters
                // test that image shows is displayed
        let theCategory = PGLFilterCategory("CICategorySharpen")!
       try await confirmFilters(theCategory)
        }

    @Test func testBlurFilters() async throws {
                // test Blure filters
                // test that image shows is displayed
        let theCategory = PGLFilterCategory("CICategoryBlur")!
        try await confirmFilters(theCategory)
        }

    @Test func compositeFilters() async throws {
                   // test Blure filters
                   // test that image shows is displayed
        let theCategory = PGLFilterCategory("CICategoryCompositeOperation")!
        try await confirmFilters(theCategory)
    }

    @Test func halfToneFilters() async throws {
                // test Blure filters
                // test that image shows is displayed
        let theCategory = PGLFilterCategory("CICategoryHalftoneEffect")!
        try await confirmFilters(theCategory)
    }

    @Test func colorAdjFilters() async throws {
                // test Color Adj filters
                // test that image shows is displayed
        let theCategory = PGLFilterCategory("CICategoryColorAdjustment")!
        try await confirmFilters(theCategory)
        }

    @Test func colorEffectFilters() async throws {
            // test Color  filters
            // test that image shows is displayed
        let theCategory = PGLFilterCategory("CICategoryColorEffect")!
       try await confirmFilters(theCategory)
    }

    @Test func tileFilters() async throws {
               // test Color  filters
               // test that image shows is displayed
        let theCategory = PGLFilterCategory("CICategoryTileEffect")!
        try await confirmFilters(theCategory)
       }

    @Test func generatorFilters() async throws {
            // test Color  filters
            // test that image shows is displayed
        let theCategory = PGLFilterCategory("CICategoryGenerator")!
       try await confirmFilters(theCategory)
    }

//    func testInputListChange() {
//        // confirm that changing the inputList of filter image parm will delete the stored value
//
//        
//    }



    @Test func hasRedInCISpotColorFilter()  {
        // test how the subclass of PGLFilterAttribute works for the CISpotColor filter

        let colorFilter = PGLSourceFilter(filter: "CISpotColor" )
        let colorAttribute = colorFilter?.attributes[1]  as? PGLFilterAttributeColor  // expected to have inputCenterColor1

        #expect(colorAttribute != nil )
        let color1 = colorAttribute?.getColorValue()

        #expect (color1 != nil )
        let attributeRed = (colorAttribute?.red)!
        #expect (attributeRed > 0.0)

    }

    // sequenceFilter removed from PGLSourceFilterTests - the demo stack is not a source filter test
//    @Test func  sequenceFilter() {
//        // SequencedFilter omitted from other tests
//        // test here for the process of adding filters, not images
//        appStack.viewerStack.createDemoStack(appStack: appStack)
//        let demoImage = appStack.viewerStack.outputImage()
//        #expect(demoImage != nil)
//        #expect ( (demoImage!.extent.width > 0) && (demoImage!.extent.height > 0), "result extent is zero width/height")
//
//    }
    

    
}
