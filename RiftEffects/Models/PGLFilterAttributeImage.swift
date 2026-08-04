//
//  PGLFilterAttributeImage.swift
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
// import Combine

class PGLFilterAttributeImage: PGLFilterAttribute {
    // attributeClass ==  AttrClass.Image.rawValue
    // || (attributeType == kCIAttributeTypeImage)?



    var isPostedTransitionImageAvailable: Bool = false

    var isDepthListAssigned = false
    // indicates that myFilter was assigned by a special constructor method
    // prevents the special specialConstructor from being assigned on every frame

    var storedParmImage: CDParmImage?

    /// Video input support

    var videoInputCount: Int = 0

//    var notifications: [NSNotification.Name : Any] = [:] // an opaque type is returned from addObservor
//    var publishers = [Cancellable]()
//    var cancellable: Cancellable?

    required init?(pglFilter: PGLSourceFilter, attributeDict: [String : Any], inputKey: String) {
        super.init(pglFilter: pglFilter, attributeDict: attributeDict, inputKey: inputKey)
        parmInputState = ParmInputState.missingImageInput
        // give the filter a value but the pglImageList still is not set and parmInputState is missingImageInput
        self.set(CIImage.empty())
    }
    
    override func releaseVars() {
        storedParmImage = nil
        super.releaseVars()
        
    }
    override func uiCellIdentifier() -> String {
        return  "Image"
    }

    override func set(_ value: Any ) {
        // use a system of double dispatch to address typing

        if attributeName != nil {
            if let newImage = value as? CIImage {
                aSourceFilter.setImageValue(newValue: newImage, keyName: attributeName!) }
            }
    }

  override func hasImageInput() -> Bool {

    // answer true if there is an inputCollection and it is not empty
      // or if image input is from another filter or child stack
      // first filter of stack and first image attribute cannot have a image input from prior filter
      
      if !imageInputIsEmpty( ) {
          return true
      }
      if hasFilterStackInput( ) {
          return true
      }

//      if imageParmState == .inputPriorFilter {
      // this state is not set until later in the processing
//          return true
//      }

      return false

  }
    override func setImageParmState(newState: ParmInputState) {

        // see PGLFilterAttributeImage
        parmInputState = newState

    }

    override func inputParmType() -> ParmInputState {

        return parmInputState
    }
    
  override  func setUICellDescription(_ uiCell: UITableViewCell) {
    var content = uiCell.defaultContentConfiguration()

    var newDescriptionString = self.attributeDisplayName ?? ""
    let sourceString = inputSourceDescription ?? ""

    if inputStack != nil {
        newDescriptionString = newDescriptionString + " -> " + (inputStack?.outputFilterName() ?? "")
    } else {
        if sourceString.isEmpty {
            if inputParmType() == .missingImageInput {
                newDescriptionString = newDescriptionString + " ----> "
            }
            else {
                newDescriptionString = newDescriptionString + " -> " + NSLocalizedString("Photos", comment: "Photo library source name")
            }

        }
        else {
            newDescriptionString = newDescriptionString + " -> " + sourceString
        }
    }
    content.text = newDescriptionString
    content.imageProperties.tintColor = .secondaryLabel
      
      

    let parmInputType = inputParmType()
    switch parmInputType {
        case ParmInputState.inputChildStack:
            content.image = PGLFilterAttribute.FlowChartSymbol
        case ParmInputState.inputPhoto:
            if self.hasOnePhoto() {
                content.image = PGLFilterAttribute.PhotoSymbolSingle }
             else {
                content.image = PGLFilterAttribute.PhotoSymbol }
        case ParmInputState.inputPriorFilter :
            content.image = PGLFilterAttribute.PriorFilterSymbol
        case ParmInputState.missingImageInput , .inputValueSet :
            content.image = PGLFilterAttribute.MissingPhotoInput
        case ParmInputState.valueParmNotSet :
            content.image = nil // other symbols are set???
        case ParmInputState.rectangleInput :
            content.image = PGLFilterAttribute.CropSymbool
      
    }

    uiCell.contentConfiguration = content

  }
    func resetDrawableSize() {
        
        let resetSuccess = inputCollection?.resetCenteredImageCache() ?? false
        if resetSuccess {
            guard let currentImageResized = inputCollection?.getCurrentImage() else
            { return }
            aSourceFilter.setImageValue(newValue: currentImageResized, keyName: self.attributeName!)
        }

    }
    

    func imageInputIsEmpty() -> Bool {
        if inputCollection == nil { return true }
        return inputCollection!.isEmpty()
    }

    func filterInputActionCell() -> PGLFilterAttribute? {
        // override to answer nil in some subclasses (image etc)

        return nil
    }

    override func setChildStackMode(inAppStack: PGLAppStack) {
        // should this be used?? may be duplicate
        // #pushChildStack
        // delete if this is duplicate #pushChildStack
        guard let localInputStack = inputStack
        else { return }
        if inputParmType() == ParmInputState.inputChildStack {
            // should stackMode be set to Replace
            // the normal setting?
            inAppStack.pushChildStack(localInputStack)
        }
    }

 override func cellAction() -> [PGLTableCellAction ] {
        // Image cell does not add subUI cells
        // just provides the contextAction
        // nil filterInputActionCell will trigger a segue
        var allActions = [PGLTableCellAction]()
        if parmInputState == ParmInputState.inputPriorFilter {
            return allActions
            // empty no actions
            //can't change input from prior filter so no cell action swipe cells
        }
        let newPickAction = PGLTableCellAction(action: "Library", newAttribute: filterInputActionCell(), canPerformAction: true, targetAttribute: self)
        newPickAction.performAction2 = true
        // performAction2 will execute if true and it will not execute performAction
     
        allActions.append(newPickAction)
    
        if hasFilterStackInput() {
            let changeAction = PGLTableCellAction(action: "Change", newAttribute: filterInputActionCell(), canPerformAction: false, targetAttribute: self)
            // this should change to the child stack... but
            allActions.append(changeAction)
        }
        else {
            let newAction = PGLTableCellAction(action: "+Effex", newAttribute: filterInputActionCell(), canPerformAction: false, targetAttribute: self)
            // this will segue to filterBranch.. opens the filterController
            allActions.append(newAction) }

        return allActions
    }

    override func performAction(_ controller: PGLSelectParmController?) {
        controller?.pickImage(self)

    }

    override func performAction2(_ controller: PGLSelectParmController?) {
        // choose stack from library as input child stack
        NSLog("PGLFilterAttributeImage performAction2")
        controller?.pickLibraryChildStack()
    }

    func loadChildStackToSequenceStack(inAppStack: PGLAppStack, userPickLibraryStack: PGLFilterStack) -> Bool {
            // empty implementation
            // see subclass PGLFilterAttrSequenceStack
            return false  // not a sequenceStackLoad
        }

    override func segueName() -> String? {
        // answer the  segue action
        // a new subUI cell was not added by the actionCells method
        
         return "goToFilterViewBranchStack"
        // this segue is attached to a different cell in IB
        // namely the ImageNewFilterInput prototype cell
        // a single prototype cell does not support  having two segues..
        // but the other cells segue can be called with perform(segue..)

    }

    func sourceImageAlbums() -> [String]? {

        if let sources = inputCollection?.sourceImageAlbums() {
            return sources
        }
        else { return nil }
    }

    // MARK: Video
/// videoFrameChange
     func updateVideoFrame() {
        // set the current video frame into the parm
        if inputCollection?.currentImageIsVideo() ?? false {
            if let ciVideoFrame =  inputCollection?.getCurrentImage() {
                aSourceFilter.setImageValue(newValue: ciVideoFrame, keyName: attributeName!)
            }
        }
    }

    func changeVideoInputCount(count: Int) {
        videoInputCount += count

    }

    override func videoInputExists() -> Bool {
        return videoInputCount > 0
    }

    func postImageChange() {
    //           let outputImageUpdate = Notification(name:PGLOutputImageChange)
    //           NotificationCenter.default.post(outputImageUpdate)
           }

    override func postTransitionFilterAdd() {
        if !isPostedTransitionImageAvailable {
            isPostedTransitionImageAvailable = true
            Logger(subsystem: LogSubsystem, category: LogCategory).info ("\( String(describing: self) + "-" + #function) ")
            super.postTransitionFilterAdd()
        }
    }

    override func postTransitionFilterRemove() {
        if isPostedTransitionImageAvailable {
            Logger(subsystem: LogSubsystem, category: LogCategory).info ("\( String(describing: self) + "-" + #function) ")
            isPostedTransitionImageAvailable = false
            super.postTransitionFilterRemove()
        }
    }



} // end PGLFilterAttributeImage
