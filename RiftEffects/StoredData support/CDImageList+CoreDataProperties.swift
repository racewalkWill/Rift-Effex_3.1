//
//  CDImageList+CoreDataProperties.swift
//  
//
//  Created by Will on 8/30/25.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


public typealias CDImageListCoreDataPropertiesSet = NSSet

extension CDImageList {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDImageList> {
        return NSFetchRequest<CDImageList>(entityName: "CDImageList")
    }

    @NSManaged public var albumIds: [String]?
    @NSManaged public var assetIDs: [String]?
    @NSManaged public var attributeName: String?
    @NSManaged public var machineName: String?
    @NSManaged public var parm: CDParmImage?

}

extension CDImageList : Identifiable {

}
