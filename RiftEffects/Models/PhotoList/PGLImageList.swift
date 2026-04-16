//
//  PGLImageList.swift
//  Glance
//
//  Created by Will on 1/27/19.
//  Copyright © 2019 Will. All rights reserved.
//

import Foundation
import UIKit
import Photos
import CoreImage
import Accelerate

enum NextElement {
    case even
    case odd
    case each
}

let PrintDebugPhotoLocation = false
@MainActor
class PGLImageList: @preconcurrency CustomStringConvertible {
    // array of CIImage with current position
    // increment will move forward and on the end reverse in opposite direction
    // holds the source of each image in the photoLibrary

    fileprivate func recacheAssetIDs() {
            // objects are assets, they are the metadata from the photolibrary.. not the image
        assetIDs = [String]()
        for anAsset in imageAssets {
            assetIDs.append(anAsset.localIdentifier)

        }
        NSLog(#function + "assetIDS count = \(assetIDs.count)")
    }
    
    var imageAssets = [PGLAsset]() {
        didSet {
            recacheAssetIDs()
        }
    }

        /// local URL for loaded video
    var localVideosURL = [String : URL]() // assetID  as key

    var inputStack: PGLFilterStack? // remove this var? imageParms will have an inputStack.. not the imageList


    var position = 0
//    {
//        didSet {
//            if PGLSourceFilter.LogParmValues { NSLog("PGLImageList position set to  \(position)") }
//        }
//    }

    var targetSize: CGSize { get {
        return TargetSize
        }
    }
//    var contentMode: UIView.ContentMode = UIView.ContentMode.scaleAspectFit

    // storable var
    var assetIDs = [String]()
    var collectionTitle = String()  // imageAssets may have multiple albums
    var nextType = NextElement.each // normally increments each image in sequence

//    var isAssetList = true // hold PGLAssets.. or holds CIImages
    var hasUncachedAssets: Bool {
        get{
           return imageAssets.contains(where: { $0.ciImage  == nil })
        }
    }

    var userSelection: PGLUserAssetSelection?
        // REMOVE - userAssetSelection was to support 3 view controllers to sequence photos..  Now replaced by PGLImageListOverlayView
    var appStack: PGLAppStack?

    // MARK: Init
    init(){
        guard let myAppDelegate =  UIApplication.shared.delegate as? AppDelegate
                        else { Logger(subsystem: LogSubsystem, category: LogCategory).fault ("PGLFilterTableController viewDidLoad fatalError AppDelegate not loaded")
                            return
                    }
        appStack = myAppDelegate.appStack
    }

//    deinit {
//        releaseVars()
//        Logger(subsystem: LogSubsystem, category: LogMemoryRelease).info("\( String(describing: self) + " - deinit" )")
//    }

    /// not used?
    convenience init(localAssetIDs: [String],albumIds: [String]) {

        // this init assumes two matching arrays of same size localId and albumid
        if (localAssetIDs.count != albumIds.count) && (!albumIds.isEmpty) {
            // empty albumIds is possible and okay
            Logger(subsystem: LogSubsystem, category: LogCategory).error ("PGLImageList init fails on localAssetIDs.count != albumIds.count")
        }
        self.init()
        assetIDs = localAssetIDs
        if !assetIDs.isEmpty {
            imageAssets = getAssets(localIds: localAssetIDs, albums: albumIds )

        }



    }

    ///   PHPicker created image selection from #loadImageListFromPicker(results: [PHPickerResult])
    ///   load the selected image assets
    ///    Used by the clone.. the PGLAssets are fully instantiated with images
    convenience init(localPGLAssets: [PGLAsset]) {
        self.init()
        imageAssets = localPGLAssets
        assetIDs = imageAssets.map({ $0.localIdentifier})


    }


    convenience init(localIdentifiers: [String]) {
        // use this when there are no album identfiers
        // ie using the PHPickerViewController which only returns assetIds
        self.init()
//        imageAssets = localPGLAssets
        assetIDs = localIdentifiers
//        let phAssets = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
        //set up imageAssets
        imageAssets = getAssets(localIds: assetIDs, albums: [String]())
        // need to add to the cache
        

    }


    /// demo init for images in the build Assets.xcassets - not in the user photos library
    convenience init(imageFileNames: [String]) {
        self .init()
        fatalError("PGLImageList imageFileNames not yet implemented")

    }


    func releaseVars() {
        // assetsIDs = [String]()
        for anAsset in imageAssets {
            anAsset.releaseVars()
        }

        userSelection?.releaseVars()

        inputStack?.releaseVars()




    }
    static var DeviceIsSimulator: Bool?

    static func isDeviceASimulator() -> Bool {
        if DeviceIsSimulator == nil {
            if let envVar = ProcessInfo.processInfo.environment["DeviceIsSimulator"] {
                DeviceIsSimulator = Bool.init(envVar)
            } else {
                DeviceIsSimulator = false
                    // cache
            }
        }
        return DeviceIsSimulator ?? false
    }
 // MARK: CustomStringConvertible
    var description: String {
           return "PGLImageList assetIDs: \(assetIDs)"
       }

    // MARK: setSelection


    func firstAsset() -> PGLAsset? {
        return imageAssets.first
    }

// MARK: State

    func estimateRunSeconds() -> Double {
        let imageCount: Double = Double(assetIDs.count)
        return imageCount * 0.010
        
    }

    func validateLoad() {
        // raise user message if the asset exists and but no ciImage
        // in limitedLibrary mode the image may not be obtained but the identifier is set


            if hasUncachedAssets {
                // raise user message.. some images will be blank
                DispatchQueue.main.async {
                    guard let window = UIApplication.shared.delegate?.window,
                        let viewController = window?.rootViewController else { return }

                    let message = "The saved photos are not in 'Selected Photos'. Open Settings for Rift-Effex 'Selected Photos' and retry "

                    //  present a new alert

                    let alert = UIAlertController(title: "Photos Not Loaded", message: message, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    let openSettingsAction = UIAlertAction(title: "Settings", style: .default) { _ in
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            // Ask the system to open that URL.
                            UIApplication.shared.open(url, options: [:])
                            }
                        }
                    alert.addAction(openSettingsAction)
                   viewController.present(alert, animated: true)
                }
            }
//        }
    }

    func hasImageStack() -> Bool {
        // will return image from the stack instead of the objects
        return inputStack != nil
    }

    func isSingular() -> Bool {
        // answer true if only one element in the objects
            return maxAssetsOrImagesCount()  == 1
    }

    func isMultiple() -> Bool {
        return maxAssetsOrImagesCount()  > 1
    }

    func maxAssetsOrImagesCount() -> Int {
              return imageAssets.count

      }

      func isEmpty() -> Bool {
           return (imageAssets.isEmpty)
      }

    func isDemoList() -> Bool {
        // if only images in the cache then it is a demo
        // images have been loaded from  build Assets.xcassets - not in the user photos library
        return (imageAssets.isEmpty)

    }

    // MARK: Clone
    func cloneEven(toParm: PGLFilterAttribute) -> PGLImageList {
        // answer copy of self set to increment only even images
        // sets self to increment only odd
//        NSLog("PGLImageList #cloneEven toParm = \(toParm)")
        let newList = PGLImageList(localPGLAssets: imageAssets)
        newList.nextType = NextElement.odd
//        newList.collectionTitle = "Odd-" + self.collectionTitle  // O for Odd
        if isMultiple() {
            newList.position = 1 }

//        newList.cachedImages = self.cachedImages
//        newList.isAssetList = self.isAssetList

        self.nextType = NextElement.even
        self.position = 0 // zero is even number
//        self.collectionTitle = "Even-" + self.collectionTitle  // E for Even

        let oddUserSelection = self.userSelection?.cloneOdd(toParm: toParm)
       
        newList.userSelection = oddUserSelection
        return newList
    }
    func isSameImages(_ other: PGLImageList) -> Bool {
        return self.assetIDs == other.assetIDs
    }

    func clone(toParm: PGLFilterAttribute) -> PGLImageList {
        // answer copy of self
        // as odd

//        NSLog("PGLImageList #clone toParm = \(toParm)")
        let newList = PGLImageList(localPGLAssets: imageAssets)
        newList.nextType = NextElement.each
//        newList.collectionTitle = "Odd-" + self.collectionTitle  // O for Odd
        newList.position = 0
//        newList.cachedImages = self.cachedImages
//        newList.isAssetList = self.isAssetList


        let aClonedSelection = self.userSelection?.cloneAll(toParm: toParm)

        newList.userSelection = aClonedSelection
        return newList
    }

    func moveContentsFrom(_ source: PGLImageList) {

        self.imageAssets.append(contentsOf: source.imageAssets)
        self.assetIDs.append(contentsOf: source.assetIDs)

        // now empty the source
        source.imageAssets.removeAll()
        source.assetIDs.removeAll()
        source.userSelection = nil
        source.position = -1
//        source.cachedImages.removeAll()

    }

    func randomPrune(imageParm: PGLFilterAttribute) {
        // prune randomly from imageAssets and assetIDs
        var allowedAssetCount = 1
        if imageParm.isTransitionFilter {
            allowedAssetCount = PGLDemo.MaxListSize }


        while (assetIDs.count > allowedAssetCount) {
            let randomIndex = Int.random(in: 0 ..< assetIDs.count)
            assetIDs.remove(at: randomIndex)
            imageAssets.remove(at: randomIndex)
            // update userSelection too !
        }
//        setUserSelection(toAttribute: imageParm)
    }
    
    // MARK:  Accessors


    func getAssets(localIds: [String],albums: [String])  -> [PGLAsset] {
        // in limitedAccess mode there are no user albums accessible
        // in this case we do  have the album of the asset
       // this assumes two matching arrays of same size localId and albums
        // modified for empty albums as in the PHPickerViewController path


        let idFetchResult = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
//        if idFetchResult.count == 0 {
//           // do what??
//        }
        let resultIndexSet = IndexSet.init(integersIn: (0..<idFetchResult.count))
        let assetItems = idFetchResult.objects(at: resultIndexSet)
        //return assetItems as! [PGLAsset]
        var pglAssetItems = [PGLAsset]()
        for (index,anItem) in assetItems.enumerated() {
            if (albums.isEmpty) || (index >= (albums.count - 1)) {
                pglAssetItems.append(PGLAsset(anItem, collectionId: nil , collectionLocalTitle: nil))
            } else {

                pglAssetItems.append(PGLAsset(anItem, collectionId: albums[index] , collectionLocalTitle: nil))
                    // PGLAsset will read collectionTitle
            }
        }
        // start caching the assets ??
        let itemsToCache = pglAssetItems
        // The nonisolated(unsafe) annotation tells the compiler that items​To​Cache is safe to send across the concurrency boundary, which is true here since it's a freshly created local array that isn't accessed again after being captured by the Task.
        NSLog("\(#function) start caching \(itemsToCache.count) assets")
        Task {
            await appStack?.photoMgr.startCaching(for: itemsToCache, targetSize: targetSize)
            for item in itemsToCache {
                NSLog("\(#function) startImageRequestTask for localIdentifer \(item.localIdentifier)")
                item.startImageRequestTask()
            }
        }
        return pglAssetItems
    }



    func sourceImageAlbums() -> [String]? {
        var albumIds = [String]()
        let sourceMap = imageAssets.map { ($0.albumId ) }
            // may have nil values
        for element in sourceMap {
                albumIds.append(element)
        }

        if albumIds.isEmpty { return nil} else
        {return albumIds }

    }

    func sourceAssetCollection() -> PHAssetCollection? {
        return userSelection?.sections.first?.value.sectionSource
    }



    func image(atIndex: Int) -> CIImage? {
        NSLog("\(String(describing: self)) image(atIndex: \(atIndex)")
        var answerImage: CIImage?
        if atIndex >= imageAssets.count { return nil }
        let imageAsset = imageAssets[atIndex]
        answerImage = imageAsset.transformedImage()
        NSLog("\(String(describing:  answerImage)) answers for \(imageAsset.localIdentifier)")
        if answerImage != nil {
            return answerImage
        }
        else {
            if imageAsset.isVideo() {
                answerImage =  imageAsset.imageFrom()
                if answerImage != nil {
                    return scaleToFrame(ciImage: answerImage!, newSize: TargetSize)
                }
                else {
                    return CIImage.empty()
                        //                    return nil  // force a retry on the next loop
                }
            }
            return nil
        }
    }


    func normalize3(scaledCIDisparity: CIImage?) -> CIImage? {
        // based upon option 3 answer in
        // https://stackoverflow.com/questions/55433107/how-to-normalize-pixel-values-of-an-uiimage-in-swift/55434232#55434232
        // uses Accelerate func vImageContrastStretch_ARGB8888

        if scaledCIDisparity == nil {
            return scaledCIDisparity
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let cgImage = PGLOffScreenRender().renderCGImage(source: scaledCIDisparity!) else { return nil }

        var format = vImage_CGImageFormat(bitsPerComponent: UInt32(cgImage.bitsPerComponent),
                                          bitsPerPixel: UInt32(cgImage.bitsPerPixel),
                                          colorSpace: Unmanaged.passRetained(colorSpace),
                                          bitmapInfo: cgImage.bitmapInfo,
                                          version: 0,
                                          decode: nil,
                                          renderingIntent: cgImage.renderingIntent)

        var source = vImage_Buffer()
        var result = vImageBuffer_InitWithCGImage(
            &source,
            &format,
            nil,
            cgImage,
            vImage_Flags(kvImageNoFlags))

      

        guard result == kvImageNoError else { return nil }

        defer { free(source.data) }

        var destination = vImage_Buffer()
        result = vImageBuffer_Init(
            &destination,
            vImagePixelCount(cgImage.height),
            vImagePixelCount(cgImage.width),
            32,
            vImage_Flags(kvImageNoFlags))

        guard result == kvImageNoError else { return nil }

        result = vImageContrastStretch_ARGB8888(&source, &destination, vImage_Flags(kvImageNoFlags))
        guard result == kvImageNoError else { return nil }

        defer { free(destination.data) }

        let scaledCGImage =  vImageCreateCGImageFromBuffer(&destination, &format, nil, nil, vImage_Flags(kvImageNoFlags), nil)

//        guard let thisCGoutput = scaledCGImage as? CGImage else { return CIImage.empty() }
        let returnImage = scaledCGImage?.takeRetainedValue() //Gets the value of this unmanaged reference as a managed reference and consumes an unbalanced retain of it.
        return CIImage(cgImage: returnImage! )

    }

        func firstImageIndex() -> Int {
            switch nextType {
            case NextElement.each, NextElement.even:
                return 0
            case NextElement.odd:
                if maxAssetsOrImagesCount()  == 1 {
                    return 0  // only one element have use the zero element
                }
                else { return 1 }
            }
        }
        func first() -> CIImage? {
            if isEmpty() {
                return CIImage.empty() }
            if hasImageStack() { return inputStack?.stackOutputImage(false)}  // needs scaleToFrame??
            let firstIndexValue = firstImageIndex()
            return image(atIndex: firstIndexValue)
                 // may be returning CIImage.empty()


        }

    func firstImageBasic() -> CIImage? {
        // does NOT answer a CIImage.empty() if nil return from the assets
        // does resize same as first()
        let firstIndexValue = firstImageIndex()
        guard let answerImage =  imageAssets[firstIndexValue].imageFrom()
        else {
            imageAssets.remove(at: firstIndexValue)
            // no image  so need to reset
            return nil }
        return answerImage
//        if doResize {
//            return self.scaleToFrame(ciImage: answerImage, newSize: TargetSize) }
//        else { return answerImage}


    }

       fileprivate func scaleToFrame(ciImage: CIImage, newSize: CGSize) -> CIImage {
           // make all the images scale to the same size and origin

           let xTransform:CGFloat = 0.0 - ciImage.extent.origin.x
           let yTransform:CGFloat = 0.0  - ciImage.extent.origin.y
           //move to zero
           let translateToZeroOrigin = CGAffineTransform.init(translationX: xTransform, y: yTransform)

           let sourceExtent = ciImage.extent
           let xScale = newSize.width / sourceExtent.width
           let yScale =  newSize.height / sourceExtent.height
           let scaleTransform = CGAffineTransform.init(scaleX: xScale, y: yScale)

           return ciImage.transformed(by: translateToZeroOrigin.concatenating(scaleTransform))

       }


    // MARK: Updates
    func append(newImage: PGLAsset) {
        imageAssets.append(newImage)
        // this will add to the cachedImages as it gets to the
        // missing cache point

    }

    func append(assets: [PGLAsset]) {
        imageAssets.append(contentsOf: assets)
        recacheAssetIDs()
            // this will add to the cachedImages as it gets to the
            // missing cache point
    }

    func insert(newAssets: [PGLAsset], startingIndex: Int) {

//        let oldEndingIndex = imageAssets.count - 1
        imageAssets.insert(contentsOf: newAssets, at: startingIndex)
        recacheAssetIDs()
    }

    /// assumes  adding to the end of the current cached image values

    func getCurrentImage() -> CIImage {
        if let myCurrentImage =  image(atIndex: position) {
            return myCurrentImage
        } else {
            return CIImage.empty()
        }
    }

    func increment() -> CIImage? {
        if hasImageStack() { return inputStack?.stackOutputImage(false)} // needs scaleToFrame??
        if isEmpty() {return nil } // guard
        if maxAssetsOrImagesCount()  == 1 { return first() } // guard - nothing to increment
             // at zero assumes first object already shown

//      NSLog("PGLImageList nextType = \(nextType) #increment start position = \(position)")

        if nextType == NextElement.each {
            position = position + 1 }
        else { position = position + 2 } // skip by 2 }

        if position >= maxAssetsOrImagesCount()  {
            // start over
            switch nextType {
                case  NextElement.each :
                    position = 0

                case  NextElement.odd :
                    position = 1

                case NextElement.even :
                    position = 0
            }
        }
//        if position >= imageAssets.count { position = 0 }
        let answerImage =  image(atIndex: position)
//         NSLog("PGLImageList nextType = \(nextType) #increment end position = \(position)")
        return answerImage
    }


/// answer true if imageCache is reset
/// answers false if the there is nothing to cache i.e. demo images
    func resetCenteredImageCache() -> Bool {

            // global TargetSize has changed
            // images should be resized/centered again
            // set cachedImages to  empty and they will resize as accessed
        if (isDemoList() || isEmpty() ) {
                // no imageAssets exist only the cachedImages..
                // so don't clear the cache
            return false
        } else {
            for thisAsset in imageAssets {
                thisAsset.resetCenterScaler()
            }

            return true
        }
    }


    // MARK: Editing - remove, reorder
    /// three parallel vars to update   the dictionary of cachedImages, the imageAssets [PGLAsset]  array and the assetIDs array of localIdentifiers
    func removeImage(at index: Int) {
        imageAssets.remove(at: index)
    }

    func removeAll() {
        imageAssets.removeAll()
//        cachedImages.removeAll()

    }

    func moveContentsFrom(fromOffsets: IndexSet, toOffset destination: Int) {
        imageAssets.move(fromOffsets: fromOffsets, toOffset: destination)

    }


    // MARK: Video
    func currentImageIsVideo() -> Bool {
        // position in zero based array needs offset
        var thisImageAsset: PGLAsset
        if !(position < imageAssets.count) {
            //  bail out position should be incremented in another pass.
            return false
        }
        switch imageAssets.count {
            case 0:
                return false
            case 1:
                // in this case the PGLImageList position is 1
                // but zero based array
                thisImageAsset = imageAssets.first!
            default:
                // now position is correct for more than one imageAsset
                thisImageAsset = imageAssets[position]
        }
        return thisImageAsset.isVideo()

    }

}

