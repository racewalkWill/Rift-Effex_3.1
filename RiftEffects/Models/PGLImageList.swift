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

var PrintDebugPhotoLocation = false

class PGLImageList: CustomStringConvertible {
    // array of CIImage with current position
    // increment will move forward and on the end reverse in opposite direction
    // holds the source of each image in the photoLibrary

    var imageAssets = [PGLAsset]() {
        didSet {
            // objects are assets, they are the metadata from the photolibrary.. not the image
            assetIDs = [String]()
            for anAsset in imageAssets {
                assetIDs.append(anAsset.localIdentifier)
//                if anAsset.isVideo() {
//                    postVideoAnimationToggleOn(imageAsset: anAsset)
//                }
            }
        }
    }

        /// local URL for loaded video
    var localVideosURL = [String : URL]() // assetID  as key

    var inputStack: PGLFilterStack? // remove this var? imageParms will have an inputStack.. not the imageList


    var position = 0 {
        didSet {
            NSLog("PGLImageList position set to  \(position)")
        }
    }
    var targetSize: CGSize { get {
        return TargetSize
        }
    }
    
    // storable var
    var assetIDs = [String]()
    var collectionTitle = String()  // imageAssets may have multiple albums
    var nextType = NextElement.each // normally increments each image in sequence

//    var isAssetList = true // hold PGLAssets.. or holds CIImages
    var isAssetList: Bool {
        get{
//            return images.isEmpty && !imageAssets.isEmpty
            // iPhone picker loads one image but still call this an assetList

            return (images.count < imageAssets.count) && !imageAssets.isEmpty
            // when all the images are cached in images then isAssetList is false.
        }
    }
    private var images = [CIImage?]()
    let doResize = MainViewImageResize  // working on scaling... boolean switch here
     var userSelection: PGLUserAssetSelection?
     // was weak var userSelection...
    
    // MARK: Init
    init(){



    }

    deinit {
        releaseVars()
//        Logger(subsystem: LogSubsystem, category: LogMemoryRelease).info("\( String(describing: self) + " - deinit" )")
    }

    /// not used?
    convenience init(localAssetIDs: [String],albumIds: [String]) {
        //  Remove
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

    }

    convenience init(ciImages: [CIImage]) {
        self .init()
        images  =  ciImages

    }

    /// demo init for images in the build Assets.xcassets - not in the user photos library
    convenience init(imageFileNames: [String]) {
        self .init()
       let uiImages = UIImage.uiImages(imageFileNames)
        for anUIImage in uiImages {
            images.append(convert2CIImage(aUIImage: anUIImage))
                // convert2CIImage will correct orientation to downMirrored
        }

    }


    func releaseVars() {
        // assetsIDs = [String]()
        for anAsset in imageAssets {
            anAsset.releaseVars()
        }
        images = [CIImage?]()
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
           return "\(assetIDs), \(images)"
       }

    // MARK: setSelection
    func setUserSelection(toAttribute: PGLFilterAttribute  ){
        // create a PGLUserSelection object from
        // the imageAssets
//        var newbie: PGLUserAssetSelection

        if let firstAsset = imageAssets.first {
            Logger(subsystem: LogSubsystem, category: LogCategory).debug("PGLImageList #setUserSelection set firstAsset")
            let thisAlbumSource = firstAsset.asPGLAlbumSource(onAttribute: toAttribute)

            let newbie = PGLUserAssetSelection(assetSources: thisAlbumSource)


     for nextAsset in imageAssets {
//            for nextAsset in imageAssets.suffix(from: 1) {
               newbie.append(nextAsset)
            }
            userSelection = newbie
        }
    }

    func firstAsset() -> PGLAsset? {
        return imageAssets.first
    }

// MARK: State
    func validateLoad() {
        // raise user message if the identifier and image count is not equal
        // in limitedLibrary mode the image may not be obtained but the identifier is set
        if !isAssetList {
            // no images but imageAssets exist - should load okay
            let imageCount = images.count
            let identifierCount = assetIDs.count

            if imageCount != identifierCount {
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
        }
    }

    func hasImageStack() -> Bool {
        // will return image from the stack instead of the objects
        return inputStack != nil
    }

    func isSingular() -> Bool {
        // answer true if only one element in the objects
            return maxAssetsOrImagesCount()  == 1
    }

    func maxAssetsOrImagesCount() -> Int {
          if isAssetList {
              return imageAssets.count
          }
          else {
              return images.count
          }
      }

      func isEmpty() -> Bool {
           return (imageAssets.isEmpty) && (images.isEmpty)
      }

    // MARK: Clone
    func cloneEven(toParm: PGLFilterAttribute) -> PGLImageList {
        // answer copy of self set to increment only even images
        // sets self to increment only odd
//        NSLog("PGLImageList #cloneEven toParm = \(toParm)")
        let newList = PGLImageList(localPGLAssets: imageAssets)
        newList.nextType = NextElement.odd
//        newList.collectionTitle = "Odd-" + self.collectionTitle  // O for Odd
        newList.position = 1
        newList.images = self.images
//        newList.isAssetList = self.isAssetList

        self.nextType = NextElement.even
        self.position = 0 // zero is even number
//        self.collectionTitle = "Even-" + self.collectionTitle  // E for Even

        let oddUserSelection = self.userSelection?.cloneOdd(toParm: toParm)
       
        newList.userSelection = oddUserSelection
        return newList
    }

    func clone(toParm: PGLFilterAttribute) -> PGLImageList {
        // answer copy of self
        // as odd

//        NSLog("PGLImageList #clone toParm = \(toParm)")
        let newList = PGLImageList(localPGLAssets: imageAssets)
        newList.nextType = NextElement.each
//        newList.collectionTitle = "Odd-" + self.collectionTitle  // O for Odd
        newList.position = 0
        newList.images = self.images
//        newList.isAssetList = self.isAssetList


        let aClonedSelection = self.userSelection?.cloneAll(toParm: toParm)

        newList.userSelection = aClonedSelection
        return newList
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
        setUserSelection(toAttribute: imageParm)
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
        var answerImage: CIImage?

        if !isAssetList {
                // has image in the private cache
                // NO asset to load
            answerImage = images[atIndex]
        }


        else { 
            let imageAsset = imageAssets[atIndex]
            if imageAsset.isVideo() {
                answerImage =  imageAsset.imageFrom()
                if answerImage != nil {
                    return scaleToFrame(ciImage: answerImage!, newSize: TargetSize)
                }
                else {
                    return CIImage.empty()
                }
            }

            if let imageFromAsset = imageAsset.imageFrom() {
                answerImage = imageFromAsset
                if (( images.count - 1 ) < atIndex ) {
                        // save into the images cache.
                        // zero  based array count is one more than the index
                    appendImage(aCiImage: imageFromAsset)
                }
            }
            else {
                return CIImage.empty()
            }
        }
        return scaleToFrame(ciImage: answerImage!, newSize: TargetSize)
    }




    /// convert UIImage to CIImage and correct orientation to downMirrored
    func convert2CIImage(aUIImage: UIImage) -> CIImage? {
        var pickedCIImage: CIImage?

        if let convertedImage = CoreImage.CIImage(image: aUIImage ) {

         let theOrientation = CGImagePropertyOrientation(aUIImage.imageOrientation)
         if PGLImageList.isDeviceASimulator() {
                 pickedCIImage = convertedImage.oriented(CGImagePropertyOrientation.downMirrored)
             } else {

                 pickedCIImage = convertedImage.oriented(theOrientation) }
         }
        return pickedCIImage
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
        if doResize {
            return self.scaleToFrame(ciImage: answerImage, newSize: TargetSize) }
        else { return answerImage}


    }

       fileprivate func scaleToFrame(ciImage: CIImage, newSize: CGSize) -> CIImage {
           // make all the images scale to the same size and origin

           if !doResize {
               return ciImage }
//           NSLog("PGLImageList #scaleToFrame ")
           let xTransform:CGFloat = 0.0 - ciImage.extent.origin.x
           let yTransform:CGFloat = 0.0  - ciImage.extent.origin.y
           //move to zero
           let translateToZeroOrigin = CGAffineTransform.init(translationX: xTransform, y: yTransform)

           let sourceExtent = ciImage.extent
           let xScale = newSize.width / sourceExtent.width
           let yScale =  newSize.height / sourceExtent.height
           let scaleTransform = CGAffineTransform.init(scaleX: xScale, y: yScale)

           return ciImage.transformed(by: translateToZeroOrigin.concatenating(scaleTransform))

           // the CILanczosScaleTransform crops a little too much..
           // it just uses the yScale only
//           let sourceSize = ciImage.extent
//           let scaleBy =  newSize.height / sourceSize.height
//           let aspectRatio = Double(newSize.width) / Double(newSize.height)
//
//           let resizedImage  = ciImage.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputAspectRatioKey: aspectRatio ,
//                       kCIInputScaleKey: scaleBy])
//           return resizedImage

       }


    // MARK: Updates
    func append(newImage: PGLAsset) {
        imageAssets.append(newImage)
        assetIDs.append(newImage.localIdentifier)
//        if newImage.isVideo() {
//            postVideoAnimationToggleOn(imageAsset: newImage)
//        }
    }

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

//      NSLog("PGLImageList nextType = \(nextType) #increment start position = \(position)")


        // at zero assumes first object already shown
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
//                    if position.isEven() {
//                        position = 0
//                    } else { position = 1 }

                case NextElement.even :
                    position = 0
//                    if !position.isEven() {
//                        position = 0
//                    } else { position = 1 }


            }
        }

        let answerImage =  image(atIndex: position)
//         NSLog("PGLImageList nextType = \(nextType) #increment end position = \(position)")
        return answerImage
    }

        func setImages(ciImageArray: [CIImage]) {

            images = ciImageArray

//            let theOrientation = CGImagePropertyOrientation(theImage.imageOrientation)
//            if PGLImageList.isDeviceASimulator() {
//                    pickedCIImage = convertedImage.oriented(CGImagePropertyOrientation.downMirrored)
//                } else {
//
//                    pickedCIImage = convertedImage.oriented(theOrientation) }
//            }
//           if let orientedCIImage = pickedCIImage {
//               selectedImageList.setImage(aCiImage: orientedCIImage, position: 0)
//           }

        }

    func setImage(aCiImage : CIImage, position: Int ) {
        images.insert( aCiImage, at: position)  // this adjusts the arrary size as needed.

    }

    func appendImage(aCiImage: CIImage) {
        images.append(aCiImage)
    }

    // MARK: Video
    func currentImageIsVideo() -> Bool {
        // position in zero based array needs offset
        var thisImageAsset: PGLAsset
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

    
//     does not toggle off.. a whole new imageList is created
//    func postVideoAnimationToggleOff(imageAsset: PGLAsset) {
//        let updateNotification = Notification(name:PGLVideoAnimationToggle)
//        NotificationCenter.default.post(name: updateNotification.name, object: imageAsset, userInfo: ["VideoImageSource" : -1 ])
//    }


}
