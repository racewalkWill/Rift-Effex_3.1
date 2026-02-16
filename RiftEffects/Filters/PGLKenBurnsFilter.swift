//
//  PGLKenBurnsFilter.swift
//  RiftEffects
//
//  Created by Will on 2/15/26.
//  Copyright © 2026 Will Loew-Blosser. All rights reserved.
//

import Foundation
import CoreImage
import simd
import UIKit
import os

/// Ken Burns style disssolve with slow pan, zoom on each image
class PGLKenBurnsFilter: PGLTransitionFilter {
    // use two MaximiumScaleTransformFilters input to Dissolve
    // inputImageList feeds each altenatively
    // alternate between with preset vary on pan, zoom
    // only increment imageList when offscreen

    override class func displayName() -> String? {
        return kKenBurnsDissolve
    }

//    var dissolveFilter: PGLTransitionFilter
        // dissolve is the output filter
    var panImageFilter: PGLScaleUpFrame
    var panBackgroundFilter: PGLScaleUpFrame

    required init?(filter: String, position: PGLFilterCategoryIndex) {
//        let dissolveDescriptor = PGLFilterDescriptor("CIDissolveTransition" , PGLTransitionFilter.self)!
            // "CIDissolveTransition" : [  PGLTransitionFilter.self  ],
        // add to the CIFilterToPGLFilter.Map

        let panImageDescriptor = PGLFilterDescriptor("CIMaximumScaleTransform", PGLScaleUpFrame.self)!

        let panBackgroundDescriptor = PGLFilterDescriptor("CIMaximumScaleTransform", PGLScaleUpFrame.self)!
            // on UI select of a linear attribute then 2 subcells of 2 values

//        dissolveFilter = dissolveDescriptor.pglSourceFilter() as! PGLTransitionFilter
        panImageFilter = panImageDescriptor.pglSourceFilter() as! PGLScaleUpFrame
        panBackgroundFilter =  panBackgroundDescriptor.pglSourceFilter() as! PGLScaleUpFrame

        super.init(filter: filter, position: position)
    }

    override class func localizedDescription(filterName: String) -> String {
        // custom subclasses should override
       return "Ken Burns Style dissolve"
    }

    override func addFilterStepTime() {
        super.addFilterStepTime()

    }

    func incrementImageLists() {
        // send increment to the image parm lists
        for anImageParm in imageParms() ?? [PGLFilterAttributeImage]() {
            _ = anImageParm.inputCollection?.increment()
        }
    }
    override  func outputImageBasic() -> CIImage? {
        return CIImage.empty()

    }


}
