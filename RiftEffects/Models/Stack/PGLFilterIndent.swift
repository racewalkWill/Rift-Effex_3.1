//
//  PGLFilterIndent.swift
//  RiftEffects
//
//  Created by Will on 5/11/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//

import UIKit
import os

@MainActor
class PGLFilterIndent: Hashable, Equatable , @preconcurrency CustomDebugStringConvertible {

        //MARK: Hashable, Equatable
    nonisolated static func == (lhs: PGLFilterIndent, rhs: PGLFilterIndent) -> Bool {
        return lhs === rhs
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

        // supports PGLStackController creation of cells in the tableView
        // indent a filter under it's parent

    var level: Int
    var filter: PGLSourceFilter
    var stack: PGLFilterStack
    var filterPosition: Int

        //MARK: init
    init(_ indent: Int, _ onFilter: PGLSourceFilter, inStack: PGLFilterStack, index: Int) {
        level = indent
        filter = onFilter
        stack = inStack
        filterPosition = index
    }

    var descriptorDisplayName: String {

        if let thisName = filter.descriptorDisplayName  {
            return thisName
        }
        else {
            return filter.localizedName()
        }

    }
    public var debugDescription: String {
        if let thisName = filter.descriptorDisplayName  {
            return thisName
        }
        else {
            return filter.localizedName()
        }
    }

    func setCellViewerStackBackground(aCell: UITableViewCell, viewerStack: PGLFilterStack) {

        if stack === viewerStack {
            aCell.backgroundColor = UIColor.systemGroupedBackground
                // .withAlphaComponent(0.2)
        }
        else {
            // .clear rather than nil: on iPhone this cell may sit inside
            // PGLTwoColumnSplitController's glass drawer, whose table view is
            // itself transparent — nil would fall back to the cell's default
            // opaque background and hide the glass behind it.
            aCell.backgroundColor = .clear
        }
    }

    func isAverageLuminanceNearZero() -> Bool {
        return filter.isAverageLuminanceNearZero
    }
}
