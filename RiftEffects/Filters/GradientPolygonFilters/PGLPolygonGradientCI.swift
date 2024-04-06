//
//  PGLPolygonGradientCI.swift
//  RiftEffects
//
//  Created by Will on 3/22/24.
//  Copyright © 2024 Will Loew-Blosser. All rights reserved.
//

import Foundation
import CoreGraphics
import UIKit
import os

/// May delete as the PGLClass for the gradient handles all the below
// MARK: DELETE

/// 5 sided simple polygon gradient
/// uses 5 linear gradients to form the closed chain of endpoints
/// may intersect itself to form star like shape
/// each linear gradient has two points to define a blend area along the line
class PGLPolygonGradientCI: CIFilter {



 override init() {

        super.init()
    }

    required init?(coder aDecoder: NSCoder)
    {

        super.init(coder: aDecoder)

    }


    class func register() {
        //       let attr: [String: AnyObject] = [:]
//        NSLog("PGLSequencedFilters #register()")
        CIFilter.registerName(kTriangleGradient, constructor: PGLFilterConstructor(), classAttributes: PGLPolygonGradientCI.customAttributes())
    }

    class override var supportsSecureCoding: Bool { get {
        // subclasses must  implement this
        // Core Data requires secureCoding to store the filter
        return true
    }}


    @objc class func customAttributes() -> [String: Any] {
        let customDict:[String: Any] = [
            kCIAttributeFilterDisplayName : kTriangleGradient,

            kCIAttributeFilterCategories :
                [kCICategoryGradient, kCICategoryStillImage],


        ]
        return customDict
    }


}
