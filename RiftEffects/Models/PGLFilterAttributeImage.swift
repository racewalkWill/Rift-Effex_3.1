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
                aSourceFilter?.setImageValue(newValue: newImage, keyName: attributeName!) }
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
        if let master = linkMaster {
            // a linked target answers the input state of its master
            return master.inputParmType()
        }
        return parmInputState
    }
    
  override  func setUICellDescription(_ uiCell: UITableViewCell) {
    var content = uiCell.defaultContentConfiguration()

    var newDescriptionString = self.attributeDisplayName ?? ""
    let sourceString = inputSourceDescription ?? ""

    if let master = linkMaster {
        newDescriptionString = newDescriptionString + " -> " + master.parentParmFilterName()
    } else if inputStack != nil {
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
    applyLinkDescription(to: &content)

    uiCell.contentConfiguration = content

  }
    func resetDrawableSize() {
        
        let resetSuccess = inputCollection?.resetCenteredImageCache() ?? false
        if resetSuccess {
            guard let currentImageResized = inputCollection?.getCurrentImage() else
            { return }
            aSourceFilter?.setImageValue(newValue: currentImageResized, keyName: self.attributeName!)
        }

    }
    

    func imageInputIsEmpty() -> Bool {
        guard let statusList = statusImageList
            else { return true }
        return statusList.isEmpty()
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
        if isLinkTarget {
            // a target shows the images of its master - only Unlink
            return [linkAction("Unlink")]
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

        if let imageLinkAction = linkCellAction() {
            allActions.append(imageLinkAction)
        }
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

        if let sources = statusImageList?.sourceImageAlbums() {
            return sources
        }
        else { return nil }
    }

    // MARK: Image Link
    /// A linked target shows the images of its master's PGLImageList - see PGLFilterAttribute MARK: Parm Link.
    /// Every image write to a filter passes PGLSourceFilter #setImageValue, which forwards a master's
    /// new image to its targets and ignores any other write to a linked target.
    /// The target keeps its own inputCollection while linked - it is not released, since a clone list
    /// may share PGLAssets with another parm - and the target shows it again on unlink.
    private var isReceivingLinkedImage = false

    override var inputCollection: PGLImageList? {
        didSet {
            // the master list changed - targets re-check their transition state against it
            for aTarget in linkTargets {
                _ = aTarget.aSourceFilter?.notifyTransitionsExist()
            }
        }
    }

    override var statusImageList: PGLImageList? {
        if let master = linkMaster {
            return master.statusImageList
        }
        return inputCollection
    }

    override func isLinkable() -> Bool {
        if (self is PGLFilterAttrSequenceStack) || (aSourceFilter is PGLSequencedFilters) {
            // sequence stacks deliver their own images
            return false
        }
        if inputStack != nil {
            // input from a child stack
            return false
        }
        switch parmInputState {
            case .inputPhoto, .missingImageInput:
                break
            default:
                // prior filter or child stack input
                return false
        }
        if (attributeName == kCIInputImageKey) && ((aSourceFilter?.stackPosition ?? 0) > 0) {
            // the stack feeds the prior filter output into this input on every frame
            return false
        }
        return true
    }

    /// a master needs images to share
    override func canBeLinkMaster() -> Bool {
        guard isLinkable(), parmInputState == .inputPhoto
            else { return false }
        return !(inputCollection?.isEmpty() ?? true)
    }

    override func canLink(to target: PGLFilterAttribute) -> Bool {
        return target is PGLFilterAttributeImage
    }

    override func willBecomeLinkTarget() {
        // transition state is re-checked against the master list after the link
        postTransitionFilterRemove()
    }

    override func didLink(target: PGLFilterAttribute) {
        guard let imageTarget = target as? PGLFilterAttributeImage
            else { return }
        if let currentImage = getImageValue() {
            imageTarget.receiveLinkedImage(currentImage)
        }
        _ = imageTarget.aSourceFilter?.notifyTransitionsExist()
    }

    /// show the own images of this parm again
    override func didUnlinkFromMaster() {
        postTransitionFilterRemove()
        if let ownList = inputCollection, !ownList.isEmpty() {
            set(ownList.getCurrentImage())
        } else {
            set(CIImage.empty())
        }
        _ = aSourceFilter?.notifyTransitionsExist()
    }

    override func linkDisplayName() -> String {
        // image links may join two inputs of the same filter - show the parm name too
        return parentParmFilterName()
    }

    override func linkPickerTitle() -> String {
        return NSLocalizedString("Link Image", comment: "action sheet title - link image inputs of filters")
    }

    override func linkPickerMessage() -> String {
        return NSLocalizedString("The linked input shows the images of this input.", comment: "action sheet message - link image inputs")
    }

    override func linkFollowPickerMessage() -> String {
        return NSLocalizedString("This input shows the images of the linked input.", comment: "action sheet message - an empty image input picks the image input it follows")
    }

    /// true if PGLSourceFilter #setImageValue should ignore a write to this parm
    func blocksImageWrite() -> Bool {
        return isLinkTarget && !isReceivingLinkedImage
    }

    /// write the master's image into the filter of this target
    func receiveLinkedImage(_ image: CIImage) {
        guard let myAttributeName = attributeName
            else { return }
        isReceivingLinkedImage = true
        defer { isReceivingLinkedImage = false }
        aSourceFilter?.setImageValue(newValue: image, keyName: myAttributeName)
    }

    /// called by PGLSourceFilter #setImageValue after this master's image changed
    func propagateLinkedImage(_ image: CIImage) {
        guard isLinkMaster
            else { return }
        for aTarget in linkTargets {
            (aTarget as? PGLFilterAttributeImage)?.receiveLinkedImage(image)
        }
    }

    override func increment() {
        if isLinkTarget {
            // the master increments the shared list
            return
        }
        super.increment()
    }

    // MARK: Video
/// videoFrameChange
     func updateVideoFrame() {
        // set the current video frame into the parm
        if isLinkTarget {
            // the master pushes its video frames to the linked targets
            return
        }
        if inputCollection?.currentImageIsVideo() ?? false {
            if let ciVideoFrame =  inputCollection?.getCurrentImage() {
                aSourceFilter?.setImageValue(newValue: ciVideoFrame, keyName: attributeName!)
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
