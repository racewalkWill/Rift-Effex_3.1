//
//  PGLFilterAttribute.swift
//  PictureGlance
//
//  Created by Will on 8/19/17.
//  Copyright © 2017 Will Loew-Blosser All rights reserved.
//

import Foundation
import UIKit
import Photos
import CoreImage
import Accelerate
import os
import Combine


enum AttrClass: String {
    case Color = "CIColor"
    case Number = "NSNumber"
    case Vector = "CIVector"
    case Image = "CIImage"
    case Data =  "NSData"
    case Value = "NSValue"
    case Object = "NSObject"
    case String = "NSString"
    case AttributedString = "NSAttributedString"
}

enum AttrType: String {
    case Rectangle = "CIAttributeTypeRectangle"
    case Image = "CIAttributeTypeImage"
    case Scalar = "CIAttributeTypeScalar"
    case Position = "CIAttributeTypePosition"
    case Distance = "CIAttributeTypeDistance"
    case Angle = "CIAttributeTypeAngle"
    case Color = "CIAttributeTypeColor"
    case Time = "CIAttributeTypeTime"
    case Offset = "CIAttributeTypeOffset"
    case OpaqueColor =  "CIAttributeTypeOpaqueColor"
    case Position3 = "CIAttributeTypePosition3"
    case TypeCount = "CIAttributeTypeCount"
    case Transform = "CIAttributeTypeTransform"
    case Boolean = "CIAttributeTypeBoolean"
    case Gradient = "CIAttributeTypeGradient"

}

enum AttrUIType {

    case pointUI
    case rectUI
    case sliderUI
    case imagePickUI
    case filterPickUI
    case integerUI
    case timerSliderUI
    case textInputUI
    case fontUI

}

enum VaryDissolveState {
    // state1 - Initial - actions are 'From' point 1 or run DissolveWrapper on 'Faces' points
    // state2 - VaryPt1 point1 is set - actions are 'To' point 2 & 'Cancel' back to state1
    // state3 - VaryPt1Pt2 point1 & point2 set - animation is running. action is 'Cancel' back to state1
    // state4 - DissolveWrapper is running - 'Cancel' back to state 1
    case Initial
    case VaryPt1
    case VaryPt1Pt2
    case DissolveWrapper
}

@MainActor
class PGLFilterAttribute {

    static let FlowChartSymbol = UIImage(systemName: "point.bottomleft.forward.to.arrowtriangle.uturn.scurvepath")
            //"flowchart")
    static let PhotoSymbol = UIImage(systemName: "photo.on.rectangle")
    static let PhotoSymbolSingle = UIImage(systemName: "photo")
    
//    static let PriorFilterSymbol = UIImage(systemName: "square.and.arrow.down.on.square")
    static let PriorFilterSymbol = UIImage(systemName:"chevron.down.square")

    static let MissingPhotoInput = UIImage(systemName: "rectangle") // looks empty...
    static let CurrentStackSymbol = UIImage(systemName: "square.stack.3d.up.fill")

//    static let ChildStackSymbol = UIImage(systemName: "bubble.middle.bottom")
    static let ChildStackSymbol = UIImage(systemName:"square.3.layers.3d.down.forward")
    
    static let ParentStackSymbol = UIImage(systemName: "arrow.down.doc")
    static let TopStackSymbol = UIImage(systemName: "square.stack.3d.up")
    static let SequenceSymbol = UIImage(systemName: "rectangle.portrait.arrowtriangle.2.outward")
    static let SequenceSymbolFilled = UIImage(systemName: "rectangle.portrait.on.rectangle.portrait.fill")

    // version 3.2 child stack levels
    static let ChildStack1Symbol = UIImage(systemName: "square.2.layers.3d")
    // was  "square.and.arrow.down"
    
    static let ChildStack2Symbol = UIImage(systemName: "square.2.layers.3d.bottom.filled")
    static let ChildStack3Symbol = UIImage(systemName: "square.3.layers.3d.bottom.filled")
    static let ChildStack4Symbol = UIImage(systemName: "square.stack" )
    static let ChildStack5Symbol = UIImage(systemName: "square.on.square.squareshape.controlhandle")
    static let CropSymbool = UIImage(systemName: "crop")
    static let OutputFilterSymbol = UIImage(systemName: "photo.badge.checkmark.fill")


                                           // arrow.down.doc
            // or
                //    doc.plaintext
                //    Arrow.up.doc
                //    Arrow.down.doc
                //    Bubble.middle.top
                //    Sidebar.squares.leading
                //    Square.stack.3d.up
                //    List.bullet.indent

   @objc var myFilter: CIFilter {
        didSet {
             self.aSourceFilter.localFilter = myFilter // keep the two refs to the filter aligned
        }
    }
    var attributeName: String?
    var attributeDisplayName: String?
    var attributeType: String?
    var attributeClass: String?
    var classForAttribute: AnyClass?
    var attributeDescription: String?
    var minValue: Float?
    var sliderMinValue: Float?
    var sliderMaxValue: Float?
    var defaultValue: Float?
    var identityValue: Float?
//    var attributeStartValue: Float!
    var attributeValueDelta: Float? // usually nil, when nil parent filter timer controls the rate of change
//    var attributeFrameDelta: Float = 0.0
    var varyStepCounter = 0
    var varyTotalFrames = 600 // 10 secs @ 60 fps
    var storedParmValue: CDParmValue?


    var uiIndexPath: IndexPath?

    var initDict = [String:Any]()

    var inputCollection: PGLImageList? {
    // more general either ImageList or FilterList  why not incrment a set of filters too?
        didSet {
            if oldValue != nil {
                oldValue?.releaseVars()

            }
        }
    }


     unowned var aSourceFilter: PGLSourceFilter
    // This holds the real ciFilter in via the var PGLSourceFilter.localFilter
    // but attribute also holds the real ciFilter in myFilter var

    //    var keyPathString = \PGLFilterAttribute.myFilter.inputSaturation
    //    ReferenceWritableKeyPath<PGLFilterAttribute, Any>
    // add attributeMin, Max and Identity? They are strings in the dict.. need conversion to floating Point

    var isTransitionFilter = false  // cache at init time aSourceFilter is unowned var.

    var inputSourceMetadata: PGLAsset? // photo or filter name used as input data store

    var inputStack: PGLFilterStack? {
        didSet{
            // assign the output of the child to the input of this attribute
            if inputStack != nil {
                self.set( inputStack?.stackOutputImage(false) as Any)
                    // false means use the final image in the child stack... BUT
                    // the child is being created so it is the dynamic output at runtime that is the input
                    // to this attribute.
                    // this is a problem...

                inputSourceDescription = inputStack?.stackName ?? "filterStack"
            }
        }
    }
        // typically an image output from a stack is the input to the attribute

    var inputSource: (source: PGLFilterStack, at: Int)?  // usually the filter that feeds to this input

    var inputSourceDescription: String? // inputCollection or childStack or.... shows on the title of the parm cell

        // really should only be a var on the subclass PGLFilterAttributeImage..
        // but assignment methods are in this superclass


    var indentLevel = 0
    var indentWidth: CGFloat = 30.0

    // default rate is .005 
//    let timeRateMininium: Double = 0.00001 // not used 2020-11-22  Remove
    var uiIndexTag:Int = 0 // used by color and maybe others?
    var varyState: VaryDissolveState = .Initial
    var hasFilterInput: Bool?
        // flag for parm description
        // nil before any input is set by the UI
        // PGLUserAssetSelection sets to false when images are selected
        // PGLFilterStack sets to true when filter input is set

    var parmInputState = ParmInputState.valueParmNotSet

  required init?(pglFilter: PGLSourceFilter, attributeDict: [String:Any], inputKey: String ) {
        initDict = attributeDict // save for creating valueParms such as PGLRotateAffineUI
        myFilter = pglFilter.localFilter
        aSourceFilter = pglFilter  // unowned var that may be deferenced..
        attributeType = attributeDict[kCIAttributeType] as? String
        attributeClass = attributeDict[kCIAttributeClass] as? String
        attributeDisplayName = attributeDict[kCIAttributeDisplayName] as? String
        attributeDescription = attributeDict[kCIAttributeDescription] as? String
        attributeName = inputKey
        minValue = attributeDict[kCIAttributeMin] as? Float
        sliderMinValue = attributeDict[kCIAttributeSliderMin] as? Float
        sliderMaxValue = attributeDict[kCIAttributeSliderMax] as? Float
        defaultValue = attributeDict[kCIAttributeDefault] as? Float // this fails for affineTransform
        identityValue = attributeDict[kCIAttributeIdentity] as? Float // this fails for affineTransform

        isTransitionFilter = pglFilter.isTransitionCategoryFilter()
            // // cache at init time aSourceFilter is unowned var and may  be dereferenced

        if attributeClass != nil {
            classForAttribute = NSClassFromString(("RiftEffects." + attributeClass!)) }
    
//        inputSourceDescription = attributeDisplayName ?? "blank"

//        keyPathString = \self.class + "." + "myFilter" + "." + attributeName
        }

    func releaseVars() {
        inputCollection?.releaseVars()
        inputCollection = nil 
        inputStack = nil


    }

//    deinit {
//        Logger(subsystem: LogSubsystem, category: LogMemoryRelease).info("\( String(describing: self) + " - deinit" )")
//    }

    func movingCorner(atCorner: Vertex, startPoint: CGPoint, newPoint: CGPoint) {
           // implemented by rectangle subclass
       }

       // maybe subclassed if a attribute needs some special logic
       // knows the name of the attribute, the class and the type
       // hold ref to the filter, gets and sets the attribute values into the filter
       // this is the data object for a table cell row of filter attributes
       // PGLSourceFilter holds these.. subclass of  PGLSourceFilter if filter specific logic needed across multiple attributes
       // i.e. if constraints exist between attributes the PGLSourceFilter implements the filter as a subclass

       class func parmClass(parmDict: [String : Any ]) -> PGLFilterAttribute.Type {
           // based upon the attribute kCIAttributeClass value use this class
           // provides creation of correct subclass for the attribute

           let attributeTypeString = parmDict[kCIAttributeType] as? String
           let parmClassString = parmDict[kCIAttributeClass] as? String

           if parmClassString != nil {
                // many filter attributes do not have a value for the class string.. be careful with nil check!
               switch parmClassString!{
                   case AttrClass.Color.rawValue:
                       return PGLFilterAttributeColor.self

                   case  AttrClass.Number.rawValue :
                       switch attributeTypeString {
                           case AttrType.Angle.rawValue:
                               return PGLFilterAttributeAngle.self
                           case AttrType.Time.rawValue:
                               return PGLFilterAttributeTime.self
                           default:
                               return PGLFilterAttributeNumber.self
                       }

                   case AttrClass.Vector.rawValue  :
                       switch attributeTypeString {
                           case AttrType.Rectangle.rawValue:
                               return PGLAttributeRectangle.self
                       case AttrType.Position3.rawValue:
                               return PGLFilterAttributeVector3.self
                       default: return PGLFilterAttributeVector.self
                       }

                   case AttrClass.Image.rawValue :
                       if attributeTypeString == kPChildSequenceStack {
                           return PGLFilterAttrSequenceStack.self
                       } else {
                           return PGLFilterAttributeImage.self }

                  case  AttrClass.Data.rawValue  :
                        return PGLFilterAttributeData.self

                   case AttrClass.Value.rawValue  :
                       if attributeTypeString == AttrType.Transform.rawValue
                           {  return PGLFilterAttributeAffine.self }
                       else { return PGLFilterAttribute.self }

                   case AttrClass.Object.rawValue  :
                       return PGLFilterAttribute.self

                   case  AttrClass.String.rawValue :
                       return PGLFilterAttributeString.self

                case AttrClass.AttributedString.rawValue :
                    return PGLFilterAttributeAttributedString.self

                   default: return PGLFilterAttribute.self
               }
           } else {return PGLFilterAttribute.self}
       }


    func postUIChange(attribute: PGLFilterAttribute) {
        let uiNotification = Notification(name:PGLAttributeAnimationChange, object: attribute,userInfo: nil)

        NotificationCenter.default.post(uiNotification)
    }

    func parentParmFilterName() -> String {
        // answer name of the parent stack parm and filter
        return  (aSourceFilter.descriptorDisplayName ?? "filter") +  ">" + (attributeDisplayName ?? "parm") 
    }

    func setUICellDescription(_ uiCell: UITableViewCell) {
        uiCell.textLabel?.text = attributeDisplayName ?? ""

        if let cellSlider = uiCell as?  PGLTableCellSlider {
            cellSlider.showTextValueInCell()
        }
        else {
//            NSLog("PGLFilterAttribute #setUICellDescription \(uiCell.textLabel!.text)")
            uiCell.detailTextLabel?.text = valueString()
//            NSLog("PGLFilterAttribute #setUICellDescription detailTextLabel.text = \(uiCell.detailTextLabel?.text)")
        }
        uiCell.indentationLevel = indentLevel  // subclasses such as timer will indent parm
    }

    func descriptiveNameDetail() -> String {
        return (attributeDisplayName ?? "parm" ) //  + " " + (attributeDescription ?? "")
    }

    // MARK: image Collection input

    func setImageCollectionInput(cycleStack: PGLImageList) {
        let firstAsset = cycleStack.imageAssets.first
        setImageCollectionInput(cycleStack: cycleStack, firstAssetData: firstAsset)
        
    }

    
    func postListSizeChange( newList: PGLImageList) {
        guard let myCurrentList = inputCollection
        else { if newList.isMultiple()  {
                    postTransitionFilterAdd()   }
                return }
        if myCurrentList.isMultiple() && newList.isMultiple() {
            return // no change
        }
        if !myCurrentList.isMultiple() && newList.isMultiple() {
                // change notice
            postTransitionFilterAdd()
            return
        }
        if myCurrentList.isMultiple() && !newList.isMultiple() {
            postTransitionFilterRemove()
            return
        }
        if !myCurrentList.isMultiple() && !newList.isMultiple() {
            postTransitionFilterRemove()
            return
        }
    }

    func removeTransitionCounts() {
        // if filter is removed then remove its transition counts
        guard let myCurrentList = inputCollection
            else { return }
        if myCurrentList.isMultiple() {
            postTransitionFilterRemove()
        }
    }

    func addTransitionCounts() {
        // if filter is added then post its transition increment
        guard let myCurrentList = inputCollection
            else { return }
        if myCurrentList.isMultiple() {
            postTransitionFilterAdd()
        }
    }

    func postTransitionFilterAdd() {
        let updateNotification = Notification(name:PGLTransitionExists)
        NotificationCenter.default.post(name: updateNotification.name, object: nil, userInfo: ["transitionFilterAdd" : +1 ])
    }

    func postTransitionFilterRemove() {
        let updateNotification = Notification(name:PGLTransitionExists)
        NotificationCenter.default.post(name: updateNotification.name, object: nil, userInfo: ["transitionFilterAdd" : -1 ])
    }

    func setImageCollectionInput(cycleStack: PGLImageList, firstAssetData: PGLAsset?) {
        inputCollection = cycleStack
        inputSourceMetadata = firstAssetData  // provides description titles - optional

        inputCollection?.inputStack = inputStack // keep these aligned
        inputSourceDescription = cycleStack.collectionTitle
        guard let myAttributeName = attributeName else
        { setImageParmState(newState: ParmInputState.missingImageInput)
            return
        }

        // MARK: to do
        // aSourceFilter is unowned var..
        // guard for early deallocation

        aSourceFilter.setImageValuesAndClone(inputList: cycleStack, attributeName: myAttributeName )

        if cycleStack.isEmpty() {
            setImageParmState(newState: ParmInputState.missingImageInput)
        } else {
            setImageParmState(newState: ParmInputState.inputPhoto) }
// also state of
//        ImageParm.inputChildStack
//        ImageParm.inputPriorFilter

        _ = aSourceFilter.notifyTransitionsExist()
        aSourceFilter.postImageChange()
    }

    func setTargetAttributeOfUserAssetCollection() {
        // if an inputCollection has a userAssetCollection
        // set it's targetFilterAttribute to self
        inputCollection?.userSelection?.myTargetFilterAttribute = self
    }

    func updateFromInputStack() {
        // if there is a child stack then get the current output as the input to this attribute
        if inputStack != nil {
            self.set( inputStack?.stackOutputImage(false) as Any)
        }
    }

    func setImageParmState(newState: ParmInputState) {
        // empty implementation in the superclass
        // see PGLFilterAttributeImage

    }

// MARK: flattened Filters
    func stackRowCount() -> Int {
       return inputStack?.stackRowCount() ?? 0
    }

    func addChildFilters(_ level: Int, into: inout Array<PGLFilterIndent>) {
       inputStack?.addChildFilters(level  , into: &into)
    }

    // MARK: description
    var description: String {
        get {
            var outputString =  "attributeName= " + String(describing: attributeName)
            outputString = outputString + " attributeDisplayName= " + String(describing: attributeDisplayName)

            outputString = outputString + " attributeType=" + String(describing: attributeType)
            outputString = outputString + " attributeClass= " + String(describing:  attributeClass)
            outputString = outputString + " classForAttribute= " + String(describing:  classForAttribute)
            outputString = outputString + " attributeDescription= " + String(describing:  attributeDescription)
            outputString = outputString + " minValue= " + String(describing:  minValue)
            outputString = outputString + " sliderMinValue= " + String(describing: sliderMinValue)
            outputString = outputString + " sliderMaxValue= " + String(describing: sliderMaxValue)
            outputString = outputString + " defaultValue= " + String(describing: defaultValue)
            outputString = outputString + " identityValue= " + String(describing: identityValue)
            return outputString
        }
    }

    func uiCellIdentifier() -> String {

        return  "parmNoDetailCell"
    }

    func getSourceDescription(imageType: ParmInputState) -> String {
        return inputSourceDescription ?? ""

    }

    func hasImageInput() -> Bool? {
        // super class this is not defined
        // only imageAttribute should answer true/false
        return nil
    }

    /// only PGLFilterAttributeImage has video input
    func videoInputExists() -> Bool {
        // subclass PGLFilterAttributeImage implements
        return false
    }

    func inputParmType() -> ParmInputState {
        // superclass default
        // see PGLFilterAttributeImage
        return parmInputState
    }

    func isMissingInput() -> Bool {
        switch parmInputState {
            case .valueParmNotSet , .missingImageInput:
                return true
            default:
                return false
        }

    }

    func getInputThumbnail(dimension: CGFloat = 200.0 ) -> UIImage{
        if hasFilterStackInput() || isImageInput() {
            if  let ciInput = getImageValue() {
                return ciInput.thumbnailUIImage(dimension)

                }
        }
        return UIImage()
    }

    func hasFilterStackInput() -> Bool {
        return inputStack != nil

    }

    func valueString() -> String {
        // subclasses such as number will restrict the number of decimial places
        return String(describing: (getValue() ?? "") )
    }

        // MARK: Filter Updates

        /// some parms based on center points need to change if the image sizng changes
        ///  does not change non position vector parms (such as color vectors)
    func moveOnDrawableSizeChange() -> Bool {
        // only some PGLFilterAttributeVectors should move
        return false
    }
    // MARK: value change
    func set(_ value: Any ) {
        // use a system of double dispatch to address typing
        //
        parmInputState = .inputValueSet
        if attributeName != nil, attributeClass != nil {

            switch attributeClass! {
                //  moved to subclass ..Image               case  AttrClass.Image.rawValue : aSourceFilter.setImageValue(newValue: value as! CIImage, keyName: attributeName!)
                //                case  AttrClass.Number.rawValue : aSourceFilter.setNumberValue(newValue: value as! NSNumber, keyName: attributeName!)
                // Number case usually in subclass PGLFilterAttributeNumber method

            case AttrClass.Vector.rawValue :
                if let newVector = value as? CIVector {
                    aSourceFilter.setVectorValue(newValue: newVector, keyName: attributeName!)}
                // vector case usually in subclass PGLFilterAttributeVector but Flash uses rectangle extent
            //                case AttrClass.Color.rawValue : aSourceFilter.setColorValue(newValue: value as! CIColor, keyName: attributeName!)
            case  AttrClass.Data.rawValue :
                if let data = value as? NSData {
                    aSourceFilter.setDataValue(newValue: data, keyName: attributeName!) }

            case  AttrClass.Value.rawValue :
                if let myValue = value as? NSValue {
                    aSourceFilter.setNSValue(newValue: myValue, keyName: attributeName!) }

            case  AttrClass.Object.rawValue :
                if let myObject = value as? NSObject {
                    aSourceFilter.setObjectValue(newValue: myObject, keyName: attributeName!) }

            case  AttrClass.String.rawValue :
                if let myString = value as? NSString {
                    aSourceFilter.setStringValue(newValue: myString, keyName: attributeName!) }

            default: Logger(subsystem: LogSubsystem, category: LogCategory).fault("Error- can not set value for unknown filter attribute class in \(String(describing: self.attributeName))")
                // raises error on a new attribute class
            }
        }
    }

    func getValue() -> Any? {
    // use a system of double dispatch to address typing?
        
    // return myFilter.value(forKey: attributeName!) as!
    // this is interesting .. the return type matters in Swift.. I was thinking smalltalk..
    // for a generic getValue setValue we actually need subclasses of this class
    // required subclass implementation with different return types..
    // think about this
    var generic: Any? = nil
    if attributeName != nil {
         generic = myFilter.value(forKey: attributeName!)
        }
//        NSLog("PGLFilterAttribute #getValue generic = \(generic)")
    return generic
    }
    
    func getImageValue() -> CIImage? {
        return getValue() as? CIImage
    }
    
    func getNumberValue() -> NSNumber? {
        let filterValue =  getValue() as? NSNumber
//        NSLog("PGLFilterAttribute #getValue filterValue = \(filterValue)")
       return filterValue

    }
    
    func getVectorValue() -> CIVector? {
        return getValue() as? CIVector
    }
    
    func getColorValue() -> CIColor? {
        return getValue() as? CIColor
    }
    
    func getDataValue() -> NSData? {
        return getValue() as? NSData
    }
    
    func getNSValue() -> NSValue? {
        return getValue() as? NSValue
    }
    func getObjectValue() -> NSObject? {
        return getValue() as? NSObject
    }
    func getStringValue() -> NSString? {
        return getValue() as? NSString
    }
  
    func isImageInput() -> Bool {
        return (attributeClass == "CIImage") || (attributeType == kCIAttributeTypeImage)
    }
    
    func isBackgroundImageInput() -> Bool {
       return (attributeType == kCIAttributeTypeImage) && (attributeName == kCIInputBackgroundImageKey)
      
    }

    func isMaskImageInput() -> Bool {
       return (attributeType == kCIAttributeTypeImage) && (attributeName == kCIInputMaskImageKey)

    }

    func isTimeTransition() -> Bool {
        // answer true if the attribute is for input time of a transition such as Dissolve
        return (attributeType == kCIAttributeTypeTime)
    }

    func mapPoint2Vector(point: CGPoint, viewHeight: CGFloat, scale: CGFloat) -> CIVector {
        // Upper Left Origin coord ULO point
        // vector in Lower Left coord  LLO

        let flippedVertical = viewHeight - point.y
            // is this the inverse func for vector2Point??
        let newVector = CIVector(x: point.x * scale , y: flippedVertical * scale )
        return newVector
    }

    func mapVector2Point(vector: CIVector, viewHeight: CGFloat, scale: CGFloat) -> CGPoint {
        // set the scaling vars
        let theScreenScaling = PGLVectorScaling(viewHeight: viewHeight, viewScale:  scale)
        setScaling(heightScreenScale: theScreenScaling)
        if vector ==  CIVector.init(x: 0.0, y: 0.0) {
            let offsetVector = CIVector(x: 0.0, y: 100.0)
            return mapVector2PointScaled(vector: offsetVector)
        } else {
            return mapVector2PointScaled(vector: vector)
        }
    }

    /// map the vector to view height and screen scale
    /// assumes scaling var has been set during creation
    func mapVector2PointScaled(vector: CIVector) -> CGPoint {
            // Upper Left Origin coord ULO point
            // vector in Lower Left coord  LLO
        if let theScale = getScaling() {
            let yPoint = ((vector.y / theScale.viewScale) - theScale.viewHeight) * -1.0
                // UNDO the flip from ULO to LLO
            let newPoint = CGPoint(x: (vector.x/theScale.viewScale) , y: yPoint)
            return newPoint
        }
        else { 
            // no mapping just answer the same point
            return vector.cgPointValue}
    }

        /// set view.height and screen scale for mapping vectors
    func setScaling(heightScreenScale: PGLVectorScaling) {
        // empty implemenation
        // see PGLFilterAttributeVectorUI
    }

    func getScaling() -> PGLVectorScaling? {
            // empty implemenation
            // see PGLFilterAttributeVectorUI
       return nil
   }
        ///  always display the position control view
        /// PGLFilterVectorAttributeVectorUI and PGLGradientVectorAttribute only shows if selected
    func shouldHidePosition(userSelected: Bool) -> Bool {
            // does not matter if the user selected this attribute
            // always show -
            // do not hide returns false
            return false
        }

    func okActionToSetValue() -> Bool {
        // subclass override to true if set value is deferred to the OK action of the parm cell
        return false
    }

    // MARK: Size changes
    /// apply size changes to the point parms so they appear in the same spot
    func movePointParms(transform: CGAffineTransform) {
//        NSLog(description)
        if moveOnDrawableSizeChange() {
            if let currentValue = getVectorValue() {
//               NSLog ("#movePointParms transform = \(transform)")
                let theValuePoint = currentValue.cgPointValue
                let newPoint = theValuePoint.applying(transform)
                let newVector = CIVector(cgPoint: newPoint)
//                Logger(subsystem: LogSubsystem, category: LogCategory).info ( "#movePointParms oldVector = \(currentValue)  newVector = \(newVector)")

                set(newVector)
                // PGLFilterAttributeVector3 or PGLFilterAttributeVector
                // will set correctly with either x,y,z vector or an x,y vector

            }
        }
    }

    /// saved on different coordinate TargetSize
    ///  map points to current Target size
    ///  ONLY used on read from dataStore
    func resizeFrom(savedSize: CGSize?) {
        // abstract superclass
        // only attribute parms with points need to implement
        // implementors will apply the #resizeStoredTransform(savedSize) to attribute values


    }

    // MARK: animation values

    func hasAnimation() -> Bool {
        return attributeValueDelta  != nil
    }

    func addAnimationStepTime() {
        // called on every frame
        // if animationTime is nil then animation is not running
        // adds the delta value (currentDt) to the parm

        if !hasAnimation() { return }  // animationTime is Float


        // adjust animationTime by the current dt
        if (varyStepCounter > varyTotalFrames)  {
//            NSLog("PGLFilterAttribute addStepTime resetting from varyStepCounter = \(varyStepCounter)")
            varyStepCounter = 0

            if attributeValueDelta != nil
                { attributeValueDelta = attributeValueDelta! * -1 }
            }
        // now add the step

        varyStepCounter += 1
            // variationSteo not nil see hasAnimation() guard above
        incrementValueDelta()


    }
    

    func setAnimationTimerDt(lengthSeconds: Float){
        // user has moved the rate of change control
        // value is 0...30
        // real step timing varies from min to max  from 0 sec to 30 sec
        // see #addStepTime() in #outputImage()
        // set the variationStep value
        // set the attributeValueDelta for change in each stop
        let framesPerSec: Float = 60.0 // later read actual framerate from UI
        varyTotalFrames = Int(framesPerSec * lengthSeconds)

        let attributeValueRange = (sliderMaxValue ?? 100.0) - (sliderMinValue ?? 0.0)
            // some filters do not define max or min values..

            // for total frames to increment to value
        if (varyTotalFrames > 0 ) // check for zero division nan
        {
            attributeValueDelta = attributeValueRange / Float(varyTotalFrames)
            // hasAnimation is now true with value in attributeValueDelta
        }
        else { attributeValueDelta = 0.0
                // keeps animation logic going but no changes in the attribute values
        }

        Logger(subsystem: LogSubsystem, category: LogCategory).notice( "#setTimerDT attributeValueDelta = \(String(describing: self.attributeValueDelta))")
    }


    func getTimerDt() -> Float {
        return attributeValueDelta ?? 0.0
    }

    func incrementValueDelta() {
        // subclasses should override
        // see PGLFilterAttributeNumber for the numeric vary rate
    }
    func hasInputCollection() -> Bool {
        // more than one input image exists
        if let theSize = inputCollection?.maxAssetsOrImagesCount() {
            return theSize > 1
        }
        return false
    }

//    func hasUserAssetSelection() -> Bool {
//        if !hasInputCollection() { return false}
//        if (inputCollection?.userSelection) != nil {
//            return true
//        }
//        else {return false}
//    }

    func getUserAssetSelection() -> PGLUserAssetSelection? {

            return inputCollection?.userSelection

    }



    func isSingluar() -> Bool {

        if hasInputCollection()
            // this answers false if only one image in the collection
            { return inputCollection!.isSingular()}
        else { return false }
    }

    func hasOnePhoto() -> Bool {
        if let myList = inputCollection {
             return myList.isSingular()}
        else { return false }
    }

    func setToIncrementEach() {
        if let myInput = inputCollection {
            // may not have an input collection
            myInput.nextType = NextElement.each
        }

    }

    func increment() {
        if attributeClass == nil {
            return
        }
        switch attributeClass! {
            case  AttrClass.Image.rawValue :
                if hasInputCollection() {
                    if let nextImage = inputCollection!.increment() {

                        aSourceFilter.setImageValue(newValue: nextImage, keyName: attributeName!)
                        }
                    }
            case  AttrClass.Number.rawValue : if let numberValue = self.getNumberValue() {
                        let newValue = numberValue.doubleValue + 1.0
                        self.set(newValue) }

            case AttrClass.Vector.rawValue :  if let vectorValue = self.getVectorValue() {
                       let newVector = CIVector(x: vectorValue.x + 1.0, y: vectorValue.y + 1.0)
                       self.set(newVector)
                    }

            case AttrClass.Color.rawValue : if let colorValue = self.getColorValue() {
                       let newColor = CIColor(red: colorValue.red + 0.1 , green: colorValue.green + 0.1, blue: colorValue.blue + 0.1)
                       self.set(newColor)
                        }
            case  AttrClass.Data.rawValue :   if let dataValue = getDataValue() {
                            set(dataValue as Any)  // increment semenatics do not work for a data object
    //                NSLog("PGLFilterAttribute increment on NSData ")
                    }
            case  AttrClass.Value.rawValue :  if let aNSValue = getNSValue() {
                            set(aNSValue as Any) // increment semenatics do not work for a data object
    //                NSLog("PGLFilterAttribute increment on NSValue ")
                }
            case  AttrClass.Object.rawValue :  if let objectValue = getObjectValue() {
                    set(objectValue as Any) }
            case  AttrClass.String.rawValue :  if let stringValue = getStringValue() {
                    set(stringValue as String + "increment") }

            default: Logger(subsystem: LogSubsystem, category: LogCategory).fault("new attribute class")
            }
    }

    // MARK: child attributes
    func valueInterface() -> [PGLFilterAttribute] {
        // subclasses such as PGLFilterAttributeAffine implement a attributeUI collection
        // single affine parm attribute needs three independent settings rotate, scale, translate
        // also use color as collection of valueUI cells
        return [self]
    }

    // MARK: Swipe support

        /// super class empty implementation
    func setChildStackMode(inAppStack: PGLAppStack) {

    }

    func varyTimerAttribute() -> PGLFilterAttribute? {
            // override to answer nil in some subclasses (image etc)

        if let newTimerRow = PGLTimerRateAttributeUI(pglFilter: (self.aSourceFilter), attributeDict: self.initDict, inputKey: self.attributeName!) {
            newTimerRow.filterAttribute(parent: self)
                // triggers change to animation state
//            newTimerRow.startCellAnimationTimer()
            return newTimerRow}
        else { return nil }
    }

    func performAction(_ controller: PGLSelectParmController?) {
       
        // user has selected swipe cell action 'Vary'
        aSourceFilter.animate(attributeTarget: self)

    }
    func performActionOff() {
        aSourceFilter.attribute(removeAnimationTarget: self)

    }

    func postVaryTimerRunning(){
        let updateNotification = Notification(name:PGLVaryTimerRunning)
        NotificationCenter.default.post(name: updateNotification.name, object: nil, userInfo: ["varyTimerChange" : +1 as AnyObject])
    }

    func postVaryTimerOff(){
        let updateNotification = Notification(name:PGLVaryTimerRunning)
        NotificationCenter.default.post(name: updateNotification.name, object: nil, userInfo: ["varyTimerChange" : -1 as AnyObject])
    }


    func cellAction() -> [PGLTableCellAction] {
        //[(action:String,newCell:PGLFilterAttribute?) ]
        // subclasses override
        var allActions = [PGLTableCellAction]()
            // [(action:String,newCell:PGLFilterAttribute?) ]()

        if !hasAnimation() { // add Vary
            if let newVaryAttribute = varyTimerAttribute() {
                let varyAction = PGLTableCellAction(action: "Vary", newAttribute: newVaryAttribute, canPerformAction: true, targetAttribute: self)
                allActions.append(varyAction) }
            }
            else { // add Cancel
                let cancelVaryAction = PGLTableCellAction(action: "Cancel", newAttribute: nil, canPerformAction: true, targetAttribute: self)
                allActions.append(cancelVaryAction) }

            // the Vary cell needs to have it's own swipe actions of  Cancel, OK
            // the Vary cell controls the rate of change with it's own slider
            // the timerParent actually does the start / stop of the animation change to the parm value
            // it signals the filter
            //  currentFilter?.attribute(animateTarget: tappedAttribute)
            // or
            // currentFilter?attribute(removeAnimationTarget: PGLFilterAttribute)
            // the timer method is the #addStepTime


        return allActions
    }

    func segueName() -> String? {
          // subclasses override in the case where only a segue
        return nil
    }
    
    func performAction2(_ controller: PGLSelectParmController?) {
        // subclasses override in the case where only a segue or command is needed
        // a new subUI cell was not added by the actionCells method
     
    }

    func restoreOldValue() {
        // implement in subclasses for the various setValue types
        // each type should have a var for the last value to restore
        // future may be an array of changes.

    }

    // MARK: MoveTo Point
    func moveTo(startPoint: CGPoint, newPoint: CGPoint, inView: UIView) {
        // move is ended..
        switch attributeClass! {
        case AttrClass.Vector.rawValue :
            // map back to flipped vertical
            // this can be deleted.. moveTo... not called
            let flippedVertical = inView.bounds.height - newPoint.y
            let newVector = CIVector(x: newPoint.x, y: flippedVertical)
            self.set(newVector)
        case AttrClass.Color.rawValue: break
        case  AttrClass.Image.rawValue : break
        case  AttrClass.Number.rawValue :  break
        case  AttrClass.Data.rawValue :  break
        case  AttrClass.Value.rawValue : break
        case  AttrClass.Object.rawValue : break
        case  AttrClass.String.rawValue :  break
        case  AttrClass.AttributedString.rawValue : break

        default: assert(true == false)  // raises error on a new attribute class
        }
    }
    
    func movingChange(startPoint: CGPoint, newPoint: CGPoint, inView: UIView) {
        // pan move in progress.. update as needed
        switch attributeClass! {
        case AttrClass.Vector.rawValue :
            // map back to flipped vertical
             // this can be deleted for the ordinary point.. movingChange...
            // the rectangle subclass still uses this protocol

            let flippedVertical = inView.bounds.height - newPoint.y
            let newVector = CIVector(x: newPoint.x, y: flippedVertical)
            self.set(newVector)
        case AttrClass.Color.rawValue: break
        case  AttrClass.Image.rawValue : break
        case  AttrClass.Number.rawValue :  break
        case  AttrClass.Data.rawValue :  break
        case  AttrClass.Value.rawValue : break
        case  AttrClass.Object.rawValue : break
        case  AttrClass.String.rawValue :  break
         case  AttrClass.AttributedString.rawValue : break
            
        default: assert(true == false)  // raises error on a new attribute class
        }
    }

    // MARK: Subclass type
    // these will be moved to subclass as they are created
    func isVector() -> Bool {
        return attributeClass == AttrClass.Vector.rawValue
    }
    
    func attributeUIType() -> AttrUIType {
        // assumes these types do not overlap
        if isPointUI() { return AttrUIType.pointUI}

        if isSliderUI() {  return AttrUIType.sliderUI}
        if isImageUI() {  return AttrUIType.imagePickUI}
        if isRectUI()  { return AttrUIType.rectUI}
        if isTextInputUI() {return AttrUIType.textInputUI}
        if isFontUI() { return  AttrUIType.fontUI}
        // else
        return AttrUIType.filterPickUI
    }
    func isRectUI()->Bool {

        return false // subclass PGLFilterAttributeRectangle answers true
        // where attributeType= "CIAttributeTypeRectangle"
        //  & attributeClass= AttrClass.Vector.rawValue
    }

    func isSliderUI()-> Bool {
         let isNumberScalar = ( attributeType == AttrType.Scalar.rawValue  )
         let isNumberDistance = ( attributeType == AttrType.Distance.rawValue  )
         let isNumberAngle = ( attributeType == AttrType.Angle.rawValue )
         let hasSliderValue = ( sliderMinValue != nil ) && (sliderMaxValue != nil)
         let isColorSlider = (attributeClass == AttrClass.Color.rawValue)  // and should be a PGLFilterAttributeColor instance
         let isTransform = (attributeType == AttrType.Transform.rawValue)
        let isNumberClass = (attributeClass == AttrClass.Number.rawValue)
         let answer = ( isNumberScalar || isNumberDistance || isNumberAngle  || hasSliderValue || isColorSlider  || isTransform || isNumberClass )
//            NSLog("attribute \(attributeName) isSliderUI = \(answer)")
        return answer
    }

    func isPointUI() -> Bool {
        let isVectorPosition = (attributeClass == AttrClass.Vector.rawValue )
        if attributeType != nil {
            // who needs this additional check on attributeType?
            return ((attributeType == AttrType.Position.rawValue) || (attributeType == AttrType.Position3.rawValue) || (attributeType == AttrType.Offset.rawValue ) )
        }
        else { return isVectorPosition }
            // where attributeType is not defined then use the attributeClass only
    }

    func isTextInputUI() -> Bool {
        // CIAttributedTextImageGenerator inputText,
        // CIAztecCodeGenerator inputMessage
        // CICode128BarcodeGenerator  inputMessage
        // CIPDF417BarcodeGenerator  inputMessage
        // CIQRCodeGenerator  inputMessage inputCorrectionLevel
        // CITextImageGenerator inputText inputFontName

        if attributeName == "inputFontName" {
            return false}
        if attributeClass == AttrClass.String.rawValue {
            return true }
        if (attributeName == "inputText") || (attributeName == "inputMessage")
            { return true }

        return false // default value
    }
    func isFontUI() -> Bool {
        // attribute will use UIFontPickerViewController
        return (attributeName == "inputFontName")
    }

    func isImageUI() -> Bool {
        let isImage = (attributeClass ==  AttrClass.Image.rawValue  )
//            && attributeType == "CIAttributeTypeImage" )
        return isImage
    }

    // MARK: controlImageView






}











