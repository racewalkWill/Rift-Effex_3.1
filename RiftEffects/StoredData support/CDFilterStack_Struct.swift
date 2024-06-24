//
//  CDFilterStack_Struct.swift
//  RiftEffects
//
//  Created by Will on 6/24/24.
//  Copyright © 2024 Will Loew-Blosser. All rights reserved.
//

import Foundation
import CoreData

extension CDFilterStack {
//   @nonobjc public class func fetchRequest() -> NSFetchRequest<CDFilterStack> {
//       return NSFetchRequest<CDFilterStack>(entityName: "CDFilterStack")
//    }

    func asFilterStackStruct() -> FilterStack {
        return FilterStack(
            created: created,
            exportAlbumIdentifier: exportAlbumIdentifier,
            exportAlbumName: exportAlbumName,
            modified: modified,
            thumbnail: thumbnail,
            title: title,
            type: type,
            objectID: objectID
            )
    }


}

struct FilterStack: Hashable {
    let created: Date?
    let exportAlbumIdentifier: String?
    let exportAlbumName: String?
    let modified: Date?
    let thumbnail: Data?
    let title: String?
    let type: String?
    let objectID: NSManagedObjectID
}
