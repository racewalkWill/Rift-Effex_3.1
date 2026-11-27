//
//  PGLMaskFilter.swift
//  RiftEffects
//
//  Created by Will on 12/26/24.
//  Copyright © 2024 Will Loew-Blosser. All rights reserved.
//

import Foundation
import CoreImage
import simd
import UIKit
import os

class PGLMaskFilter: PGLRectangleFilter {

    /// the mask output is not scaled - already in the input space
    override var showsInputWhileEditing: Bool {
        return false
    }

    override func scaleOutput(ciOutput: CIImage, stackCropRect: CGRect) -> CIImage {
            // does NOT scale to extent of the stackCropRect
//        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")
//        NSLog("     no op change stackCropRect = \(stackCropRect)")
        return ciOutput
    }

    override class func displayName() -> String? {
        return NSLocalizedString("Mask", comment: "Mask filter display name")
    }
}


