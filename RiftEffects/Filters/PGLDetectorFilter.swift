//
//  PGLDetectorFilter.swift
//  RiftEffects
//
//  Created by Will on 5/2/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//

import UIKit

class PGLDetectorFilter: PGLSourceFilter {
    // move down the detector[] array here?
    required init?(filter: String, position: PGLFilterCategoryIndex) {
      super.init(filter: filter, position: position)
     hasAnimation = true
//        detectors.append( DetectorFramework.Active.init(ciFilter: PGLFaceCIFilter()))

    }

    override func setCIContext(detectorContext: CIContext?) {
        for thisDetector in detectors {
            // pass on the context for the  detectorFilter.detector
            thisDetector.setCIContext(detectorContext: detectorContext)
        }
    }

}
