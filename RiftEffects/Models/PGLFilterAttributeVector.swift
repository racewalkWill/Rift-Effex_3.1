//
//  PGLFilterAttributeVector.swift
//  RiftEffects
//
//  Created by Will on 1/24/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//

import UIKit

class PGLFilterAttributeVector: PGLFilterAttribute {
    // value of the vector attribute is the current point of the filter
    // three vars must be set to do vector panning
    // animationTime, startPoint & endPoint
    var vectorLength:Float = 0.0
    var vectorAngle:Float = 0.0  //radians
    var vectorSin: Float = 0.0
    var vectorCos: Float = 0.0
    var xSign: Float = 1.0
    var xDelta: Float = 0.0
    var incrementDirection = 1 // changes sign on end of variation range 1 or -1

    //MARK: vary from to
    var startPoint: CIVector?
    var endPoint: CIVector? {
        didSet {  // setting the endpoint implies that startPoint is the current position
            if let newPoint = endPoint {

            let xSqr = pow((newPoint.x - startPoint!.x), 2.0)
            let ySqr = pow ((newPoint.y - startPoint!.y), 2.0)
            vectorLength =  sqrtf( Float(xSqr + ySqr) )
            vectorAngle = asin(Float((newPoint.y - startPoint!.y))/vectorLength )
            vectorCos = cos(vectorAngle)
            vectorSin = sin(vectorAngle)
            xDelta = Float(newPoint.x - startPoint!.x)
            if xDelta < 0.0 {
                xSign = -1.0 } // avoid NAN error from sign function if xDelta is zero
            } else  {
                xSign = 1.0
                    // startPoint = nil  ?? why is this !!
                }

            // reset the attributeValueDelta for the vectorLength
            // other classes use attributeValueDelta based on range of the slider
            // which does not apply here
            if (varyTotalFrames > 0 ) // check for zero division nan

            {
                attributeValueDelta = vectorLength / Float(varyTotalFrames)
            }
        }
    }
    var scaling: PGLVectorScaling?

    required init?(pglFilter: PGLSourceFilter, attributeDict: [String:Any], inputKey: String ) {
        super.init(pglFilter: pglFilter, attributeDict: attributeDict, inputKey: inputKey)
        if defaultValue == nil {

            var cornerPoint: CGPoint?
//            NSLog("PGLFilterAttributeVector does not have default")
            let insetRect = CGRect(x: 30, y: 30, width: TargetSize.width, height: TargetSize.height).insetBy(dx: 100.0, dy: 100.0)
            // assuming LLO here... Lower Left Origin coordinates
            switch attributeName {
                case "inputTopLeft":
                  cornerPoint = CGPoint(x: insetRect.origin.x, y: insetRect.maxY)  //LLO

                case "inputTopRight" :
                   cornerPoint = CGPoint(x: insetRect.maxX, y: insetRect.maxY)  //LLO

                case "inputBottomLeft":
                    cornerPoint = insetRect.origin //LLO

                case "inputBottomRight":
                    cornerPoint = CGPoint(x: insetRect.maxX, y: insetRect.origin.y) //LLO 

                default:
                    if !shouldSetDefaultVectorValue() {
                        // do not set cornerPoint default for PGLAttributeVectorExpand
                        // used by Tone Curve 
                        break
                    }
                    // set the cornerPoint to
                    // the midPoint offset of the insetRect

                    cornerPoint = CGPoint(x: insetRect.midX, y: insetRect.midY)
                        /// don't let multiple points land on top of each other
                    let adjustConstant = insetRect.height / 5.0
                    let offSet = adjustConstant * CGFloat(pglFilter.attributes.count)
                        // this assumes that this attibute has not been added yet
                        // so the count of the existing number of attributes can be the
                        // offset multiple
                    // adjust down and left from the center of the insetRect
                    cornerPoint?.x -= offSet
                    cornerPoint?.y -= offSet
//                    NSLog ("\( String(describing: self) + "-" + #function)" + " vector default is cornerPoint = \(cornerPoint)")

            }
            if cornerPoint != nil {
                aSourceFilter.setVectorValue(newValue: CIVector(cgPoint: cornerPoint!), keyName: attributeName!)
            }
        }


    }

    func shouldSetDefaultVectorValue() -> Bool {
        return true
    }

//MARK: Vary vector start end
    func setVectorEndPoint() {
        if startPoint != nil
           {endPoint = getVectorValue() }
    }
    func setVectorStartPoint(){
        startPoint = getVectorValue()
    }
    // Vary action on UI.. set the vector move start point

    func endVectorPan() {
        startPoint = nil
        endPoint = nil
    }

    func setRandomVectorEndPoint() {
        guard let startPoint = startPoint else { return }

        let startPointX = startPoint.x
        let startPointY = startPoint.y

        // Valid range is inset 20% from TargetSize edges
        let insetFraction: CGFloat = 0.2
        let minX = TargetSize.width * insetFraction
        let maxX = TargetSize.width * (1.0 - insetFraction)
        let minY = TargetSize.height * insetFraction
        let maxY = TargetSize.height * (1.0 - insetFraction)

        // Maximum change is 50% of the dimension from startPoint
        let maxChangeX = TargetSize.width * 0.5
        let maxChangeY = TargetSize.height * 0.5

        // Intersect both constraints to get safe bounds
        let lowerX = max(minX, startPointX - maxChangeX)
        let upperX = min(maxX, startPointX + maxChangeX)
        let lowerY = max(minY, startPointY - maxChangeY)
        let upperY = min(maxY, startPointY + maxChangeY)

        let newX: CGFloat = lowerX < upperX ? CGFloat.random(in: lowerX...upperX) : lowerX
        let newY: CGFloat = lowerY < upperY ? CGFloat.random(in: lowerY...upperY) : lowerY

//        NSLog("\(String(describing:self)) setRandomVectorEndPoint old value \(String(describing: endPoint))")

        endPoint = CIVector(x: newX, y: newY)
        varyStepCounter = 0 // reset for new endPoint

        NSLog("\(String(describing:self)) setRandomVectorEndPoint new value \(String(describing: endPoint))")
    }

    func setRandomVectorStartPoint() {
       // guard let startPoint = startPoint else { return }

//        let startPointX = startPoint.x
//        let startPointY = startPoint.y

        // Valid range is inset 20% from TargetSize edges
        let insetFraction: CGFloat = 0.2
        let minX = TargetSize.width * insetFraction
        let maxX = TargetSize.width * (1.0 - insetFraction)
        let minY = TargetSize.height * insetFraction
        let maxY = TargetSize.height * (1.0 - insetFraction)

        // Maximum change is 50% of the dimension from startPoint
//        let maxChangeX = TargetSize.width * 0.5
//        let maxChangeY = TargetSize.height * 0.5


        let newX: CGFloat =  CGFloat.random(in: minX...maxX)
        let newY: CGFloat =  CGFloat.random(in: minY...maxY)

//        NSLog("\(String(describing:self)) setRandomVectorEndPoint old value \(String(describing: endPoint))")

        startPoint = CIVector(x: newX, y: newY)
        varyStepCounter = 0 // reset for new startPoint

        NSLog("\(String(describing:self)) setRandomVectorStartPoint new value \(String(describing: startPoint))")
    }

 // MARK: set
    override func set(_ value: Any) {
        if attributeName != nil {
            if let newVectorValue = value as? CIVector {
                parmInputState = .inputValueSet
                aSourceFilter.setVectorValue(newValue: newVectorValue, keyName: attributeName!) }
        }
    }

    override func resizeFrom(savedSize: CGSize?) {
        // assumes setStoredValueToAttribute has created the vector and set into the filter
        if !moveOnDrawableSizeChange() {
            // not a vector that should move..
            return
        }
        if savedSize != nil {
            let resizingTransform = resizeStoredTransform(savedSize)
            let filterVector = getVectorValue()?.applying(resizingTransform)
            if filterVector != nil {
                aSourceFilter.setVectorValue(newValue: filterVector!, keyName: attributeName!)
            }
            if startPoint != nil {
                startPoint = startPoint!.applying(resizingTransform)
            }
            if endPoint != nil {
                endPoint = endPoint!.applying(resizingTransform)
            }
        }
    }


    override func performActionOff() {
        super.performActionOff()
        endVectorPan()
        attributeValueDelta = nil
            // stops animation

         varyState = .Initial
    }

    override  func setUICellDescription(_ uiCell: UITableViewCell) {
      var content = uiCell.defaultContentConfiguration()
      let newDescriptionString = self.attributeDisplayName ?? ""
      content.text = newDescriptionString
      content.imageProperties.tintColor = .secondaryLabel
        content.image = UIImage(systemName: "plus.circle")

      uiCell.contentConfiguration = content

    }

    // MARK: Swipe actions Vector
    fileprivate func addCancelAction(_ allActions: inout [PGLTableCellAction]) {
        // point 1 &/or point 2 set so allow Cancel
        let cancelVaryAction = PGLTableCellAction(action: "Cancel", newAttribute: nil, canPerformAction: true, targetAttribute: self)
        allActions.append(cancelVaryAction)

    }

    override  func addAnimationStepTime() {
        // called on every frame
        // if animationTime is nil then animation is not running
        // adds the delta value (currentDt) to the parm

        if !hasAnimation() { return }  // animationTime is Float

        if (varyStepCounter > varyTotalFrames) {
            // || (varyStepCounter < 0) {
            // the (varyStepCounter < 0) is the wrong condition
            // where is the varyStepCounter going to -1 ?
            // because varyTotalFrames is zero

            // attributeValueDelta is not used for the vector increment
            incrementDirection = incrementDirection * -1
            NSLog("\(String(describing:self)) addAnimationStepTime incrementDirection flipped \(String(describing: incrementDirection))")
            NSLog("varyStepCounter \(String(describing: varyStepCounter))")
            NSLog("varyTotalFrames \(String(describing: varyTotalFrames))")

            if incrementDirection >= 0 {
                // on the start point switch
                NSLog("\(String(describing:self)) PGLFilterAttributeVector set endPoint")
                setRandomVectorEndPoint()
            }
            if attributeValueDelta != nil
                { attributeValueDelta = attributeValueDelta! * -1 }
        }
        // now add the step
        varyStepCounter += incrementDirection
            // variationSteo not nil see hasAnimation() guard above
        incrementValueDelta()
    }

    override func incrementValueDelta() {
        // animation time range 0.0 to 1.0
        if !hasAnimation() {return }

        if (endPoint != nil)  && (startPoint != nil ){
//            let currentPoint = getVectorValue()
            // old animationTime is a value moving from -1 to +1
            let changeRatio: Float = Float(varyStepCounter) / Float(varyTotalFrames)
            let distanceOfIncrement = vectorLength * changeRatio


            let newX = Float(startPoint!.x) + (xSign * (vectorCos * distanceOfIncrement))
            let newY = Float(startPoint!.y) + (vectorSin * distanceOfIncrement)
            let newVector = CIVector(x: CGFloat(newX), y: CGFloat(newY))
//            NSLog("PGLFilterAttributeVector #incrementValueDelta currentVector = \(String(describing: getVectorValue()))")
//            NSLog("PGLFilterAttributeVector #incrementValueDelta \(attributeName) newVector = \(newVector)")
            set(newVector)

            postUIChange(attribute: self)
        }

    }
    override func setAnimationTimerDt(lengthSeconds: Float){
         // user has moved the rate of change control
         // value is 0...30
         // real step timing varies from min to max  from 0 sec to 30 sec
         // see #addStepTime() in #outputImage()
         // set the variationStep value
         // set the attributeValueDelta for change in each stop

         if vectorLength <=  0 { return } // end point for vectorlength must be set first

         let framesPerSec: Float = 60.0 // later read actual framerate from UI
         varyTotalFrames = Int(framesPerSec * lengthSeconds)


     }
   

    override func cellAction() -> [PGLTableCellAction] {

        return super.cellAction()
    }

    override  func performAction(_ controller: PGLSelectParmController?) {

        switch varyState {
            case .Initial:
                    setVectorStartPoint()
                    setRandomVectorEndPoint()
                varyState = .VaryPt1Pt2 // move to next state for both from and to points set
                aSourceFilter.startAnimation(attributeTarget: self)
//                NSLog("PGLFilterAttributeVector varyState .Initial")

            case .VaryPt1:
                // not used with the setRandomEndPoint
//                NSLog("PGLFilterAttributeVector varyState .VaryPt1")
                varyState = .Initial
            case .VaryPt1Pt2:
//                NSLog("PGLFilterAttributeVector varyState .VaryPt1Pt2")
                aSourceFilter.stopAnimation(attributeTarget: self)
                 varyState = .Initial

            case .DissolveWrapper:
                removeWrapperFilter()
                varyState = .Initial
        }

    }

    override func performAction2(_ controller: PGLSelectParmController?) {

        // a new subUI cell was not added by the actionCells method
//        setVectorEndPoint()
        if varyState == .VaryPt1 {
            varyState = .VaryPt1Pt2 // move to next state for both from and to points set
            // set UI vary values
            setAnimationTimerDt(lengthSeconds: 5.0)

        }
    }

    func removeWrapperFilter() {
        aSourceFilter.removeWrapperFilter()
    }

// MARK: Vector Scaling
    override func moveOnDrawableSizeChange() -> Bool {
        // only some PGLFilterAttributeVectors should move
        return true
    }

    func scaleVector(inputVector: CIVector, scaleBy: CGAffineTransform, invertScale: Bool) -> CIVector {
        var vectorFactor: CGAffineTransform!
        let newVectorPoint = inputVector.cgPointValue
//        NSLog(#function + "invertScale: \(invertScale) : newVectorPoint: \(newVectorPoint)")
        if invertScale {
            vectorFactor = scaleBy.inverted()
            // divide to smaller
        } else {
            vectorFactor = scaleBy
                // multiply to larger
        }
        let scaledPoint = newVectorPoint.applying(vectorFactor)
//        NSLog(#function + "scaledPoint: \(scaledPoint) ")
        let scaledVectorValue = CIVector.init(cgPoint: scaledPoint)
        return scaledVectorValue
    }

    override  func setScaling(heightScreenScale: PGLVectorScaling) {
        scaling = heightScreenScale
    }

    override func getScaling() -> PGLVectorScaling? {
        return scaling
    }


}
