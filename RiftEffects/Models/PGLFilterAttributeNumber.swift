//
//  PGLFilterAttributeNumber.swift
//  Glance
//
//  Created by Will on 4/1/19.
//  Copyright © 2019 Will. All rights reserved.
//

import Foundation

import UIKit
import Photos
import CoreImage

class PGLFilterAttributeNumber: PGLFilterAttribute {

    /// Authoritative value of a Distance parm (tile width, blur radius, zoom amount...) in
    /// FilterCanvasSize units. The CIFilter holds this through the filter's PGLParmMapping so
    /// the distance scales with the image like the point parms. nil until first set or
    /// render - then the CIFilter's current value (its default) is taken as the canvas value.
    var canvasNumber: NSNumber?
    /// the mapping at the last pushToFilter
    var appliedMapping: PGLParmMapping?

    required init?(pglFilter: PGLSourceFilter, attributeDict: [String:Any], inputKey: String ) {
        super.init(pglFilter: pglFilter, attributeDict: attributeDict, inputKey: inputKey)


    }

    /// Distance parms are pixel lengths - kept in canvas units and scaled to the render size
    func usesCanvasDistance() -> Bool {
        return attributeType == AttrType.Distance.rawValue
    }

    override func set(_ value: Any) {
         if attributeName != nil {
            if let myNumber = value as? NSNumber {
                parmInputState = .inputValueSet
                if usesCanvasDistance() {
                    canvasNumber = myNumber
                    pushToFilter(mapping: currentParmMapping())
                } else {
                    aSourceFilter?.setNumberValue(newValue: myNumber, keyName: attributeName!) }
                }
        }
    }

    /// Distance parms answer the canvas value - sliders, animation and storage work in canvas units
    override func getValue() -> Any? {
        if usesCanvasDistance(), let canvasNumber {
            return canvasNumber
        }
        return super.getValue()
    }

    /// Converts the canvas value through `mapping` and writes it into the actual CIFilter.
    func pushToFilter(mapping: PGLParmMapping) {
        guard let canvasNumber, attributeName != nil else { return }
        let renderValue = mapping.toRender(distance: CGFloat(canvasNumber.doubleValue))
        aSourceFilter?.setNumberValue(newValue: NSNumber(value: Double(renderValue)), keyName: attributeName!)
        appliedMapping = mapping
    }

    override func applyMapping(_ mapping: PGLParmMapping) {
        guard usesCanvasDistance() else { return }
        if canvasNumber == nil {
            // first render - the CIFilter default is the canvas value
            canvasNumber = super.getValue() as? NSNumber
        }
        if appliedMapping != mapping {
            pushToFilter(mapping: mapping)
        }
    }

    /// The stored value is in the saved render size - see storeParmValue.
    /// Convert it to canvas units with the same uniform fit used to store it.
    override func resizeFrom(savedSize: CGSize?) {
        guard usesCanvasDistance(), let savedSize, savedSize.width > 0, savedSize.height > 0,
              let storedNumber = canvasNumber
            else { return }
        let canvasValue = storedNumber.doubleValue / Double(canvasUniformFitScale(size: savedSize))
        set(NSNumber(value: canvasValue))
    }

    override func incrementValueDelta() {
//        NSLog("\(String(describing: self)) incrementValueDelta \(Unmanaged.passUnretained(self).toOpaque()) attributeName: \(attributeName ?? "nil")")
        let curentNumericValue =  Float(truncating: self.getNumberValue() ?? 1.3)
                // as? Float {
            // value is type Double 1.3
            // now increment value
            if  (attributeValueDelta != nil ){
                var newValue = curentNumericValue + attributeValueDelta!
                if newValue.isNaN {return }
                if newValue.isInfinite {return }
                if newValue > sliderMaxValue ?? 100.0 { newValue = sliderMaxValue ?? 100.0
                    flipAnimationDirectionAtEnd() }
                if newValue < sliderMinValue ?? 0.0 { newValue = sliderMinValue ?? 0.0
                    flipAnimationDirectionAtEnd()}
                // this will make the change stop until the frame count reaches a point to flip direction
                
//                NSLog("PGLFilterAttributeNumber incrementValueDelta curentNumericValue \(curentNumericValue)")
//                NSLog("PGLFilterAttributeNumber incrementValueDelta attributeValueDelta = \(String(describing: attributeValueDelta))")
//                NSLog("PGLFilterAttributeNumber incrementValueDelta newValue \(newValue)")

                if usesCanvasDistance() {
                    canvasNumber = newValue as NSNumber
                    pushToFilter(mapping: appliedMapping ?? currentParmMapping())
                } else {
                    aSourceFilter?.setNumberValue(newValue: newValue as NSNumber, keyName: attributeName!)
                }
                postUIChange(attribute: self)
            }

    }
    override func valueString() -> String {
        let parmNumber = getValue() as! Double
        // could use getNumberValue() to avoid a generic..
//        NSLog("PGLFilterAttributeNumber #valueString has value \(parmNumber)")
        return String(format: "%.03f", parmNumber)
    }

    override  func setUICellDescription(_ uiCell: UITableViewCell) {
      if isBooleanUI() {
        // boolean parms use the switch cell handled by the base class
        return super.setUICellDescription(uiCell)
      }
      var content = uiCell.defaultContentConfiguration()
      let newDescriptionString = self.attributeDisplayName ?? ""
      content.text = newDescriptionString
      content.imageProperties.tintColor = .secondaryLabel
        content.image = UIImage(systemName: "slider.horizontal.below.rectangle")

      uiCell.contentConfiguration = content

    }

}






