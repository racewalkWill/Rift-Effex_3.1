//
//  PGLGradientAttribute.swift
//  RiftEffects
//
//  Created by Will on 3/23/24.
//  Copyright © 2024 Will Loew-Blosser. All rights reserved.
//

import Foundation
import CoreImage
import simd
import UIKit
import os

let kPGradientKeyDelimitor = Character(".")

class PGLGradientChildFilter: PGLSourceFilter {
        // parent is PGLTriangleGradientFilter or subclass

    var parentFilter: PGLTriangleGradientFilter?
    var sideKey = 0

    ///  get values with debug setting of PGLSourceFilter.LogParmValues = true
    ///  then adjust visually and copy values from the log
    static let VectorDefaultsiPad: [String: CGPoint] =  [
        "linear0.inputPoint0": CGPoint(x:213, y: 398),
        "linear0.inputPoint1": CGPoint(x:209 , y: 319),
        "linear1.inputPoint0": CGPoint(x:1017, y: 717),
        "linear1.inputPoint1": CGPoint(x:1047 , y: 719),
        "linear2.inputPoint0": CGPoint(x:441, y: 568),
        "linear2.inputPoint1": CGPoint(x:392 , y: 610)
    ]

    static let VectorDefaultsiPhone: [String: CGPoint] =  [
        "linear0.inputPoint0": CGPoint(x:210, y: 371),
        "linear0.inputPoint1": CGPoint(x:209 , y: 289),
        "linear1.inputPoint0": CGPoint(x:980, y: 672),
        "linear1.inputPoint1": CGPoint(x:1012 , y: 683),
        "linear2.inputPoint0": CGPoint(x:419, y: 562),
        "linear2.inputPoint1": CGPoint(x:411 , y: 574)
    ]

    var appStack: PGLAppStack! {
        // now a computed property
        guard let myAppDelegate =  UIApplication.shared.delegate as? AppDelegate
            else { Logger(subsystem: LogSubsystem, category: LogCategory).fault("PGLSelectParmController viewDidLoad fatalError(AppDelegate not loaded")
            fatalError("PGLSelectParmController could not access the AppDelegate")
        }
       return  myAppDelegate.appStack
    }

    required init?(filter: String, position: PGLFilterCategoryIndex) {
        super.init(filter: filter, position: position)
    }

    override func parmClass(parmDict: [String : Any ]) -> PGLFilterAttribute.Type  {
            // override in PGLSourceFilter subclasses..
            // most will do a lookup in the class method

        if  (parmDict[kCIAttributeClass] as! String == AttrClass.Vector.rawValue)
        {
            return PGLGradientVectorAttribute.self }
        else {
                // not a vector parm... return a normal lookup.. usually the imageParm
            return PGLFilterAttribute.parmClass(parmDict: parmDict) }
    }

    override func setDefaults() {
            // for side key = 3
        setTriangleVectorDefaults()
    }

    func vectorAttributes() -> [PGLFilterAttribute] {
        return attributes.filter({ $0.isVector() })
    }

    func setTriangleVectorDefaults() {

        for myAttribute in vectorAttributes() {
            if let thisVectorName = myAttribute.attributeName{
                if let newPoint = PGLGradientChildFilter.VectorDefaultsiPhone[thisVectorName] {
                    let newValue = CIVector(cgPoint: newPoint)
                    setVectorValue(newValue: newValue, keyName: thisVectorName)
                }
            }
        }
    }

        /// need to filter the keyName to the base part that the ciFilter supports
        ///  keyName has format to be unique when there are multiple gradients in use
        ///    format is gradient.keyName  ie linear1.inputPoint1
    override func setVectorValue(newValue: CIVector, keyName: String) {

        let suffixKeyName = baseKeyName(compoundKeyName: keyName)
        super.setVectorValue(newValue: newValue, keyName: suffixKeyName)

    }

    func prefixGradientIndex(compoundKeyName: String) -> Int {
        if let delimitorIndex = compoundKeyName.firstIndex(of: kPGradientKeyDelimitor) {
            let prefix = compoundKeyName.prefix(upTo: delimitorIndex)
            let lastChar = prefix.last
            return lastChar?.wholeNumberValue ?? 0
        }
        return 0
    }

        /// answer suffix part of the keyName inputPoint1
        ///    format is gradient.keyName  ie linear1.inputPoint1
    func baseKeyName(compoundKeyName: String ) -> String {
        if let suffixPosition = compoundKeyName.firstIndex(of: kPGradientKeyDelimitor)  {
            var answer =  String(compoundKeyName.suffix(from: suffixPosition))
            answer.removeFirst() // take out the period delimitor that is now leading char
            return answer
        }
        else { return compoundKeyName }
    }

        /// format is gradient.keyName  ie linear1.inputPoint1
        /// prefix shows which of the multiple gradient filters this kay belongs to
        ///  value for inputPoint1
    override func valueFor( keyName: String) -> Any? {
        let suffixKeyName = baseKeyName(compoundKeyName: keyName )
        return super.valueFor(keyName: suffixKeyName)
    }

    func applyTranslationMove(translation: CGAffineTransform) {
            // get the current value of this attribute from the filter
            // apply the translation and set as the new value
        for anAttribute in vectorAttributes() {
            if let vectorAttribute = anAttribute as? PGLGradientVectorAttribute {
                if let oldVector =  self.valueFor(keyName: vectorAttribute.attributeName!) as? CIVector
                {
                    let oldPoint = oldVector.cgPointValue
                    let newPoint = oldPoint.applying(translation)
                    let newVector = CIVector(cgPoint: newPoint)
                    setVectorValue(newValue: newVector, keyName: vectorAttribute.attributeName!)
                    // update the view positionControl center
                    if let positionControl = appStack.parmControls[vectorAttribute.attributeName!] {
                        let newViewCenter = vectorAttribute.mapVector2PointScaled(vector: newVector ) 
                        positionControl.center = newViewCenter
                    }

                }
            }
        }

    }
}

