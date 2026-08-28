//
//  PGLAttributeVectorExpand.swift
//  RiftEffects
//
//  Created by Will on 12/14/22.
//  Copyright © 2022 Will Loew-Blosser. All rights reserved.
//

import Foundation

import UIKit
import Photos
import CoreImage

class PGLAttributeVectorExpand: PGLFilterAttributeVector {

    // Scales the filter's raw 0...1 CIToneCurve coordinates up to FilterCanvasSize-relative
    // coordinates, so getVectorValue()/set(_:) answer the same canonical space every other
    // vector-based attribute uses - markers stay correctly placed regardless of view size.
    var upScaler = CGAffineTransform(scaleX: FilterCanvasSize.width, y: FilterCanvasSize.height)

    override func shouldSetDefaultVectorValue() -> Bool {
        return false
    }

    override func usesCanvasCoordinates() -> Bool {
        // this attribute's canonical value is already pushed via set()/getVectorValue()
        // above (unit <-> canvas scaling), so it does not need the applyRenderSize hook
        return false
    }

    override func set(_ value: Any) {
        // divide by the scaler
        if attributeName != nil {
            if let newVectorValue = value as? CIVector {

                let scaledVectorValue = scaleVector(inputVector: newVectorValue, scaleBy: upScaler, invertScale: true)

                aSourceFilter.setVectorValue(newValue: scaledVectorValue, keyName: attributeName!)
                parmInputState = .inputValueSet
            }
        }
    }

    override func getVectorValue() -> CIVector? {
        // multiply by the scaler..
        // make the graphic point easier to drag with enlarged scale
       guard let filterValue = getValue() as? CIVector
        else { return CIVector.init(cgPoint: CGPoint.zero)}

        let scaledVectorValue = scaleVector(inputVector: filterValue, scaleBy: upScaler, invertScale: false)

        return scaledVectorValue
    }



}
