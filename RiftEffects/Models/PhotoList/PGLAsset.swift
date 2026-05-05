//
//  PGLImageSourcePath.swift
//  Glance
//
//  Created by Will on 2/20/20.
//  Copyright © 2020 Will Loew-Blosser. All rights reserved.
//

import Foundation
import UIKit
import Photos
import CoreImage
import os



struct PGLDevicePosition {
    var orientation: UIInterfaceOrientation = .unknown
    var device: AVCaptureDevice.Position = .unspecified
}

@MainActor
class PGLAsset: Hashable, Equatable, Identifiable {
    // a wrapper object around PHAsset
       // holds the sourceInfo so it can be displayed
       // does this cause any caching memory problems??
       // because the assetCollection is held??
       // other option is to capture localIdentifier & title only
    nonisolated(unsafe) var asset: PHAsset

    // sourceInfo not needed.. PHAsset.fetchAssets(withLocalIdentifiers already set
    lazy var sourceInfo: PHAssetCollection? =
        { let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumId], options: nil)
            return fetchResult.firstObject
                // may be nil
        }()
           // remove this after albumId & album title are implemented

    var albumId: String  // must have an albumId
    var collectionTitle = String()
    var isSelected = false


    // video
    var assetVideo: PGLAssetVideoPlayer?

    let localIdentifier: String

    nonisolated var id: String { return localIdentifier }
        // return ObjectIdentifier(self) }

    var cache: PGLCachedImageMgr?
    private var imageRequestID: PHImageRequestID?
     var thumbnail: UIImage?
  private var ciImage: CIImage?
    var centerScaler: PGLCenterScaler?
//    var imageScaler: PGLImageScaler?
    var onImageReady: ((CIImage) -> Void)?

    let thumbnailSize: CGSize = CGSize(width: 100, height: 100)

    // MARK: Hash, Equatable
    nonisolated static func == (lhs: PGLAsset, rhs: PGLAsset) -> Bool {
       return lhs.localIdentifier == rhs.localIdentifier
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(localIdentifier)
    }


// MARK: init


    init(_ sourceAsset: PHAsset, collectionId: String?, collectionLocalTitle: String?) {
        if collectionId == nil
          {  albumId = "" }
        else { albumId = collectionId! }
        asset = sourceAsset
        localIdentifier = asset.localIdentifier

        guard let myAppDelegate =  UIApplication.shared.delegate as? AppDelegate
                        else { Logger(subsystem: LogSubsystem, category: LogCategory).fault ("PGLFilterTableController viewDidLoad fatalError AppDelegate not loaded")
                            return
                    }
        cache = myAppDelegate.appStack.photoMgr

    }

    convenience init(sourceAsset: PHAsset, sourceCollection: PHAssetCollection) {
        self.init(sourceAsset, collectionId: sourceCollection.localIdentifier, collectionLocalTitle: sourceCollection.localizedTitle)
        sourceInfo = sourceCollection
    }

    convenience init(sourceAsset: PHAsset) {
        self.init(sourceAsset, collectionId: nil, collectionLocalTitle: nil)
    }

    @MainActor func releaseVars() {

        sourceInfo = nil
        assetVideo?.releaseVars()

        }


    func isNull() -> Bool {
        return  asset.localIdentifier.hasPrefix("(null)/")
            // "(null)/L0/001" is error string
    }

    func assetIdAlbumId() -> (assetId: String, albumId: String) {
        return (assetId: localIdentifier, albumId: albumId)
    }



    static let ImageLogger = OSLog(subsystem: "com.apple.Photos", category: "PGLAsset")
    // MARK: Image
    /// return the CIImage
    /// moved from the PGLImageList
    @MainActor
    func imageFrom() -> CIImage? {
        // • When self​.image is already cached (from a previous request), it's immediately converted via convert2​CIImage() and returned as a CIImage
//        • The Task to fetch from the cache only fires when image is nil (first call)
//        • On the first call it still returns nil, but once the async fetch completes and sets self​.image, subsequent calls will return the converted CIImage

//        os_signpost(.begin, log: PGLAsset.ImageLogger, name: "imageFrom")
//        defer {
//            os_signpost(.end, log: PGLAsset.ImageLogger, name: "imageFrom")
//        }
        if isVideo() {
            if assetVideo != nil {

                if let answerFrame = assetVideo?.imageFrom() {
                    return answerFrame
                } // else continue to read the PHImageManager still frame
            }
        }

        if let myCIImage = ciImage {
            return myCIImage
        }


        return nil
               // nil on first call; image will be available on subsequent calls
      } // end imageFrom()

   

        /// convert UIImage to CIImage and correct orientation to downMirrored
    @MainActor func convert2CIImage(aUIImage: UIImage) -> CIImage? {
            var pickedCIImage: CIImage?

            if let convertedImage = CoreImage.CIImage(image: aUIImage ) {

             let theOrientation = CGImagePropertyOrientation(aUIImage.imageOrientation)
             if PGLImageList.isDeviceASimulator() {
                     pickedCIImage = convertedImage.oriented(CGImagePropertyOrientation.downMirrored)
                 } else {
//                     NSLog("PGLAsset #convert2CIImage theOrientation = \(theOrientation)")
                     pickedCIImage = convertedImage.oriented(theOrientation) }
             }
            return pickedCIImage
        }

    func imageAtTargetSize() -> CIImage?
    {    guard self.imageFrom() != nil else
            { return  nil }

        if let myCI = self.ciImage {
            return self.centerScaler?.imageForTargetSize(image: myCI)
        } else {
            return nil
        }

    }

    func startImageRequestTask()  {
        Task {
            guard let cache = cache else { return }
//            NSLog(#function, #line)
            imageRequestID = await cache.requestImage(for: self, targetSize: TargetSize) { @Sendable result in
                Task { @MainActor in
//                    NSLog("\(#function) process: \(ProcessInfo.processInfo.processName) time: \(Date()) result: \(String(describing: result))")
                    if let result = result {
                        if let returnUIImage = result.image {
                            NSLog("\(#function) image recevied for \(self.asset.localIdentifier)")
                            self.thumbnail = returnUIImage.preparingThumbnail(of: self.thumbnailSize)
                            self.ciImage = self.convert2CIImage(aUIImage: returnUIImage)

                            self.centerScaler = self.setCenterScaler(to: self.ciImage!)
                            if let ciImage = self.ciImage {
                                if let resizedImage = self.imageAtTargetSize() {
                                    self.onImageReady?(resizedImage) }
                                else {
                                    self.onImageReady?(ciImage) }

                                }
                            }

                        }
                    }  // child TASK close
                }
            } // parent TASK close
    }

    func imageNotAvailable() -> Bool {
        // ciImage is private just return status 
       return ciImage == nil
    }

    func resetCenterScaler() {
        if ciImage == nil { return }
        centerScaler = setCenterScaler(to: ciImage!)
        NSLog("\(#function) centerScaler: \(String(describing: centerScaler))")
        // now update ciImage with the scaler
        
    }

    func setCenterScaler(to ciImage: CIImage) -> PGLCenterScaler? {
        let newCenterScaler = PGLCenterScaler(centerCIImage: ciImage)
    // comment PGLImageScaler is just a struct that holds the transformed image

//        let centeredImage = centerScaler.displayTransform(image: ciImage)
//        let myScaler = PGLImageScaler(image: centeredImage, centerScaler: centerScaler)
        return newCenterScaler

        
    }
//    func setImageLoad(attribute: PGLFilterAttribute, completionHandler: { }()->Void )

    func uiImage() -> UIImage? {
        return thumbnail

    }



    //MARK: Video
    func isVideo() -> Bool {
        return asset.mediaType == .video
    }


    @MainActor  func requestVideo() {
        assetVideo = PGLAssetVideoPlayer(parentAsset: self)
        assetVideo?.setUpVideoPlayAssets()

    }

}
