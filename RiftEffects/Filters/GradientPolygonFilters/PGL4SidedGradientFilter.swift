//
//  PGL4SidedGradientFilter.swift
//  RiftEffects
//
//  Created by Will on 4/6/24.
//  Copyright © 2024 Will Loew-Blosser. All rights reserved.
//

import Foundation

import CoreImage
import simd
import UIKit
import os

class PGL4SidedGradientFilter: PGLTriangleGradientFilter {

    override class var polygonSideCount: Int { return 4 }

    override class func localizedDescription(filterName: String) -> String {
        // custom subclasses should override
       return NSLocalizedString("4 sided Gradient for Blend with Mask. Generates the mask shape", comment: "4 Sided Gradient custom filter description")
    }

    override class func displayName() -> String? {

        // FilterDescriptor will use the ciFilter.localizedName if this is nil.
        // where a ciFilter is used with different pglSourceFilter classes then this method should be implemented
        // by the subclass
        return NSLocalizedString("4 Sided Gradient", comment: "4 Sided Gradient filter display name")
    }
}
