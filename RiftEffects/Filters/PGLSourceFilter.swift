//
//  PGLSourceFilter.swift
//  
//
//  Created by Will on 3/9/17.
//  Copyright © 2017 Will Loew-Blosser. All rights reserved.
//  Modified from Apple CIFunHouse sample app file FilterStack.h
//

import Foundation
import CoreImage
import simd
import UIKit
import os
import CoreData


protocol PGLAnimation {
    func addFilterStepTime() async
}



@MainActor
class PGLSourceFilter :  PGLAnimation  {
    // helper object for CIFilter  holds the filter and dispatches
    // PGLSourceFilter holds PGLFilterAtrributes.. make a subclass of  PGLSourceFilter if filter specific logic needed across multiple attributes
    // i.e. if constraints exist between attributes the PGLSourceFilter implements the filter as a subclass


//    let AssociationKey = "storedImageInputAttributeKeys"
    // 10/22/17 removing the cache of attributes for now .. check performance

    // Subclassing NOTE: if subclass is added similar to the PGLCropFilter then the
    // instance creation in the PGLFilterDescriptor init method needs another case..
        //    if thisName == PGLCropFilter.pglNameForFilter()?.filterName {
        //    pglSourceFilterClass = PGLCropFilter.self
        //

        /// in the debugger execute expression PGLSourceFilter.LogParmValues = true
static let LogParmValues = true //false
        // set to true to capture parm  set value messages & values
        // enter in the debug
        //      po PGLSourceFilter.LogParmValues = true
        // console will show lines containing filterName, setter method, values, attribute name
        // example:
        //  [PGL_Parms] CILinearGradient setVectorValue(newValue:keyName:)( [1047 504] , inputPoint0 )




    class func displayName() -> String? {
        return nil // subclasses override
        // FilterDescriptor will use the ciFilter.localizedName if this is nil.
        // where a ciFilter is used with different pglSourceFilter classes then this method should be implemented
        // by the subclass
    }

    class func classStringName() -> String {
        return String(describing: self)
    }
    var filterName: String! {
        didSet {
            Logger(subsystem: LogSubsystem, category: LogCategory).notice("PGLSourceFilter filterName set to String(describing:filterName)")
        }
    }
    var descriptorDisplayName: String? // not the same as the ciFilter name


    var localFilter: CIFilter // do not make unowned
    var attributes = [PGLFilterAttribute]() // may have subclasses
    var filterCategories = [String]()
    var uiPosition: PGLFilterCategoryIndex

    var stackPosition: Int = 0
        // stackPostion is UI attribute does not need to be stored

    var isImageInputType = false
    weak var oldImageInput: CIImage?
    var storedFilter: CDStoredFilter? // managedObject - write/read to Core Data
    var imageInputCache: [String :CIImage?] = [:]

    // animation vars
    var hasAnimation = false {
        didSet {
            NSLog("hasAnimation = \(hasAnimation)")
        }
    }
    
    var animationAttributes = [PGLFilterAttribute]()
    var userLengthSeconds: Float = 0.0
    var stepTime = 0.0 {
        // range -1.0 to 1.0
        didSet {
//            NSLog("PGLSourceFilter stepTime now = \(stepTime)")
        }
    }
    let defaultDt = 0.01
    var dt = 0.01{
        didSet{
            wrapper?.dt = dt
            // wrapper if active needs the rate of change dt
        }
    // rate of change for animation & increment timers
    }
    var detectors = [any PGLDetection]()
    lazy var thumbNail = getThumbnail() // only set when referenced need to reset on changes..
    unowned var wrapper: PGLDissolveWrapperFilter?
private  var userDescription: String?

    var isAverageLuminanceNearZero = false

@IBInspectable var debugOutputImage = false


    //MARK: subclass creation
   // add a dict pair into PGLFilterDescriptor for subclasses
    // PGLFilterDescriptor.pglFilterClassDict = ["CICrop": PGLCropFilter.self, "CICropDown": PGLCropDownFilter.self ]
    func classStringName() -> String {
        // answer the displayname of the class for use in matching
        // to the correct PGLSourceFilter class in the core data read methods.
        return String(describing: (type(of:self).self))
    }

    //MARK: instance inits
required init?(filter: String, position: PGLFilterCategoryIndex) {
    if let thisFilter = type(of:self).self.requestCISourceFilter(filterName: filter)
        // funny way to myClass methods. Gets get the class to provide the CIFilter instance
        // subclass of PGLSourceFilter may construct different CIFilter - see PGLDepthFilter

            {
            uiPosition = position
            filterCategories = thisFilter.attributes[kCIAttributeFilterCategories] as! [String]

            self.localFilter = thisFilter
//             NSLog("PGLSourceFilter #init localFilter = \(localFilter)")
            // some attributes... CIAbstractFilter could be filtered out here ie. the feature select..
            for anAttributeKey in thisFilter.inputKeys {
                let inputParmDict = (thisFilter.attributes[anAttributeKey]) as! [String : Any]
                
                let parmAttributeClass = parmClass(parmDict: inputParmDict)
//                parmAttributeClass.updateDefaultValues(parmDict: inputParmDict)
                if let thisParmAttribute = parmAttributeClass.init(pglFilter: self, attributeDict: inputParmDict, inputKey: anAttributeKey  )
                    {
                    attributes.append(contentsOf: thisParmAttribute.valueInterface())
                           // some parmAttributes have multitple value settings (AffineTransform etc)
                           // most just answer themselves for the value UI (slider, position...)
                }
                isImageInputType =  attributes.contains { (attribute: PGLFilterAttribute ) -> Bool in
                    attribute.isImageInput()
                }
            }
            filterName = filter // string name in the method call
        } else
            { return nil }
    }

    convenience init?(filter: String) {
       self.init(filter: filter, position: PGLFilterCategoryIndex()) // default index with zeros, empty values

    }
    
    func parmClass(parmDict: [String : Any ]) -> PGLFilterAttribute.Type  {
        // override in PGLSourceFilter subclasses..
        // most will do a lookup in the class method
        return PGLFilterAttribute.parmClass(parmDict: parmDict)
    }

//    deinit {
//        Logger(subsystem: LogSubsystem, category: LogMemoryRelease).info("\( String(describing: self) + " - deinit" )")
//    }
    func updateDefaultValues(parmDict: [String:Any]) {
        // superclass empty implementation
    }

    func releaseVars() {
        for anAttribute in attributes {
            anAttribute.releaseVars()
        }
//        storedFilter = nil

    }

   class func requestCISourceFilter(filterName: String) -> CIFilter? {
        // override if needed -  see PGLDepthFilter
        return CIFilter(name: filterName)
    }

    class func localizedDescription(filterName: String) -> String {
        // custom subclasses should override
        guard let standardDescription = CIFilter.localizedDescription(forFilterName: filterName)
            else { return filterName }
        return standardDescription

    }

    func resetAttributesToLocalFilter() {
        // if the local filter (a CIFilter) is changed then the
        // attributes all need it too.. this occurs in the CoreData read
        for anAttribute in attributes {
            anAttribute.myFilter = self.localFilter
        }
    }

    func setCIContext(detectorContext: CIContext?) {
        // super class does nothing
        // subclasses using a CIDetector will use this

    }

    func isTransitionCategoryFilter() -> Bool {
        // answers true if filterCategories contains value "CICategoryTransition"
        // only transition filters should have multiple images in a parm imageList
         return filterCategories.contains("CICategoryTransition")

    }

    func notifyTransitionsExist() -> Bool {
        // answer true if there are two parms with at least
        // one image
        // or one parm with 2 or more images
        // input from stack is an image input to the parm
        // post transitionFilterAdd if true
//        Logger(subsystem: LogSubsystem, category: LogCategory).info ("\( String(describing: self) + "-" + #function) ")
        if !isTransitionCategoryFilter() {
            return false
        }

        let transitionAttributes = imageAttributes()
        if transitionAttributes.isEmpty {
            return false
        }
        var attributesWithInput = transitionAttributes.filter(
            { $0.hasImageInput() } )
        // also check for .inputPriorFilter
        if stackPosition != 0 {
            // this filter is not the first in the stack
            //  and then first image attributes should have .inputPriorFilter
            if !transitionAttributes.isEmpty {
                let priorInputAttribute = transitionAttributes[0]
                // first image attribute should be the one getting input from prior filter output
                if !priorInputAttribute.hasImageInput() {
                    // it failed the hasImageInput test, but will have .inputPriorFilter
                    attributesWithInput.append(priorInputAttribute)
                }
            }
        }

        if attributesWithInput.isEmpty {
            return false
        }
        if attributesWithInput.count > 1 {
            // there are at least two attributes with at least one input image
            // all qualify to post
            for anImageAtt in attributesWithInput {
                anImageAtt.postTransitionFilterAdd()
            }
            return true
        } else {
            // exactly one element in attributesWithTransitions
            // does it have more than one image
            guard let singleImageAttribute = attributesWithInput.first
                else { return false}
            guard let singleList = singleImageAttribute.inputCollection
                else { return false }
            if singleList.isMultiple() {
                    singleImageAttribute.postTransitionFilterAdd()
                    return true
                } else {
                    // one attribute with one input can not transition
                    return false
                }
            }

    }





    func imageAttributes() -> [PGLFilterAttributeImage] {
        let allImageAttributes = imageInputAttributeKeys.map({attribute(nameKey:$0)}  )

        let converted = allImageAttributes.map({ $0 as! PGLFilterAttributeImage})
        return converted

    }


    func setUpStack(onParentImageParm: PGLFilterAttributeImage) -> PGLFilterStack {
        // super class answers normal stack
        // the sourceFilter subclass PGLSequencedFilters
        // connects the PGLSequenceStack with the ciFilter

       return PGLFilterStack()

    }

    // MARK: Demo Updates

    /// some parms based on center points need to change if the image sizng changes
    ///  does not change non position vector parms (such as color vectors)
//    func applyParmSizeChange(changeAffine: CGAffineTransform) {
//        if filterName == "CIToneCurve" {
//            return
//        }
//        for aParm in attributes {
//            aParm.applyParmSizeChange(changeAffine: changeAffine)
//        }
//    }
    func setRandomParms() {
        for anAttribute in self.attributes {
            anAttribute.setRandomValue()
        }
    }
    func removeImagesTo(collectImagesList: PGLImageList) {
        let imageKeys = self.imageInputAttributeKeys
        for anKey in imageKeys {
            guard let imageAttribute = self.attribute(nameKey: anKey) as? PGLFilterAttributeImage
            else { continue }
            if (imageAttribute.inputStack != nil) {
                    // drill down child stacks
                _ =  imageAttribute.inputStack!.removeAllImagesAndStopAnimations(collectImagesList: collectImagesList)
            }
            else {
                    // not a child stack.. collect this level
                guard let thisAttributeImageCollection = imageAttribute.inputCollection
                else { continue }
                imageAttribute.removeTransitionCounts() // call this before the images are removed
                collectImagesList.moveContentsFrom(thisAttributeImageCollection)
            }
            if imageAttribute.parmInputState == .inputPhoto {
                // other states .inputChildStack or .inputPriorFilter or .missingInput
                // do not need to be changed
                imageAttribute.set(CIImage.empty() )
                imageAttribute.setImageParmState(newState: .missingImageInput)
                }
            }
    }

    // MARK: input/output
    fileprivate func setDetectorsInput(_ image: CIImage?, _ source: String?) {
        // make all input image go to this method
        for aDetector in detectors {
            aDetector.setInput(image: image, source: source)
            // detector checks for features on setInput
            if let myLocalCIAbstractFilter = localFilter as? PGLFilterCIAbstract {
                // other CIFilters do not have the features var
                myLocalCIAbstractFilter.features = aDetector.features
            }
        }
    }

    func setInput(image: CIImage?, source: String?) {

        if isImageInputType {
            if ((oldImageInput !== image)  && ( image != nil) ) { // same condition used in subclass PGLDetectorFilter.setInput
                // ignore changes in the image input for successive frames.
                oldImageInput = image
// uncomment this logging to see the frame by frame .. also lists the kernel in the filter... for CIDepthOfField it's more than you would think.
//                if debugOutputImage { NSLog("PGLSourceFilter setInput(image: didSet = \(String(describing: image))") }
//                localFilter.setValue(image, forKey: inputImage)

                setImageValue(newValue: image!, keyName: kCIInputImageKey)

                if source != nil {setSource(description: source!, attributeKey: kCIInputImageKey)}
            }
            // let the addStepTime do this
           setDetectorsInput(image, source) // same condition used in subclass PGLDetectorFilter.setInput
        }
    }





    var imageInputCount: Int {
        // computed property
        return (imageInputAttributeKeys.count)
    }
    
    fileprivate func setImageInputAttributKeys() -> [String] {

        var imageKeyFound = false
        var addingArray = [String]()
        for key in localFilter.inputKeys {
            imageKeyFound = false // reset for each key
            if let attrDict = localFilter.attributes[key]  {
                let thisDict = attrDict as! [String : Any]
                if let attributeType = thisDict[kCIAttributeType] as? String {
                    if attributeType == kCIAttributeTypeImage {
                        addingArray.append(key)
                        imageKeyFound = true
                    }
                }
                else { // no attributeType entry found
                    if let attributeClass = thisDict[kCIAttributeClass] as? String {
                        if !imageKeyFound && (attributeClass == "CIImage") {
                                // don't add twice if both attributeClass and attributeType are listed
                            addingArray.append(key)
                            imageKeyFound = true
                        }
                    }

                }

                if !imageKeyFound {
                        // case for another attribute type ..
                        // such as inputGradientImage in CIColorMap
                        // which has attibuteClass of CIImage
                    if let attributeClass = thisDict[kCIAttributeClass] as? String {
                        if (attributeClass == "CIImage") {
                                // don't add twice if both attributeClass and attributeType are listed
                            addingArray.append(key)
                            imageKeyFound = true
                        }
                    }

                }
            } // attributes of this key
        }  // end key for loop
        return  addingArray
    }

   lazy var imageInputAttributeKeys = setImageInputAttributKeys()

     func otherImageInputKeys() -> [String] {
            // answers other image inputs
            // does not include the common kCIInputBackgroundImageKey, kCIInputImageKey
            // not currently used.. but seems useful at some point.
            var otherKeys = imageInputAttributeKeys
            otherKeys.removeAll(where: {$0 == kCIInputBackgroundImageKey})
            otherKeys.removeAll(where: {$0 == kCIInputImageKey})
            return otherKeys
        }


    func canPasteImage() -> Bool {
        // subclsses answer true as needed see PGLPasteUIImage
        return false
    }

    func hasImageParmMissingInput() -> Bool {
       // answer true if one image Parm is missing an input
        for imageAttributeKey in imageInputAttributeKeys {
            if let inputAttribute = attribute(nameKey: imageAttributeKey )
            {
                if  inputAttribute.inputParmType() == ParmInputState.missingImageInput
                        {
                    return true }
            }
        }
        return false // default return - all inputs are populated or none are image inputs
    }

    func allImageParmsMissingInput() -> Bool {
        // answer false if no image parms or all imageParms are missing inputs
        if imageInputAttributeKeys.isEmpty {
            return false
        }
        for imageAttributeKey in imageInputAttributeKeys {
            if let inputAttribute = attribute(nameKey: imageAttributeKey )
            {
                if  inputAttribute.inputParmType() != ParmInputState.missingImageInput
                {   // found a parm with an image input
                    return false }
            }

        }
        // default return
        return true // all of the imageParms are missing input
    }

    func setInputImageParmState(newState: ParmInputState) {
        if let inputImageAttribute = getInputImageAttribute() {
            inputImageAttribute.setImageParmState(newState: newState)
        }
    }

    func getInputImageAttribute()-> PGLFilterAttributeImage? {
        if let inputImageAttribute = attribute(nameKey: kCIInputImageKey ) {
            return inputImageAttribute as? PGLFilterAttributeImage
        }
        return nil
    }

    func localizedName() -> String {
      return  CIFilter.localizedName(forFilterName: localFilter.name) ?? "unNamed"
    }

    func outputImage() -> CIImage? {
        // if any inputs are from another filter then they should be updated first

//        addFilterStepTime()  // if animation then move time forward
        // increments this filter detectors 

        if let myWrapper = wrapper {
            /// if let form check added for production crash on   if not nil wrapper { wrapper!outputImageBasic()
            /// not clear how the if not nil check failed - a concurrency memory management issue???
            ///
            return myWrapper.outputImageBasic()
        }
        else {
            return outputImageBasic()
        }
            // notice that addStepTime is called  inside the outputImageBasic

    }

    func firstDetector() -> (any PGLDetection)? {
        return detectors.first
    }
    func outputImageBasic() -> CIImage? {

        // wrapper may call this to produce wrapper effects on the basicImage
        addFilterStepTime()  // if animation then move time forward
        updateImageVideoFrames()

        for anAttribute in attributes {
                    anAttribute.updateFromInputStack()
                    anAttribute.applyRenderSize(RenderTargetSize)
                }
        if hasImageParmMissingInput() {
            return CIImage.empty()
            
        }
        let thisOutput = localFilter.outputImage
        //        thisOutput?.cropped(to: thisOutput!.extent)
//                if debugOutputImage { NSLog("PGLSourceFilter outputImage =  \(String(describing: thisOutput))")  }
        return thisOutput
    }

    func scaleOutput(ciOutput: CIImage, stackCropRect: CGRect) -> CIImage {
        // empty implementation answers the input
        // subclassses such as PGLRectangleFilter which crops implement
        return ciOutput
    }
     func setDefaults() {
        // in iOS this is set automatically - macOS needs explicit setDefaults()
        // test cases are callers so comment out to
        // get tests to run same as runtime

        // localFilter.setDefaults()
    }




    
    func isBackgroundImageInput() -> Bool {
        return attributes.contains { (attribute: PGLFilterAttribute ) -> Bool in
            attribute.isBackgroundImageInput()
        }
    }

    func isMaskImageInput() -> Bool {
        return attributes.contains { (attribute: PGLFilterAttribute ) -> Bool in
            attribute.isMaskImageInput()
        }
    }

    func setImageValuesAndClone(inputList: PGLImageList, attributeName:String ) {
        //  superclass implementation to dispatch into the attribute
        // special filters that need aux data to function should override
        // PGLDisparityFilter implements
//        guard let newImage = inputList.first() else {
//            return // cache may not have returned yet from the PHPhoto librar
//        }
        let newImage = inputList.first() ?? CIImage.empty()
        setImageValue(newValue: (newImage), keyName: attributeName)
        setImageListClone(imageList: inputList, sourceKey: attributeName)
       
    }

    func setUserPick(attribute: PGLFilterAttribute, imageList: PGLImageList) {
        //  superclass implementation to dispatch into the attribute
        // special filters that need aux data to function should override
        // PGLDisparityFilter implements
        attribute.setImageCollectionInput(cycleStack: imageList)
    }

    // MARK: thumbnails
    func getThumbnail(dimension: CGFloat = 200.0 ) -> UIImage {

            if  let ciOutput = outputImage() {

                let thumbnail = ciOutput.thumbnailUIImage(dimension)
                return thumbnail
            }
        // if no output return empty UIImage
        return UIImage()
    }

    func fullFilterName() -> String {
        // both localized name in the interface and the ciFilter name
        // use in NSLog statements
        return "\(String(describing:self.localizedName())) \(String(describing: self.filterName)))"
    }

    func filterUserDescription() -> String? {
        if userDescription == nil {
            if let myuserDescriptor = PGLFilterCategory.getFilterDescriptor(aFilterName: self.filterName, cdFilterClass: classStringName()) {
                    userDescription = myuserDescriptor.userDescription
            }
        }
        return userDescription
    }
    


     func postImageChange() {
//        let outputImageUpdate = Notification(name:PGLOutputImageChange)
//        NotificationCenter.default.post(outputImageUpdate)
    }

    // MARK: UIImage Store/Read
    func createCDClipboardData(filterImageAttribute: PGLFilterAttributeImage, moContext: NSManagedObjectContext) {
        // empty superclass implementation
        // save into coreData images that are not in the photoLibrary
        // see PGLPastUIImageFilter

    }

    func supportsImageClipboardData() -> Bool {
        return false
    }
        // MARK: set/get value

    func setImageValue(newValue: CIImage, keyName: String) {
//        NSLog("PGLFilterClasses #setImageValue key = \(keyName)")
//        newValue.clampedToExtent()        // test changing all inputs to the same extent

        localFilter.setValue( newValue, forKey: keyName)
//        logParm(#function, newValue.debugDescription, keyName)
        /*
         var sizedInput: CIImage
        if isTransitionFilter() {

            sizedInput = newValue.scale( targetSize: RenderTargetSize)
                    // scale checks for equal extent size, adjusts as needed to match
            
            localFilter.setValue( sizedInput, forKey: keyName)
        } else {
            localFilter.setValue( newValue, forKey: keyName)
        }
         */

    }

    func removeImageValue(keyName: String) {
        localFilter.setValue(nil, forKey: keyName)
    }

    func setBackgroundInput(image: CIImage?) {
        if isBackgroundImageInput() {
            localFilter.setValue( image, forKey: kCIInputBackgroundImageKey)
            postImageChange()
        }
    }

    func setMaskInput(image: CIImage?) {
        if isMaskImageInput() {
            localFilter.setValue( image, forKey: kCIInputMaskImageKey)
            postImageChange()
        }
    }

     func logParm(_ methodString: String, _ newValue: String, _ keyName: String) {
        if PGLSourceFilter.LogParmValues {
            Logger(subsystem: LogSubsystem, category: LogParms).debug("\(self.filterName ?? "noFilterName") \(methodString)( \(newValue) , \(keyName) )")
        }
    }

    func setNumberValue(newValue: NSNumber, keyName: String) {
        localFilter.setValue( newValue, forKey: keyName)
        logParm(#function, newValue.debugDescription, keyName)
        postImageChange()
    }


    func setVectorValue(newValue: CIVector, keyName: String) {
        logParm(#function, newValue.debugDescription, keyName)
        localFilter.setValue( newValue, forKey: keyName)
        postImageChange()
    }
    func setColorValue(newValue: CIColor, keyName: String) {
        localFilter.setValue( newValue, forKey: keyName)
        logParm(#function, newValue.debugDescription, keyName)
        postImageChange()
    }
    func setDataValue(newValue: NSData, keyName: String) {
        localFilter.setValue( newValue, forKey: keyName)
        logParm(#function, newValue.debugDescription, keyName)
        postImageChange()
    }
    func setNSValue(newValue: NSValue, keyName: String) {
        localFilter.setValue( newValue, forKey: keyName)
        logParm(#function, newValue.debugDescription, keyName)
        postImageChange()
    }
    func setObjectValue(newValue: NSObject, keyName: String) {
        localFilter.setValue( newValue, forKey: keyName)
        logParm(#function, newValue.debugDescription, keyName)
        postImageChange()
    }
    func setStringValue(newValue: NSString, keyName: String) {
        localFilter.setValue( newValue, forKey: keyName)
        logParm(#function, newValue.debugDescription, keyName)
        postImageChange()
    }

    func setAttributeStringValue(newValue: NSAttributedString, keyName: String) {
        localFilter.setValue( newValue, forKey: keyName)
        logParm(#function, newValue.debugDescription, keyName)
        postImageChange()
    }

    

    
    
    func valueFor( keyName: String) -> Any? {
        return localFilter.value( forKey: keyName)
    }

    func inputImage() -> CIImage?  {
        if isImageInputType {
            let thisValue = valueFor(keyName: kCIInputImageKey) as? CIImage
            return thisValue
        }
        else {
            return CIImage.empty()}
    }

    func addChildSequenceStack(appStack: PGLAppStack) {
       // over ride in PGLSequencedFilters

    }

// MARK: flattened Filters
    func stackRowCount() -> Int {
        // answer 1 plus the count of filters in the input parm stacks
        // usually 1
        var childRowCount = 0
        for aParm in attributes {
            childRowCount += aParm.stackRowCount()
        }
        return 1 + childRowCount  // answer 1 row for the filter
    }

    func addChildFilters(_ level: Int, into: inout Array<PGLFilterIndent>) {
        // called for flattened filters
        // there may be several childInputStacks at this level
        for aParm in attributes {
            if aParm.hasFilterStackInput() {
                aParm.addChildFilters(level, into: &into )
            }
        }
    }



     // MARK: input source
    func attribute(nameKey: String) -> PGLFilterAttribute? {
        if let sourceIndex = attributes.firstIndex(where: {$0.attributeName == nameKey})
        { return attributes[sourceIndex]}
        else { return nil }
    }

    func setSourceFilter(sourceLocation: (source: PGLFilterStack, at: Int),attributeKey: String) {
        // checking memory circular ref between aSourceFilter and inputSource vars
        // 2020-10-20 comment out below
//        if let sourceAttribute = attribute(nameKey: attributeKey)
//        {  sourceAttribute.inputSource = sourceLocation
//            if let imageAttribute = sourceAttribute as? PGLFilterAttributeImage {
//                if ( sourceLocation.at > 0 ) {
//                // first zero position filter can not have input from a previous filter
//                imageAttribute.hasFilterInput = true  // flag for parm description
//
//                }
//            }
//        }
    }

    func resetDrawableSize() {
        if let myImageParms = imageParms() {
            for anImageParm in myImageParms {
                anImageParm.resetDrawableSize()
            }
        }


    }


    
    func sourceDescription(attributeKey:String) -> String  {
        if attribute(nameKey: attributeKey) != nil
            { return self.localizedName() + "-" + filterName }  // + "-" + sourceAttribute.inputSourceDescription 
        else { return "blank" }

    }

    func setSource(description: String, attributeKey:String) {
        if let sourceAttribute = attribute(nameKey: attributeKey)
            { sourceAttribute.inputSourceDescription = description }
    }

    func backgroundImage() -> CIImage? {
        return valueFor(keyName: kCIInputBackgroundImageKey) as? CIImage
        }

// MARK: Filter Animation frame changes


    func stopAnimation(attributeTarget: PGLFilterAttribute) {
        
        if attributeTarget.attributeValueDelta != nil {
                   // stop the animation

            attributeTarget.attributeValueDelta = nil
                // turns off animation at the attribute

                // MARK: Fix set the filter level dt here
               animationAttributes.removeAll { (anAttribute: PGLFilterAttribute) -> Bool in
                   anAttribute.attributeName == attributeTarget.attributeName
                   }
                hasAnimation = ( animationAttributes.count > 0 )
            attributeTarget.postVaryTimerOff()
            attributeTarget.varyState = .Initial
               }
    }

    func startAnimation(attributeTarget: PGLFilterAttribute) {

        // start the animation
        startAnimationBasic(attributeTarget: attributeTarget)
        attributeTarget.setAnimationTimerDt(lengthSeconds: (Float(defaultDt) * 1000))
        // 5 seos = defaultDt .005 * 1000 = 5.0
//        attributeTarget.attributeValueDelta = Float(dt ) // default rate of change from the filter
//        }
    }

    func
    startAnimationBasic(attributeTarget: PGLFilterAttribute) {
        // assumes the animation vars are set either from the UI
        // or on a read from the db

        hasAnimation = true
        animationAttributes.append(attributeTarget)
        attributeTarget.postVaryTimerRunning()
    }



    func removeWrapperFilter() {

        if let faceDetector = detectors.first {
            faceDetector.releaseTargetAttributes()
        }
            wrapper?.releaseWrapper()
            wrapper = nil
       hasAnimation = false
        
    }

    func setWrapper(outputFilter: PGLDissolveWrapperFilter, detector: any PGLDetection) {

//        output.setImageAnimation()
        wrapper = outputFilter
        detector.setOutputAttributes(wrapperFilter: outputFilter)
        detectors.append(detector)
        let startImage = inputImage()
        setDetectorsInput(startImage, nil)
        outputFilter.updateInputs(detector: detector)
        // gets 2 images for the dissolve: input and target
        outputFilter.detectorFilter = detector
            // output will trigger to detector when
            // an image should change
           // change at dissolve rate increment when offscreen
    }

    func stopAllAnimation() {
        for animationAttribute in animationAttributes {
            stopAnimation(attributeTarget: animationAttribute)
            // this triggers the needsRedraw flag for varyRunning to false
        }
    }
    func animate(attributeTarget: PGLFilterAttribute) {
        // put the attribute into receiver array for addStepTime and increment messages
//         fatalError("animate(attributeTarget: is replaced by stop start methods")
        if hasAnimation {
            stopAnimation(attributeTarget: attributeTarget)
        }
        else {
            startAnimation(attributeTarget: attributeTarget)
        }

    }

    func attribute(removeAnimationTarget: PGLFilterAttribute) {
        // remove the attribute from the receiver array for addStepTime and increment messages
        // a duplicate of the remove logic in animateTarget..
        // delete this method??
        removeAnimationTarget.attributeValueDelta = nil // stop animation logic
        animationAttributes.removeAll { (anAttribute: PGLFilterAttribute) -> Bool in
            anAttribute.attributeName == removeAnimationTarget.attributeName
        }
        hasAnimation = !animationAttributes.isEmpty
            // keep the var and the lower level animationAttributes in sync
        removeAnimationTarget.postVaryTimerOff() 
    }

     func updateImageVideoFrames() {
        if let existingImageParms = imageParms() {
            for anImageParm in existingImageParms {
                anImageParm.updateVideoFrame()
            }
        }
    }
    
    func addFilterStepTime() {
        // called on every frame
        // this does not send the increment message to the inputImage parm.
        // use PGLTransitionFilter for imageList image increment .
        
//        wrapper?.addStepTime() // usually nil so not sent
        
        if hasAnimation {
            if (stepTime > 1.0) || (stepTime < -1.0) {
                dt = dt * -1
                    // maybe just set to -1.0 or 1.0.. multiply may be slightly over the 1 value.
                
                for aDetector in detectors {
                    aDetector.increment()  // advances to the next feature
                }
            }
            // go back and forth between -1.0 and 1.0
            // toggle dt either neg or positive
            stepTime += dt
                /*! @abstract Interpolates smoothly between 0 at edge0 and 1 at edge1
                 *  @discussion You can use a scalar value for edge0 and edge1 if you want
                 *  to clamp all lanes at the same points.
                             let inputTime = simd_smoothstep(-1.0, 1, stepTime)
                 */
            let inputTime = stepTime
            for aDetector in detectors {
                aDetector.setInputTime(time: Double(inputTime)) 
            }
            for parm in animationAttributes {
                parm.addAnimationStepTime()
                }
        }
        updateImageVideoFrames()


    }

    func setTimerDt(lengthSeconds: Float) {
        // empty implementation
        // see PGLTransitionFilter implementation
        // attributes have independent timer cycle for the Vary
        // this is for timerLoops at the filter level (ie. TransitionFilters)

    }

   

    func setImageListClone(imageList: PGLImageList, sourceKey: String) {
        // empty implementation
        // PGLTransitionFilter subclass will  clone cycleStack to other parms

    }

// MARK: swipeCell action
    @MainActor func cellFilterAction(stackController: PGLStackController, indexPath: IndexPath) -> [UIContextualAction] {

        // does NOT use the attribute system with dispatch of PGLTableCellAction
        // this is simple case for filters.
        // override for special filters - i.e. PGLRandomFilterMaker
        var contextActions = [UIContextualAction]()
        var myAction: UIContextualAction!

        myAction = UIContextualAction(style: .normal, title: NSLocalizedString("Open", comment: "Swipe action label")) { [weak self] (_, _, completion) in
            guard self != nil
                       else { return  }
            stackController.appStack.viewerStack.activeFilterIndex = indexPath.row
               // not needed? viewerStack may change.. row is not the index (indented issue on child stack)

           // set appStack and stack indexes to the selected filter
           let cellObject = stackController.appStack.flatCellFilters[indexPath.row]

           _ = stackController.appStack.moveTo(filterIndent: cellObject) // this is also setting the activeFilterIndes..

           Logger(subsystem: LogSubsystem, category: LogCategory).info("PGLStackController trailingSwipeActionsConfigurationForRowAt Open")
                stackController.segueToParmController()
                completion(true)
               }
        contextActions.append(myAction)
        
        myAction = UIContextualAction(style: .normal, title: NSLocalizedString("Change", comment: "Swipe action label")) { [weak self] (_, _, completion) in
            guard self != nil
               else { return  }

            stackController.appStack.viewerStack.activeFilterIndex = indexPath.row
               // not needed? viewerStack may change.. row is not the index (indented issue on child stack)

           Logger(subsystem: LogSubsystem, category: LogCategory).info("PGLStackController trailingSwipeActionsConfigurationForRowAt Change ")
           // set appStack and stack indexes to the selected filter
           let cellObject = stackController.appStack.flatCellFilters[indexPath.row]

           _ = stackController.appStack.moveTo(filterIndent: cellObject) // this is also setting the activeFilterIndes..
            stackController.appStack.setFilterChangeModeToReplace()
               // this is passed to the filterController
               // in the segue

            // if StackController is in the container then the container should
            // perform the segue to the filterImageContainer..
            //
            var filterSegue  = "showFilterController"
            if stackController.parent is PGLStackImageContainerController {
                filterSegue = "showFilterImageContainer"
            }
            stackController.performSegue(withIdentifier: filterSegue , sender: nil)
                 // show segue showFilterController opens the PGLFilterTableController
                 // set the stack activeFilter


           completion(true)
       }
        contextActions.append(myAction)


        myAction = UIContextualAction(style: .normal, title: NSLocalizedString("Delete", comment: "Swipe action label")) { [weak self] (_, _, completion) in
            guard self != nil
                       else { return  }
           Logger(subsystem: LogSubsystem, category: LogCategory).info("PGLStackController trailingSwipeActionsConfigurationForRowAt Delete")
                stackController.removeFilter(indexPath: indexPath)
                completion(true)
               }
        contextActions.append(myAction)



        return contextActions
    }

}


//extension PGLSourceFilter : Equatable {
//    static func == (lhs: PGLSourceFilter, rhs: PGLSourceFilter) {
//        filter
//
//    }
//}
















