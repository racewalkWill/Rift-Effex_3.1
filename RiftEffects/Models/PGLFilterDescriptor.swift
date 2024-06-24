//
//  PGLFilterDescriptor.swift
//  PictureGlance
//
//  Created by Will on 3/18/17.
//  Copyright © 2017 Will. All rights reserved.
//

import Foundation
import CoreImage

//@MainActor  just some func are marked @MainActor
struct PGLFilterDescriptor: Equatable, Hashable {

    
//    func encode(with aCoder: NSCoder) {
////        fatalError("PGLFilterDescriptor does not implement encode")
//    }
//    
//    required init?(coder aDecoder: NSCoder) {
////        fatalError("PGLFilterDescriptor does not implement coder")
//    }
    
    
    let  kFilterSettingsKey = "FilterSettings"
    let  kFilterOrderKey = "FilterOrder"

    let filterName: String
    var displayName: String?
    var inputImageCount = -1
    let userDescription: String
    var uiPosition = PGLFilterCategoryIndex()

    var debugDescription: String {
        return filterName
    }


    //MARK: hasher/equatable
     static func == (lhs: PGLFilterDescriptor, rhs: PGLFilterDescriptor) -> Bool {
        return (lhs.filterName == rhs.filterName) && (lhs.pglSourceFilterClass === rhs.pglSourceFilterClass)
    }

     func hash(into hasher: inout Hasher)  {
        let myClassNameString =  String(describing: (type(of: pglSourceFilterClass).self))

        hasher.combine(filterName)
        hasher.combine(myClassNameString)
    }

    var pglSourceFilterClass = PGLSourceFilter.self  //some will use a subclass ie PGLCropFilter etc..

    //MARK: init
    // connect the ciFilter name to a PGLSourceFilter class
    // the ciFilter will get installed into the PGLSourceFilter instances
    // this fails if a ciFilter is used by several PGLSourceFilters because dictionary has unique keys
    // it is a many to many relationship from CIFilter instances to (PGLSourceFilter & PGLSourceFilter subclasses)
    // see implementation in CIFilter class func pglClassMap()
    // constructed in PGLFilterCategory, PGLFilterDescriptors, CIFilter

    @MainActor init?(_ ciFilterName: String, _ pglClassType: PGLSourceFilter.Type? ) {
         // if pglClassType passed as nil then defaults to PGLSourceFilter.self
         
        filterName = ciFilterName  // keep the code name around

        if let aPGLClass = pglClassType {
            pglSourceFilterClass = aPGLClass
            if let pglSourceDisplayName =  pglSourceFilterClass.displayName() {
              displayName =  pglSourceDisplayName
            }
        }
         if displayName == nil {
             displayName = CIFilter.localizedName(forFilterName: ciFilterName) ?? ciFilterName
                     // will be localized to Dissolve or other...
         }
        userDescription = pglSourceFilterClass.localizedDescription(filterName: ciFilterName)
            // just the filter name if no description is found
            // else the default value is PGLSourceFilter.self


    }

    func filter() -> CIFilter {
        // see also PGLFilterConstructor filter(withName: String

        return PGLFilterConstructor().filter(withName: filterName)!
            // triggers nil unwrap error if filter is not returned
    }

    @MainActor func pglSourceFilter() -> PGLSourceFilter? {
        // create and return a new instance of my real filter
        // or nil if the real filter can not be created

        let newSourceFilter = pglSourceFilterClass.init(filter: filterName, position: uiPosition)
        newSourceFilter?.setDefaults()
        newSourceFilter?.descriptorDisplayName = displayName
        return newSourceFilter


    }

    @MainActor func copy() -> PGLFilterDescriptor {
        let newbie = PGLFilterDescriptor(filterName, pglSourceFilterClass)!

        return newbie
    }


}




