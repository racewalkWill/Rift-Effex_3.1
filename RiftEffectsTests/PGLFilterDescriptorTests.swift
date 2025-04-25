//
//  PGLFilterDescriptorTests.swift
//  PictureGlance
//
//  Created by Will on 3/27/17.
//  Copyright © 2017 Will. All rights reserved.
//

// import XCTest
import Testing
import os
import UIKit

@testable import RiftEffects

@MainActor
@Suite(.serialized) struct  PGLFilterDescriptorTests {
     let standardFilterName = "CIDiscBlur"
    let standardClass = PGLSourceFilter.self
    var appStack: PGLAppStack!

    init() async throws {
        let myAppDelegate =  UIApplication.shared.delegate as! AppDelegate
        appStack = myAppDelegate.appStack

        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    // deinit
//    override func tearDown() {
//        // Put teardown code here. This method is called after the invocation of each test method in the class.
//        self.appStack.releaseTopStack()
//
//        super.tearDown()
//    }

    @Test func categoryDescription() {
        let classCategories = [kCICategoryDistortionEffect,
                               kCICategoryGeometryAdjustment]
        for aCategory in classCategories {
            let allFilters = CIFilter.filterNames(inCategory: aCategory)
//            Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("all filters by category \(aCategory) = \(allFilters)")
            #expect (allFilters.count > 0)

        }


    }
    @Test func descriptionFilterDescriptor() {
        // check that the print description is working
        let newDescriptor = PGLFilterDescriptor(standardFilterName, standardClass)
        #expect (newDescriptor?.filterName == standardFilterName )  // should be a localized description

        #expect (newDescriptor?.displayName != standardFilterName)



    }

    @Test func filterCategory() {
        if let aCategory = PGLFilterCategory("CICategoryDistortionEffect") {
            #expect (aCategory.filterDescriptors.count > 2) }

    }

    @Test func allFilterCategories() {
        let allCategories = PGLFilterCategory.allFilterCategories()

       let categoryGeometryAdjustment = allCategories[2]
//        Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice( "categoryGeometryAdjustment = \(categoryGeometryAdjustment)")

        #expect (categoryGeometryAdjustment.filterDescriptors.count > 5 )
    }

/// list all filters for test runs
    @Test func allFilterCreation() throws {
        let allCategories = PGLFilterCategory.allFilterCategories()
        for aCategory in allCategories {
            let categoryFilterNames = CIFilter.filterNames(inCategory: aCategory.categoryConstant)

            for aFilterName in categoryFilterNames {
                var mappedClasses = [PGLSourceFilter.self]
                let specialMap = CIFilterToPGLFilter.Map[aFilterName]
                    // nil is answered for most
                if specialMap != nil {
                    mappedClasses = specialMap!
                }
                    for aMapClass in mappedClasses {


                        let  thisFilterDescriptor = PGLFilterDescriptor(aFilterName, aMapClass)
                       try  #require (thisFilterDescriptor != nil )


                        #expect (thisFilterDescriptor?.filter != nil , "CIFilter did not create filter \(aFilterName) from category \(aCategory.categoryConstant)")

                        let pglFilter = thisFilterDescriptor!.pglSourceFilter()
                        #expect (pglFilter != nil, "CIFilter did not create pglSourceFilter \(aFilterName) from category \(aCategory.categoryConstant)")

                        Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("Filter -\(aCategory.categoryConstant) -\(aFilterName) -\(aMapClass) -\(pglFilter!.localizedName()) ")
                    }
                }
            }

    }

    /// generate to the log the filter category, filtername, localized name and description
    @Test func filterNameDescriptionCapture() throws {

        let allCategories = PGLFilterCategory.allFilterCategories()
        for aCategory in allCategories {
            let categoryFilterNames = CIFilter.filterNames(inCategory: aCategory.categoryConstant)

            for aFilterName in categoryFilterNames {
                var mappedClasses = [PGLSourceFilter.self]
                let specialMap = CIFilterToPGLFilter.Map[aFilterName]
                    // nil is answered for most
                if specialMap != nil {
                    mappedClasses = specialMap!
                }
                    for aMapClass in mappedClasses {

                        let thisFilterDescriptor =  PGLFilterDescriptor(aFilterName, aMapClass)
                        try #require(thisFilterDescriptor != nil )

                        #expect (thisFilterDescriptor?.filter != nil , "CIFilter did not create filter \(aFilterName) from category \(aCategory.categoryConstant)")
                        let pglFilter = thisFilterDescriptor?.pglSourceFilter()
                        #expect (pglFilter != nil , "CIFilter did not create pglSourceFilter \(aFilterName) from category \(aCategory.categoryConstant)")

                        let filterDescription = CIFilter.localizedDescription(forFilterName: aFilterName)!
                        Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("Filter:\(aCategory.categoryConstant):\(aFilterName):\(pglFilter!.localizedName()):\(filterDescription)")
                    }
                }
            }

    }

    @Test func filterDescriptionCapture() {
        // capture to the log all of the filter info for analysis
        var filterAttributes = [String:Any]()

        let allCategories = PGLFilterCategory.allFilterCategories()
        for aCategory in allCategories {
            let categoryFilterNames = CIFilter.filterNames(inCategory: aCategory.categoryConstant)

            for aFilterName in categoryFilterNames {
                filterAttributes = [String:Any]()
                Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("testing filter \(aFilterName) category \(aCategory.categoryConstant)")
                let thisFilterDescriptor = PGLFilterDescriptor(aFilterName, standardClass)
                // these filters should already be cached in the categories but checking direct creation here
                if let myFilter = thisFilterDescriptor?.pglSourceFilter() {
                    Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("\(aFilterName)")
                    Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("\(CIFilter.localizedDescription(forFilterName: aFilterName)!)" )

                    filterAttributes = (myFilter.localFilter.attributes)
                    Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("\(filterAttributes.description)")
                }
//                        Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("all filters by category \(aCategory) = \(allFilters)")


            }

        }
    }

    @Test func unknownFilterAttributesList() {
        // capture to the log filter attributes that are not implemented for UI

        var nonUIParmCount = 0
        let allCategories = PGLFilterCategory.allFilterCategories()
        for aCategory in allCategories {
            let categoryFilterNames = CIFilter.filterNames(inCategory: aCategory.categoryConstant)

            for aFilterName in categoryFilterNames {
                if (PGLExcludeFilters.list.contains(aFilterName))
                    && (PGLExcludeFilters.skipFailingFilters)
                    {continue}
                let thisFilterDescriptor = PGLFilterDescriptor(aFilterName, standardClass)
                // these filters should already be cached in the categories but checking direct creation here
                if let myFilter = thisFilterDescriptor?.pglSourceFilter() {
                    let  filterAttributes = (myFilter.attributes)
                    for anAttribute in filterAttributes {
                        if anAttribute.attributeUIType() == AttrUIType.filterPickUI {
                            // pointUI, sliderUI, imagePickUI, rectUI are not filterPickUI.. interfaces exist
                            nonUIParmCount += 1
//                            Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("testing filter \(aFilterName) category \(aCategory.categoryConstant)")
                            Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("filter \(aFilterName) category \(aCategory.categoryConstant) NOT UI Parm \(anAttribute.description)")
                        }
                    }
                }
            }
        }
        Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("Count of nonUI Parms = \(nonUIParmCount)")
    }

    @Test func filterAttributeCounter() {
        // capture to the log counts of filter classes, types
        var filterAttributes = [String:Any]()
        var filters = [String:CIFilter]()
        var attributeCounts = [0:0] // key is number of inputAttributes, value is number of occurences in all the filters
        var attributeTypeCounts = [String:Int]() // key is type name, value is number of occurences in all the filters
        var attributeClassCounts = [String:Int]() // key is class name , value is number of occurences in all the filters
        var countedFilter: CIFilter?
        var oldCount = 0
        var filtersUsingVectors = [String]()


        let allCategories = PGLFilterCategory.allFilterCategories()
        for aCategory in allCategories {
            let categoryFilterNames = CIFilter.filterNames(inCategory: aCategory.categoryConstant)
            Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("filters in category \(aCategory.categoryName) = \(categoryFilterNames.count)")
            for aFilterName in categoryFilterNames {
                filterAttributes = [String:Any]()  // reset to empty attributes
                if let thisFilter = CIFilter(name: aFilterName) {
                    countedFilter = filters.updateValue(thisFilter, forKey: aFilterName)
                    if countedFilter == nil {
                        // old value was nil, this is a new filter.. process with counts for thisFilter

                    filterAttributes = (thisFilter.attributes)
                    let inputKeysCount = thisFilter.inputKeys.count
                        if inputKeysCount > 5 {
                            Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice(" large parm count for \(aFilterName) count = \(inputKeysCount)")
                        }
                    oldCount = attributeCounts[inputKeysCount] ?? 0 // needs to count only the input parms
                    attributeCounts[inputKeysCount] = oldCount + 1

                        for thisAttribute in filterAttributes {
                            if let thisAttributeDict = thisAttribute.value as? [String:Any] {
                            let attributeClass = thisAttributeDict[kCIAttributeClass] as! String
                            oldCount = attributeClassCounts[attributeClass] ?? 0
                            attributeClassCounts[attributeClass] = oldCount + 1
                                if attributeClass == "CIVector" {
                                    filtersUsingVectors.append(aFilterName)
                                }
                            if let attibuteType = thisAttributeDict[kCIAttributeType] as? String {
                                    oldCount = attributeTypeCounts[attibuteType] ?? 0
                                    attributeTypeCounts[attibuteType] = oldCount + 1
                                }

                            }
                        }
                    }


                }
//        Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("all filters by category \(aCategory) = \(allFilters)")


            }

        }
        Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("testFilterAttibuteCounter filter count = \(filters.count)")
        Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("testFilterAttibuteCounter PARMS (parmsSize: filterCount) \(attributeCounts)")
        Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("testFilterAttibuteCounter CLASS (class: count) \(attributeClassCounts)")
        Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("testFilterAttibuteCounter TYPE (type: count) \(attributeTypeCounts)")
        Logger(subsystem: TestLogSubsystem, category: TestLogCategory).notice("filters with Vectors \(filtersUsingVectors)")

    }

    @Test func  descriptorSort() {
        // test duplicate filters in the
        // PGLFilterCategory.filterDescriptors var
        // descriptors are built by category and some filters are in multiple categories
        // but the var should only have unique filters by filterName

        var answerFilters = [PGLFilterDescriptor]()
        for aCategory in PGLFilterCategory.allFilterCategories() {
            answerFilters.append(contentsOf: aCategory.filterDescriptors)
        }
        let categoryCount = answerFilters.count

        let filterDescriptors = PGLFilterCategory.filterDescriptors
        let filterCount = filterDescriptors.count
        #expect (filterCount <= categoryCount, "filterCount = \(filterCount)")

    }


}
