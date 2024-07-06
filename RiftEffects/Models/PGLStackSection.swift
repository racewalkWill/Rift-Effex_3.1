//
//  PGLStackSections.swift
//  RiftEffects
//
//  Created by Will on 7/1/24.
//  Copyright © 2024 Will Loew-Blosser. All rights reserved.
//

import Foundation
@MainActor


class PGLStackSection {

    var filterIndents = [PGLFilterIndent]()

    init( _ filters: [PGLFilterIndent]) {
        if filters.isEmpty {
            fatalError("PGLStackSection has no filters")
        }
        self.filterIndents = filters.sorted(by: { $0.filterPosition <  $1.filterPosition })
    }

     func append(_ filter: PGLFilterIndent) {
        filterIndents.append(filter)

    }
    func stack() -> PGLFilterStack {
        return  filterIndents[0].stack
    }

    func stackHeaderIndentLevel() -> Int {
        if filterIndents.isEmpty {
            return 0
        } else {
            return filterIndents[0].level
        }
    }

    func sectionRowCount() -> Int {
        // section has filterIndents for each filter
        // stack header is NOT included
        return filterIndents.count
    }



}
