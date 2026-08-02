//
//  MenuLabel.swift
//  RiftEffects
//
//  Created by Will on 11/12/24.
//  Copyright © 2024 Will Loew-Blosser. All rights reserved.
//

import Foundation

enum PGLMenuLabel: String {
    case random = "Random"
    case Blend = "Blend Demo"
    case Sequence = "Sequence Demo"
    case Edge = "Edge Demo"
    case Tone = "Tone Demo"
    case Kaleidoscope = "Kaleidoscope Demo"
    case Help = "Help..."
    case Privacy = "Privacy Policy"
    case Library = "Library..."
    case Save = "Save..."
    case Record = "Record"
    case Guide = "Guide"
    case Music = "Music"
    case Optimize = "Optimize"
    case Copy = "Copy"
    case Paste = "Paste"
    case Delete = "Delete"
    case Undo = "Undo"
    case Redo = "Redo"

    /// user-visible localized menu title; rawValue stays as the stable identifier
    var localizedTitle: String {
        switch self {
            case .random: return NSLocalizedString("Random", comment: "Menu title")
            case .Blend: return NSLocalizedString("Blend Demo", comment: "Menu title")
            case .Sequence: return NSLocalizedString("Sequence Demo", comment: "Menu title")
            case .Edge: return NSLocalizedString("Edge Demo", comment: "Menu title")
            case .Tone: return NSLocalizedString("Tone Demo", comment: "Menu title")
            case .Kaleidoscope: return NSLocalizedString("Kaleidoscope Demo", comment: "Menu title")
            case .Help: return NSLocalizedString("Help...", comment: "Menu title")
            case .Privacy: return NSLocalizedString("Privacy Policy", comment: "Menu title")
            case .Library: return NSLocalizedString("Library...", comment: "Menu title")
            case .Save: return NSLocalizedString("Save...", comment: "Menu title")
            case .Record: return NSLocalizedString("Record", comment: "Menu title")
            case .Guide: return NSLocalizedString("Guide", comment: "Menu title")
            case .Music: return NSLocalizedString("Music", comment: "Menu title")
            case .Optimize: return NSLocalizedString("Optimize", comment: "Menu title")
            case .Copy: return NSLocalizedString("Copy", comment: "Menu title")
            case .Paste: return NSLocalizedString("Paste", comment: "Menu title")
            case .Delete: return NSLocalizedString("Delete", comment: "Menu title")
            case .Undo: return NSLocalizedString("Undo", comment: "Menu title")
            case .Redo: return NSLocalizedString("Redo", comment: "Menu title")
        }
    }

}
