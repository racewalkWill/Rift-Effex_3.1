//
//  PGLFilterStackTests.swift
//  PictureGlance
//
//  Created by Will on 3/24/17.
//  Copyright © 2017 Will. All rights reserved.
//

// import XCTest
import Testing
import UIKit
import Photos
import os
import CoreData


@testable import RiftEffects


@MainActor
@Suite(.serialized) struct PGLFilterStackTests {

    var filterStack: PGLFilterStack!  
    var testAppStack = PGLAppStack() // creates an empty filterStack
    var testCIImage: CIImage!
    var activeFilterCount = 0
    var cleanUpDeleteList = [NSManagedObjectID]()
    lazy var dataProvider: PGLStackProvider = {
       let appDelegate = UIApplication.shared.delegate as? AppDelegate
       let provider = PGLStackProvider(with: appDelegate!.dataWrapper.persistentContainer)
        provider.setFetchControllerForBackgroundContext()
       return provider
   }()

       static func imageListTestObject() -> PGLImageList {
            let assetIDs = [PhotoId.burst1.rawValue, PhotoId.burst2.rawValue , PhotoId.timeLapse1.rawValue, PhotoId.timeLapse2.rawValue, PhotoId.timeLapse3.rawValue, PhotoId.timeLapse4.rawValue]
            // create a Cycle stack
            let albumIDs = [PhotoId.burstAlbum.rawValue, PhotoId.burstAlbum.rawValue,PhotoId.burstAlbum.rawValue,PhotoId.timeLapseAlbum.rawValue,PhotoId.timeLapseAlbum.rawValue,PhotoId.timeLapseAlbum.rawValue,]
    // matching assetId and albumId arrays
            return PGLImageList(localAssetIDs: assetIDs, albumIds: albumIDs)
        }


   //  override func setUp() {
    init()  async throws {

       filterStack = testAppStack.viewerStack
        // filterStack gets one default filter
        // add two more
       
        guard let favoriteImageList = fetchFavoritesList() else
            { Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice (" setUp fatalError( favoritesAlbum contents not returned")
             return
        }

        if let bumpFilter = PGLSourceFilter(filter: "CIBumpDistortion") {
            bumpFilter.setDefaults()
           guard let firstImageParm = bumpFilter.imageParms()?.first
            else { fatalError("Need an image parm to test ")}
            firstImageParm.inputCollection = favoriteImageList
            firstImageParm.parmInputState = ParmInputState.inputPhoto
            filterStack.appendFilter(bumpFilter) }

        // 2018-12-14  most of the tile filters seem to error.. skip CIPerspectiveTile for now..
        // CIKaleidoscope does work in tile category..
        if let tileFilter = PGLSourceFilter(filter: "CIKaleidoscope") {
            tileFilter.setDefaults()
            filterStack.appendFilter(tileFilter)
        }
        activeFilterCount = filterStack.activeFilters.count
  

        filterStack.stackType = "testCase PGLFilterStackTests"

    }

//    override  func tearDown() {
//        let myAppDelegate =  UIApplication.shared.delegate as! AppDelegate
//        myAppDelegate.saveContext()
//        self.appStack.releaseTopStack()
//        let newStack = PGLFilterStack()
//        newStack.setStartupDefault() // not sent in the init.. need a starting point
//        testAppStack.resetToTopStack(newStackId: newStack)
//        super.tearDown()
//    }

    func fetchFavoritesList() -> PGLImageList? {
            // prune to 6 images
        let maxFavoriteSize = 6
        var favIDs = [String]()
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


    mutating func testStackSetup() {
        // shows that the suite setup has an output image
        // and save the output image
        let moContext = dataProvider.persistentContainer.viewContext
        filterStack.stackName = "testStackSetup" + " \(Date())"
        _ = filterStack.writeCDStack(moContext: moContext)
        #expect (filterStack.storedStack != nil)


    }
//    func testThreeFilterStack() {
//        XCTAssert(filterStack.activeFilters.count == 2)
//        let output = filterStack.outputImage()
//        XCTAssertTrue( (output!.extent.width > 0) && (output!.extent.height > 0), "output extent is zero width/height")
//
//        XCTAssertNotNil(output)
//    }

   

    @Test mutating func addDeleteFilters() {
        // show removing a filter from a stored stack
        // show adding a filter to a stored stack.
        let defaultTitle = "testAddDeleteFilters" +  " \(Date())"
        filterStack.stackName = defaultTitle
        Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("PGLFilterStackTests #testWriteStack() stackName = \(defaultTitle)")
        let moContext = dataProvider.persistentContainer.viewContext

        let writtenStack = filterStack.writeCDStack(moContext: moContext)
        Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("PGLFilterStackTests #testAddDeleteFilters wroteCDStack \(writtenStack)")


        _ = filterStack.removeLastFilter()
        #expect (filterStack.activeFilters.count == activeFilterCount - 1)


        let savedStack = filterStack.writeCDStack(moContext: moContext) // should update with delete
        let newStack2 = PGLFilterStack()
        newStack2.on(cdStack: savedStack)
        #expect (filterStack.activeFilters.count == newStack2.activeFilters.count)
        #expect (filterStack.activeFilters.count == activeFilterCount - 1)

        // the managed object is the same on all three stacks
        #expect (filterStack.storedStack === newStack2.storedStack)


        for aFilter in filterStack.activeFilters {
            Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("filterStack filter = \(String(describing: aFilter.filterName))")
        }

        for aFilter in newStack2.activeFilters {
            Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("newStack2 filter = \(String(describing: aFilter.filterName))")
        }

        

    }

    @Test mutating func cycleSave() {
        //confirm that the multiple inputs to a filter are saved
        let stackName = "testCycleSave" +  " \(Date())"
        let moContext = dataProvider.persistentContainer.viewContext
        filterStack.stackName = stackName
        // need a filter then assign the test PGLImageList to it..
        // the save of the filter should create the CDImageList
        let aImageList = PGLFilterStackTests.imageListTestObject()
        // setImageCollectionInput(cycleStack: PGLImageList, firstAssetData: PHAsset)
        let currentFilterName = filterStack.currentFilter().filterName
        let currentFilterIndex = filterStack.activeFilterIndex
        if let anImageParm = filterStack.currentFilter().imageParms()?.first {
           anImageParm.setImageCollectionInput(cycleStack: aImageList)
           
        }

        let savedStack = filterStack.writeCDStack(moContext: moContext)
            // stack, filters, imageList should all be stored

        let aNewStack = PGLFilterStack()
        aNewStack.on(cdStack: savedStack)
        aNewStack.activeFilterIndex = currentFilterIndex // put back to saved position

        #expect ( aNewStack.currentFilter().filterName == currentFilterName)
        let storedImageParm = aNewStack.currentFilter().imageParms()?.first
        let storedImageList = storedImageParm!.inputCollection!
        let storedIDs =  (storedImageList.assetIDs).sorted()
        let listIDs = (aImageList.assetIDs).sorted()
        #expect ( storedIDs == listIDs )
        // fails due to different order of the elements


        // confirm that the stored data CDFi
    }

    @Test func inputFilterSave() {
        // one of the parms uses a filter stack as input..
        // save and read back
        let stackName = "testInputFilterSave" + " \(Date())"
         filterStack.stackName = stackName
        // need a filter then assign the test PGLImageList to it..
        // the save of the filter should create the CDImageList

        if let dissolveFilter = (PGLFilterDescriptor("CIDissolveTransition", PGLTransitionFilter.self))?.pglSourceFilter()
             {
            filterStack.replaceFilter(at: 0, newFilter: dissolveFilter)
        }
        if let blendFilter = PGLSourceFilter(filter: "CIBlendWithMask") {
            blendFilter.setDefaults()
            filterStack.moveActiveBack()
            if let aParm = filterStack.currentFilter().imageParms()?.first {
                Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("PGLFilterStackTests #testInputFilterSave to  \(self.filterStack.stackName)")
                Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("PGLFilterStackTests #testInputFilterSave to \(String(describing: self.filterStack.currentFilter().filterName))")
                Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("PGLFilterStackTests #testInputFilterSave to \(String(describing: aParm.attributeName))")

                testAppStack.addChildStackTo(parm: aParm)
                let newMasterStack = testAppStack.viewerStack

                newMasterStack.replace(updatedFilter: blendFilter)

                #expect (newMasterStack.currentFilter().filterName == "CIBlendWithMask")
                #expect ((testAppStack.hasParentStack()))
                #expect (testAppStack.viewerStack === newMasterStack)
                #expect (testAppStack.outputOrViewFilterStack() === filterStack)



                testAppStack.showFilterImage = true // change output to the current stack
                #expect (testAppStack.outputOrViewFilterStack() === newMasterStack)
                testAppStack.showFilterImage = false // change back

                let outputAttributes = testAppStack.outputOrViewFilterStack().currentFilter().attributes
                let inputStackAttribute = outputAttributes.filter( {$0.inputStack != nil} ).first
                let inputFilterPosition = testAppStack.outputOrViewFilterStack().activeFilterIndex
                let testInputStack = inputStackAttribute!.inputStack

                #expect (testInputStack != nil )
//                Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("Filter with child inputStack = \(testAppStack.outputFilterStack().currentFilter())")
                Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("Filter position = \(inputFilterPosition)")
                Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("attribute \(String(describing: inputStackAttribute)) has inputStack \(String(describing: testInputStack))")

                _ = testAppStack.outputOrViewFilterStack().stackName
                 testAppStack.writeCDStacks()

                let newStack = PGLFilterStack()
                let newStackStored = testAppStack.viewerStackOrPushedFirstStack()!.storedStack!
                newStack.on(cdStack: newStackStored)

                newStack.activeFilterIndex = inputFilterPosition
                let topAttributes = newStack.currentFilter().attributes
                let newInputStackAttribute = (topAttributes.filter( {$0.inputStack != nil} )).first
                #expect (newInputStackAttribute != nil )
                #expect (newInputStackAttribute?.attributeName == inputStackAttribute?.attributeName)
                #expect (newInputStackAttribute?.inputStack != nil )
                #expect (testInputStack!.stackName == newInputStackAttribute?.inputStack?.stackName)

            }
        }
    }



}
