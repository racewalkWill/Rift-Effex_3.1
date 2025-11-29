//
//  PGLFilterConstructor.swift
//  RiftEffects
//
//  Created by Will on 5/2/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//

import UIKit

class PGLFilterConstructor: NSObject,  CIFilterConstructor {
    //MARK: CIFilterConstructor protocol
    // see also the PGLFilterDescriptor method filter() -> CIFilter

    func filter(withName: String) -> CIFilter? {

        switch withName {
            case kPSequencedFilter :
                return PGLCISequenced()

            case kPBumpBlend :
                return PGLBumpBlendCI()

//            case kUIImagePasteFilter :
//                return CIMaximumScaleTransform()

//            case kPBumpFace:
//                return PGLBumpFaceCIFilter()
//            case kPFaceFilter:
//                    return PGLFaceCIFilter()
            case kPImages :
                    return PGLImageCIFilter()
           
            case kPRandom :
                return PGLRandomFilterAction()

//            case kPCarnivalMirror:
//                return PGLCarnivalMirror()


//            case kPWarpItMetal :
//                return WarpItMetalFilter()
            case kCompositeTextPositionFilter:
                /// supports prior version of the filter by answering new version
                return CompositeTextPositionFilter()

            case kBlendTextFilter:
//                return PGLTextImageGenerator.internalCIFilter()
                return CIBlendText()

            case kSaliencyBlurFilter:
                return PGLSaliencyBlurFilter()

            case kPCopyOut: return PGLCopyToOutputCIFilter()

            case kTriangleGradient: return PGLPolygonGradientCI()

            case k4SidedGradient: return PGLPolygonGradientCI()

            default:
                return CIFilter(name: withName)!
        }
    }

}
