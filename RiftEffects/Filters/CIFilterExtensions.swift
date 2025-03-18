//
//  CIFilterExtensions.swift
//  PictureGlance
//
//  Created by Will Loew-Blosser on 3/11/17.
//  Copyright © 2017 Will Loew-Blosser. All rights reserved.
//  based on Apple sample app CIFunHouse file CIFilter+FHAdditions
//

import Foundation
import CoreImage

enum Stack { case begin, middle, end }

// constants for custom filter creation / loading

let kPSequencedFilter = "Sequenced Filters"
let kPChildSequenceStack = "ChildSequenceStack"
let kPFaceFilter = "FaceFilter"
let kPBumpBlend = "BumpBlend"
let kPBumpFace = "BumpFace"
let kPImages = "Images"  // "Pics" //"Images"
let kPRandom = "Random Filters"
let kPCarnivalMirror = "CarnivalMirror"
let kPTiltShift = "TiltShift"
let kPWarpItMetal  = "WarpItMetal"
let kPCopyOut = "VideoCam"
let kCompositeTextPositionFilter = "CompositeTextPositionFilter"
let kBlendTextFilter = "BlendText"
let kSaliencyBlurFilter = "Saliency Blur"
let kTriangleGradient = "Triangle Gradient"
let k4SidedGradient = "4 Sided Gradient"

let kPMaskFilter = "MaskFilter"

// MOVED in  121.05  to CIFilterToPGLFilter.Map


extension Int { func isEven() -> Bool { return (self % 2 == 0) } }

extension CGRect {
    func isNAN() -> Bool {
        return width.isNaN || height.isNaN
    }

    func isXYInfinite() -> Bool {
        return origin.x.isInfinite || origin.y.isInfinite
    }

    func isOutofRange() -> Bool {
        let answer =  isNAN() || isXYInfinite()
        return answer
    }
}

