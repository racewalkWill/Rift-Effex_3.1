//
//  CDAttributeAffine+CoreDataProperties.swift
//  RiftEffects
//
//  Created by Will on 4/4/26.
//

import Foundation
import CoreData


extension CDAttributeAffine {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDAttributeAffine> {
        return NSFetchRequest<CDAttributeAffine>(entityName: "CDAttributeAffine")
    }

    @NSManaged public var vectorAngle: Float
    @NSManaged public var vectorLength: Float
    @NSManaged public var vectorX: Float
    @NSManaged public var vectorY: Float
    @NSManaged public var vectorZ: Float

}
