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

    required init?(filter: String, position: PGLFilterCategoryIndex) {
        super.init(filter: filter, position: position)
        // super sets up three sides..
        // now add one more
        sideCount = 4
        blendFilters.append(CIFilter(name: kGradientBlendFilter)! )

            // for the attributes in the ciFilter parm
        let thisGradientIndex = sideCount - 1 // zero based offset

        if let  childLinearFilter = PGLGradientChildFilter(filter: "CILinearGradient", position: PGLFilterCategoryIndex()) {
            childLinearFilter.parentFilter = self
            childLinearFilter.sideKey = thisGradientIndex

            linearGradients.append(childLinearFilter)
            let vectorAttributes = childLinearFilter.attributes.filter( {$0.isVector() })

            for aVector in vectorAttributes {
                /// set to form linear1.inputPoint0 etc..
                ///  decoded back in  PGLGradienChildFilter setVectorValue...
                aVector.attributeName = kGradientAttributePrefix + String(thisGradientIndex) + String(kPGradientKeyDelimitor) + aVector.attributeName!
                aVector.attributeDisplayName = "Side " + String(thisGradientIndex + 1 ) + " " + aVector.attributeDisplayName!
                }
            attributes.append(contentsOf: vectorAttributes )
            childLinearFilter.setDefaults()
        }
    }

    override class func localizedDescription(filterName: String) -> String {
        // custom subclasses should override
       return "4 sided Gradient for Blend with Mask. Generates the mask shape"
    }

    override class func displayName() -> String? {

        // FilterDescriptor will use the ciFilter.localizedName if this is nil.
        // where a ciFilter is used with different pglSourceFilter classes then this method should be implemented
        // by the subclass
        return k4SidedGradient
    }

    override func outputImageBasic() -> CIImage? {
        //notice that .outputImage() is used for the linearGradients image return
        // BUT .outputImage is used for the blendFilter image return..
        // it's a bug in the filter code !!

        let linear0Image = linearGradients[0].outputImage()
        let linear1Image = linearGradients[1].outputImage()
        let linear2Image = linearGradients[2].outputImage()
        let linear3Image = linearGradients[3].outputImage()

        blendFilters[0].setValue(linear0Image, forKey: kCIInputImageKey)
        blendFilters[0].setValue(linear1Image, forKey: kCIInputBackgroundImageKey)

        let blend0Image = blendFilters[0].outputImage

        blendFilters[1].setValue(blend0Image, forKey: kCIInputImageKey)
        blendFilters[1].setValue(linear2Image, forKey: kCIInputBackgroundImageKey)

        let blend1Image = blendFilters[1].outputImage

        blendFilters[2].setValue(blend1Image, forKey: kCIInputImageKey)
        blendFilters[2].setValue(linear3Image, forKey: kCIInputBackgroundImageKey)

        return blendFilters[2].outputImage

    }
}
