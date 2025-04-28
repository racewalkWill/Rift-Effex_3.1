//
//  PGLFilterAttributeAffine.swift
//  RiftEffects
//
//  Created by Will on 1/21/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//
import Foundation
import UIKit
import Photos
import CoreImage
import Accelerate
import os
import Combine

class PGLFilterAttributeAffine: PGLFilterAttribute {

    // the affine itself does not really hold vars to change.
    // these var, rotation, scale and translate will produce or change
    // the affine.
    // the initial values will be defaults
    
    // the affine becomes a runtime generated value from the stored
    // rotation, scale & translate
    // this is in contrast to most other filters where the UI components
    // update.display the underlying  values from the stored filter


    var affine = (CGAffineTransform.identity).scaledBy(x: 1.0 , y: 1.0)
    var rotation: Float = 0.0
    var scale: Float = 1.0 // identity scale
    var translate = CIVector(x: 0.0, y: 0.0)
    var valueParms = [PGLFilterAttribute]()
    var childUIAttributeName = "empty"

    //MARK: affine matrix vars
        // init to identity values
        // used to read affine
           var a: Double?
           var b: Double?
           var c: Double?
           var d: Double?
           var tx: Double?
           var ty: Double?


    required init?(pglFilter: PGLSourceFilter, attributeDict: [String:Any], inputKey: String ) {
        super.init(pglFilter: pglFilter, attributeDict: attributeDict, inputKey: inputKey)
//        setRotation(radians: 0.01)
//        setRotation(radians: -0.01)

    }

    override func valueInterface() -> [PGLFilterAttribute] {
        // subclasses such as PGLFilterAttributeAffine implement a attributeUI collection
        // single affine parm attribute needs three independent settings rotate, scale, translate

        if let rotateParm = PGLRotateAffineUI(pglFilter: aSourceFilter, attributeDict: initDict, inputKey: attributeName!)
        {   rotateParm.affine(parent: self)
            valueParms.append(rotateParm) // add translate & scale here
        }

        if let translateParm = PGLTranslateAffineUI(pglFilter: aSourceFilter, attributeDict: initDict, inputKey: attributeName!)
        {   translateParm.affine(parent: self)
            valueParms.append(translateParm) // add translate & scale here
        }

        if let scaleParm = PGLScaleAffineUI(pglFilter: aSourceFilter, attributeDict: initDict, inputKey: attributeName!)
        {   scaleParm.affine(parent: self)
            valueParms.append(scaleParm) // add translate & scale here
        }
        return valueParms
    }

    func setAffine() {
      NSLog("setAffine = \(affine)")
        parmInputState = .inputValueSet
        let nsTransform = NSValue(cgAffineTransform: affine)
        aSourceFilter.setNSValue(newValue: nsTransform, keyName: attributeName!)
    }

//    func setScale(vector: CIVector) {
//        NSLog("PGLFilterAttributeAffine setScale affine = \(affine), vector = \(vector)")
//        let xScale = vector.x
//        let yScale = vector.y
//
//        NSLog("PGLFilterAttributeAffine xScale = \(xScale), yScale = \(yScale)")
//        affine = affine.scaledBy(x: CGFloat(vector.x), y: CGFloat(vector.y))
//        // this throws away the rotate and translate changes...
//
//        setAffine()
//        NSLog("PGLFilterAttributeAffine setScale NOW affine = \(affine)")
//    }

    func setScale(xScale: Float, yScale: Float) {
        affine = affine.scaledBy(x: CGFloat(xScale), y: CGFloat(yScale))
        setAffine()
    }


    func setRotation(radians: Float) {
        // should radians be normalized to a 0..1.0 range?

        affine = affine.rotated(by: CGFloat(radians))
        rotation = radians
        setAffine()

    }


    func setTranslation(moveBy: CIVector) {
//        NSLog ("setTranslation by: \(moveBy)")
        affine = affine.translatedBy(x: CGFloat(moveBy.x), y: CGFloat(moveBy.y))
        translate = moveBy
        setAffine()
    }



    override func set(_ value: Any ) {
        if let newAffine = value as? CGAffineTransform {
            affine = newAffine
            setAffine()
        }

    }
    override func incrementValueDelta() {
        // animation time range 0.0 to 1.0

            setRotation(radians: attributeValueDelta! )
            postUIChange(attribute: self)

    }

   override func varyTimerAttribute() -> PGLFilterAttribute? {
        return nil // affine does not directly vary.. UI attributes attached can vary
    }

    override func resizeFrom(savedSize: CGSize?) {
        // assumes setStoredValueToAttribute has created the filter rect
        if savedSize != nil {
            let resizingTransform = resizeStoredTransform(savedSize)
            affine = affine.concatenating(resizingTransform)
            setAffine()
        }
    }

}
