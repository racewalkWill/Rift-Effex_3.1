//
//  PGLAttributeRectangle.swift
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


class PGLAttributeRectangle: PGLFilterAttribute {
    // where attributeType= "CIAttributeTypeRectangle"
    //  & attributeClass= AttrClass.Vector.rawValue
   
    var filterRect: CGRect =  CGRect(x: 0, y: 0, width: 300, height: 300)
//    {didSet {
////        NSLog("PGLAttributeRectangle didSet filterRect = \(filterRect)")
//      //  filterRect = (0.0, 0.0, 1583.0, 1668.0)
//        if (filterRect.height >= 1660){
//            NSLog("PGLAttributeRectangle full size filterRect = \(filterRect)")
//        }
//        // this is called to much in the inputImage code.. WHY?
//        }}
   
    var oldVector: CIVector?
    var isCropped = false
    var imageParmState = ParmInputState.rectangleInput


    required init?(pglFilter: PGLSourceFilter, attributeDict: [String:Any], inputKey: String ) {
        super.init(pglFilter: pglFilter, attributeDict: attributeDict, inputKey: inputKey)
        if let myVector = self.getVectorValue(){
//            NSLog("PGLFilterAttributeRectangle init vectorValue = x:\(myVector.x) y:\(myVector.y)  width: \( myVector.z) height: \(myVector.w)")
            if (myVector.x < 1.0 && myVector.y < 1.0 && myVector.z < 1.0 && myVector.w < 1.0) {
                filterRect = CGRect(x: myVector.x, y: myVector.y, width: myVector.z, height: myVector.w)
            }  // else keep the default rect of 300
            else {
                // default to TargetSize or effectively no crop
                filterRect = CGRect(origin: CGPoint.zero, size: TargetSize)
                applyCropRect(mappedCropRect: filterRect)
            }
        }
        if let rectangleFilter = pglFilter as? PGLRectangleFilter {
            rectangleFilter.cropAttribute = self
        }
//        NSLog("PGLFilterAttributeRectangle init filterRect = \(filterRect)")
        // the rect should actually be the frame of the rectangle controller view..
        // raises question about why the filterRect is on this object..
    }

    override func valueString() -> String {
        if isCropped {
             return String(describing: (getValue() ?? "") )
        }
        else { // no meaningful value
                return ""}
    }

    override func inputParmType() -> ParmInputState {

        return imageParmState
    }

    override  func setUICellDescription(_ uiCell: UITableViewCell) {
      var content = uiCell.defaultContentConfiguration()
      let newDescriptionString = self.attributeDisplayName ?? ""
      content.text = newDescriptionString
      content.imageProperties.tintColor = .secondaryLabel
    content.image = UIImage(systemName: "crop")

      uiCell.contentConfiguration = content

    }
    // MARK: change values

    override func cellAction() -> [PGLTableCellAction] {
        var allActions = [PGLTableCellAction]()

        if isCropped {
            let cancelAction = PGLTableCellAction(action: "Cancel", newAttribute: nil, canPerformAction: true, targetAttribute: self)
            cancelAction.performAction2 = true  // runs performAction2
            allActions.append(cancelAction)
        }
        else {
            let okAction = PGLTableCellAction(action: "OK", newAttribute: nil, canPerformAction: true, targetAttribute: self)
            allActions.append(okAction)
        }
        return allActions

    }

    override func performAction(_ controller: PGLSelectParmController?) {
        NSLog("PGLFilterAttributeRectangle #performAction ")
       controller?.cropAction(rectAttribute: self)
        controller?.hideRectController()
        isCropped = true
    }

    override func performAction2(_ controller: PGLSelectParmController?) {
        // Cancel action from the swipe cell

        restoreOldValue()
        controller?.hideRectController()
         isCropped = false
    }
    override func varyTimerAttribute() -> PGLFilterAttribute? {
        return nil // rectangle does not directly vary.. UI attributes attached can vary
    }

   override func okActionToSetValue() -> Bool {
        // subclass override to true if set value is deferred to the OK action of the parm cell
        return true
    }

    override func restoreOldValue() {
        // implement in subclasses for the various setValue types
        // each type should have a var for the last value to restore
        // future may be an array of changes.
//        set(oldVector)  // the form of set() does some typecasting to any and back again.. in this subclass set directly
        if oldVector != nil {
            aSourceFilter.setVectorValue(newValue: oldVector!, keyName: attributeName!)
        }
    }

    override func resizeFrom(savedSize: CGSize?) {
        // assumes setStoredValueToAttribute has created the filter rect
        if savedSize != nil {
            let resizingTransform = resizeStoredTransform(savedSize)
            filterRect = filterRect.applying(resizingTransform)
            applyCropRect(mappedCropRect: filterRect)
        }
    }


    //MARK: movement

    override func moveTo(startPoint: CGPoint, newPoint: CGPoint, inView: UIView) {
        // there is  the case of drag of the same size rect to a new position.
        // also case of new rectangle based on adjusting the rect vertex closest to the start point to the new point.


        let newOriginX = filterRect.origin.x + (newPoint.x - startPoint.x)
        let newOriginY = filterRect.origin.y + (newPoint.y - startPoint.y)

        filterRect.origin.x = newOriginX
        filterRect.origin.y = newOriginY

        // let the parent filter do the work in CIImage.methods  see PGLCropFilter outputImage()
    }

    override func set(_ value: Any) {
        // this parm should use the applyCropRect.. bypass the set call
        // empty implementation
    }
    func applyCropRect(mappedCropRect: CGRect) {
        // assumes mappedCropRect is the new frame as transformed into the CIImage size and LLO coordinates
        // generate the vector
        // save the old vector
        // apply to the filter
        parmInputState = .inputValueSet
        
        let newVector = CIVector(x: mappedCropRect.origin.x, y: mappedCropRect.origin.y, z: mappedCropRect.size.width, w: mappedCropRect.size.height)
//        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")
//        NSLog("     newVector \(newVector) from \(mappedCropRect)")
        oldVector = self.getVectorValue()  // save old value for cancel action
        aSourceFilter.setVectorValue(newValue: newVector, keyName: attributeName!)
        // let the parent filter do the work in CIImage.methods  see PGLRectangleFilter outputImage()
        filterRect = mappedCropRect // save the rect

    }

    override func movePointParms(transform: CGAffineTransform) {
           // adjust the crop for a move of parms
        let newCropRect = filterRect.applying(transform)
        applyCropRect(mappedCropRect: newCropRect)

    }


    override func movingChange(startPoint: CGPoint, newPoint: CGPoint, inView: UIView) {
        // pan move in progress.. update as needed
        // does not change the filter just changes the rect of the parm
//        let logMovingChange = false

        let actualStartPoint: CGPoint

        if startPoint == CGPoint.zero {actualStartPoint = newPoint} else {actualStartPoint = startPoint}
         // the first call of pan change does not know the start point.. later calls during the pan have the value.

        switch attributeClass! {
        case AttrClass.Vector.rawValue :

//            if logMovingChange {   NSLog("PGLFilterAttributeRectangle #movingChange startPoint = \(startPoint) newPoint = \(newPoint)")

//                NSLog("PGLFilterAttributeRectangle #movingChange in view.frame = \(inView.frame)") }
            // this is the view.frame of PGLParmTableViewController.


            let deltaX = newPoint.x - actualStartPoint.x
            let deltaY = newPoint.y - actualStartPoint.y


            let newOriginX = filterRect.origin.x + deltaX
            let newOriginY = filterRect.origin.y + deltaY
//            if logMovingChange {           NSLog("PGLFilterAttributeRectangle #movingChange filterRect = \(filterRect)") }
//            if newOriginX == 0 { fatalError(" going to zero origin in filterRect.origin" )}
            filterRect.origin = CGPoint(x:newOriginX, y: newOriginY)
//            if logMovingChange { NSLog("PGLFilterAttributeRectangle #movingChange orgin moved filterRect = \(filterRect)")}


        case AttrClass.Color.rawValue: break
        case  AttrClass.Image.rawValue : break
        case  AttrClass.Number.rawValue :  break
        case  AttrClass.Data.rawValue :  break
        case  AttrClass.Value.rawValue : break
        case  AttrClass.Object.rawValue : break
        case  AttrClass.String.rawValue :  break
            
        default: assert(true == false)  // raises error on a new attribute class
        }


    }

    override func movingCorner(atCorner: Vertex, startPoint: CGPoint, newPoint: CGPoint) {
        // changes the corner but does not apply the change to the filter..
        // the visual rectangle is moving but the filter is not updated until the OK button
        let actualStartPoint: CGPoint
        var deltaX: CGFloat = 0.0
        var deltaY: CGFloat = 0.0
        if startPoint == CGPoint.zero {actualStartPoint = newPoint} else {actualStartPoint = startPoint}
        // the first call of pan change does not know the start point.. later calls during the pan have the value.
//        NSLog("PGLFilterAttributeRectangle #movingCorner filterRect = \(filterRect)")
//        NSLog("PGLFilterAttributeRectangle #movingCorner atCorner = \(atCorner) startPoint = \(startPoint) newPoint = \(newPoint)")
        switch atCorner {
            case Vertex.upperLeft:
                deltaX = newPoint.x - actualStartPoint.x
                deltaY = newPoint.y - actualStartPoint.y

            case Vertex.lowerRight:
                 deltaX =  actualStartPoint.x - newPoint.x
                 deltaY =  actualStartPoint.y - newPoint.y

            case Vertex.lowerLeft:
                 deltaX =   newPoint.x - actualStartPoint.x
                 deltaY =   actualStartPoint.y - newPoint.y

            case Vertex.upperRight:
                deltaX =  actualStartPoint.x - newPoint.x
                deltaY = newPoint.y - actualStartPoint.y

            }
         filterRect = filterRect.insetBy(dx: deltaX, dy: deltaY)
//         NSLog("PGLFilterAttributeRectangle #movingCorner filterRect NOW = \(filterRect)")

    }

  

    override func isRectUI() -> Bool {
        return true // super class answers false
        // where attributeType= "CIAttributeTypeRectangle"
        //  & attributeClass= AttrClass.Vector.rawValue
    }

    // MARK: controlImageView

}
