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
   
    /// Authoritative rect in FilterCanvasSize units - mapped through the filter's PGLParmMapping
    /// onto where its image is drawn, like the point parms, so a crop or extent follows rotation,
    /// photos of other shapes and transition blends. `filterRect` is only the editing overlay frame.
    var canvasRect = CGRect.zero
    /// canvasRect before the last commit - restored by the Cancel action
    var previousCanvasRect: CGRect?
    /// the overlay edit not yet committed by OK - in canvas units so it survives rotation
    /// and mapping changes (a transition blends its rect every frame)
    var pendingCanvasRect: CGRect?
    /// the mapping at the last pushToFilter
    var appliedMapping: PGLParmMapping?

    var isCropped = false
    var imageParmState = ParmInputState.rectangleInput

    /// Reduction filters sample a region of their input - the default region is the whole image.
    static let wholeImageDefaultFilters: Set<String> = [
        "CIAreaAlphaWeightedHistogram", "CIAreaAverage", "CIAreaAverageMaximumRed", "CIAreaBoundsRed",
        "CIAreaHistogram", "CIAreaLogarithmicHistogram", "CIAreaMaximum", "CIAreaMaximumAlpha",
        "CIAreaMinMax", "CIAreaMinMaxRed", "CIAreaMinimum", "CIAreaMinimumAlpha",
        "CIRowAverage", "CIColumnAverage", "CIKMeans"
    ]


    required init?(pglFilter: PGLSourceFilter, attributeDict: [String:Any], inputKey: String ) {
        super.init(pglFilter: pglFilter, attributeDict: attributeDict, inputKey: inputKey)
        // a saved value replaces this in #setStoredValueToAttribute / #resizeFrom
        canvasRect = defaultCanvasRect()
        pushToFilter(mapping: currentParmMapping())
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
        // Cancel - back to the canvas rect before the last commit
        pendingCanvasRect = nil
        if let previousCanvasRect {
            canvasRect = previousCanvasRect
            pushToFilter(mapping: currentParmMapping())
        }
    }

    /// The stored rect is relative to the saved render size (the stack globalSize) -
    /// see storeParmValue. Stretch it per axis to FilterCanvasSize, the same as the point parms.
    override func resizeFrom(savedSize: CGSize?) {
        // assumes setStoredValueToAttribute has set canvasRect to the stored rect
        guard savedSize != nil else { return }
        canvasRect = canvasRect.applying(resizeStoredTransform(savedSize, destination: FilterCanvasSize))
        pushToFilter(mapping: currentParmMapping())
    }

    // MARK: canvas rect

    /// The initial rect, from the filter's own CIAttributeDefault:
    /// - unbounded "no crop" rect (CICrop) - the whole image, uncropped
    /// - reduction filters (wholeImageDefaultFilters) - the whole image
    /// - zero rect, no default, or a small fixed default (CIClamp, generators, transitions...)
    ///   - inset by 200 render pixels (R239.0) so the first display shows output
    func defaultCanvasRect() -> CGRect {
        let wholeCanvas = CGRect(origin: .zero, size: FilterCanvasSize)
        if let filterName = aSourceFilter?.localFilter.name,
           PGLAttributeRectangle.wholeImageDefaultFilters.contains(filterName) {
            return wholeCanvas
        }
        if let ciDefault = initDict[kCIAttributeDefault] as? CIVector, ciDefault.count == 4 {
            let defaultRect = ciDefault.cgRectValue
            if defaultRect.isInfinite || defaultRect.width > 1.0e100 || defaultRect.height > 1.0e100 {
                return wholeCanvas
            }
        }
        // 200 render pixels as a fraction of the render size - the filter usually has no input
        // image yet, so the inset is kept relative to the canvas, which maps onto the image
        let renderSize = RenderTargetSize
        guard renderSize.width > 0, renderSize.height > 0 else {
            return wholeCanvas.insetBy(dx: FilterCanvasSize.width * 0.1, dy: FilterCanvasSize.height * 0.1)
        }
        let insetX = min(FilterCanvasSize.width * 200.0 / renderSize.width, FilterCanvasSize.width * 0.4)
        let insetY = min(FilterCanvasSize.height * 200.0 / renderSize.height, FilterCanvasSize.height * 0.4)
        return wholeCanvas.insetBy(dx: insetX, dy: insetY)
    }

    /// Converts canvasRect through `mapping` and writes it into the actual CIFilter.
    func pushToFilter(mapping: PGLParmMapping) {
        guard let attributeName else { return }
        let renderVector = mapping.toRender(CIVector(cgRect: canvasRect))
        aSourceFilter?.setVectorValue(newValue: renderVector, keyName: attributeName)
        appliedMapping = mapping
    }

    override func applyMapping(_ mapping: PGLParmMapping) {
        // pushes only when the reference rect, render size or aspect fill changed
        if appliedMapping != mapping {
            pushToFilter(mapping: mapping)
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
        if LogDiagnostic { NSLog("DIAGNOSTIC PGLAttributeRectangle.moveTo [3] startPoint=\(startPoint) newPoint=\(newPoint) filterRect=\(filterRect)") }

        // let the parent filter do the work in CIImage.methods  see PGLCropFilter outputImage()
    }

    override func set(_ value: Any) {
        // this parm should use the applyCropRect.. bypass the set call
        // empty implementation
    }
    // MARK: overlay

    /// inset of the overlay from the image edges when the rect covers the whole image
    static let wholeImageOverlayInset: CGFloat = 100.0

    /// The overlay frame in the image view - the pending edit, else the committed rect.
    /// A rect covering the whole image (the CICrop default) would put the frame on the image
    /// edges where it is hard to see - the overlay starts inset instead; OK commits that frame,
    /// otherwise the value stays the whole image.
    func overlayViewRect(viewSize: CGSize) -> CGRect {
        let mapping = currentParmMapping()
        let valueRect = mapping.viewRect(for: pendingCanvasRect ?? canvasRect, viewSize: viewSize)
        guard pendingCanvasRect == nil else { return valueRect }
        let imageRect = mapping.viewRect(for: CGRect(origin: .zero, size: FilterCanvasSize), viewSize: viewSize)
            .intersection(CGRect(origin: .zero, size: viewSize))
        guard !imageRect.isNull, !imageRect.isEmpty,
              valueRect.insetBy(dx: -1, dy: -1).contains(imageRect)
            else { return valueRect }
        let insetX = min(PGLAttributeRectangle.wholeImageOverlayInset, imageRect.width * 0.3)
        let insetY = min(PGLAttributeRectangle.wholeImageOverlayInset, imageRect.height * 0.3)
        return imageRect.insetBy(dx: insetX, dy: insetY)
    }

    /// keep the overlay frame after a drag as the pending edit
    func setPendingOverlay(viewRect: CGRect, viewSize: CGSize) {
        pendingCanvasRect = currentParmMapping().canvasRect(for: viewRect, viewSize: viewSize)
    }

    /// The OK action - commit the overlay frame (view points in the image view).
    func commitOverlay(viewRect: CGRect, viewSize: CGSize) {
        parmInputState = .inputValueSet
        let mapping = currentParmMapping()
        previousCanvasRect = canvasRect  // for the Cancel action
        canvasRect = mapping.canvasRect(for: viewRect, viewSize: viewSize)
        pendingCanvasRect = nil
        pushToFilter(mapping: mapping)
    }

    /// Commit a rect in render pixels (CoreImage LLO) - an archived CIFilter value.
    /// Converted to canvas units through the filter's current mapping.
    func applyCropRect(mappedCropRect: CGRect) {
        parmInputState = .inputValueSet
        let mapping = currentParmMapping()
        previousCanvasRect = canvasRect  // for the Cancel action
        canvasRect = mapping.toCanvas(rect: mappedCropRect)
        pushToFilter(mapping: mapping)
        // let the parent filter do the work in CIImage.methods  see PGLRectangleFilter outputImage()
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
            if LogDiagnostic { NSLog("DIAGNOSTIC PGLAttributeRectangle.movingChange [3] startPoint=\(actualStartPoint) newPoint=\(newPoint) filterRect=\(filterRect)") }
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
         if LogDiagnostic { NSLog("DIAGNOSTIC PGLAttributeRectangle.movingCorner [3] atCorner=\(atCorner) startPoint=\(actualStartPoint) newPoint=\(newPoint) filterRect=\(filterRect)") }

    }

  

    override func isRectUI() -> Bool {
        return true // super class answers false
        // where attributeType= "CIAttributeTypeRectangle"
        //  & attributeClass= AttrClass.Vector.rawValue
    }

    // MARK: controlImageView

}
