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
        if let defaultVector = getVectorValue() {
            zValue = defaultVector.z
        }

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
        // the XYvector is dragged to a new point.

            let newVector = CIVector(x: newXYvector.x, y: newXYvector.y, z: newZValue)
            aSourceFilter.setVectorValue(newValue: newVector, keyName: attributeName!)
    }

    func set3ValueVector(_ newZValue: CGFloat) {
        // when the zValue is the only change
        if let oldVector = getVectorValue() {
            let newVector = CIVector(x: oldVector.x, y: oldVector.y, z: newZValue)
             aSourceFilter.setVectorValue(newValue: newVector, keyName: attributeName!)
        }

        func getZValue() -> CGFloat {
            return getVectorValue()?.z ?? zValue
        }
        
    }

    override func moveOnDrawableSizeChange() -> Bool {
        // only some PGLFilterAttributeVectors should move
        return true
    }

    override func incrementValueDelta()  {
        // animation time range 0.0 to 1.0
        // must also set with a x,y,z vector
        // z component of the vector is not animated

            if (endPoint != nil)  && (startPoint != nil ){

                let distanceTime = vectorLength * attributeValueDelta!

                let newX = Float(startPoint!.x) + (xSign * (vectorCos * distanceTime))
                let newY = Float(startPoint!.y) + (vectorSin * distanceTime)
                let newVector = CIVector(x: CGFloat(newX), y: CGFloat(newY), z: zValue)
                aSourceFilter.setVectorValue(newValue: newVector, keyName: attributeName!)
                postUIChange(attribute: self)
            }
        }




}
