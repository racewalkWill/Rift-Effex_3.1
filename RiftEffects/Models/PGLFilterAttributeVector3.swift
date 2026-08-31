//
//  PGLFilterAttributeVector3.swift
//  RiftEffects
//
//  Created by Will on 1/24/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//

import UIKit

class PGLFilterAttributeVector3: PGLFilterAttributeVector {
    // has a 3d position of three points..
    // use the existing superclass for 2 points
    // add a slider for the third point in a subUI cell

    var zValue: CGFloat = 0.0

    required init?(pglFilter: PGLSourceFilter, attributeDict: [String:Any], inputKey: String ) {
        super.init(pglFilter: pglFilter, attributeDict: attributeDict, inputKey: inputKey)

        zValue = FilterCanvasSize.height / 7.0
            // FilterCanvasSize is fixed, so this default is now identical across devices
        set3ValueVector( zValue)

    }
    override func valueInterface() -> [PGLFilterAttribute] {
        // subclasses such as PGLFilterAttributeAffine implement a attributeUI collection
        // single affine parm attribute needs three independent settings rotate, scale, translate

        var vectorUICells = super.valueInterface()
        if let parm3 = PGLVectorNumeric3UI(pglFilter: aSourceFilter, attributeDict: initDict, inputKey: attributeName!)
        {   parm3.zValueParent = self
            vectorUICells.append(parm3)
            return vectorUICells
        } else { return vectorUICells }

}
    override func set(_ value: Any) {

        if attributeName != nil {
            if let newVector = value as? CIVector {

                set3ValueVector(newVector, newZValue: zValue) }

            }
        }

    func set3ValueVector(_ newXYvector: CIVector, newZValue: CGFloat) {
        // the XYvector is dragged to a new point - both stored canvas-relative.
            parmInputState = .inputValueSet
            zValue = newZValue
            canvasVector = CIVector(x: newXYvector.x, y: newXYvector.y, z: newZValue)
            pushToFilter(renderSize: RenderTargetSize)
    }

    func set3ValueVector(_ newZValue: CGFloat) {
        // when the zValue is the only change
        zValue = newZValue
        if let oldVector = getVectorValue() {
            set3ValueVector(oldVector, newZValue: newZValue)
        }
    }

    override func usesCanvasCoordinates() -> Bool {
        // only some PGLFilterAttributeVectors use canvas coordinates
        return true
    }

    override func resizeFrom(savedSize: CGSize?) {
        // Base PGLFilterAttributeVector.resizeFrom() ends by calling set(_:), but this
        // class's set(_:) override ignores the z component of whatever CIVector it's given
        // and substitutes the current (not-yet-resized) zValue - so routing through it here
        // would silently drop the resized z. Go through set3ValueVector directly instead.
        guard usesCanvasCoordinates() else { return }
        guard savedSize != nil, let currentVector = canvasVector else { return }
        let resizingTransform = resizeStoredTransform(savedSize, destination: FilterCanvasSize)
        let resized = currentVector.applying(resizingTransform)
        set3ValueVector(resized, newZValue: resized.z)
        if startPoint != nil {
            startPoint = startPoint!.applying(resizingTransform)
        }
        if endPoint != nil {
            endPoint = endPoint!.applying(resizingTransform)
        }
    }

    override func incrementValueDelta()  {
        // animation time range 0.0 to 1.0
        // must also set with a x,y,z vector
        // z component of the vector is not animated

            if (endPoint != nil)  && (startPoint != nil ){

                let distanceTime = vectorLength * attributeValueDelta!

                let newX = Float(startPoint!.x) + (xSign * (vectorCos * distanceTime))
                let newY = Float(startPoint!.y) + (vectorSin * distanceTime)
                set3ValueVector(CIVector(x: CGFloat(newX), y: CGFloat(newY)), newZValue: zValue)
                postUIChange(attribute: self)
            }
        }




}
