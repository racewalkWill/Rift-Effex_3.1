/*
See the License.txt file for this sample’s licensing information.
*/

import UIKit
import Photos
import SwiftUI
import os.log

actor PGLCachedImageMgr {
    
    private let imageManager = PHCachingImageManager()
    
    private var imageContentMode = PHImageContentMode.aspectFit
    
    enum CachedImageManagerError: LocalizedError {
        case error(any Error)
        case cancelled
        case failed
    }
    
    private var cachedAssetIdentifiers = [String : Bool]()
    
    private lazy var requestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        // default settings
//        options.isNetworkAccessAllowed = true
//        options.resizeMode = .fast
//        options.deliveryMode = .opportunistic

        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
//        options.isSynchronous = true
        options.version = .current
        options.resizeMode = PHImageRequestOptionsResizeMode.exact

        return options
    }()



    
    var cachedImageCount: Int {
        cachedAssetIdentifiers.keys.count
    }
    
    func startCaching(for assets: [PGLAsset], targetSize: CGSize) {
        let phAssets = assets.compactMap { $0.asset}
        phAssets.forEach {
            cachedAssetIdentifiers[$0.localIdentifier] = true
        }
        NSLog(#function)
        imageManager.startCachingImages(for: phAssets, targetSize: targetSize, contentMode: imageContentMode, options: requestOptions)
    }

    func stopCaching(for assets: [PGLAsset], targetSize: CGSize) {
        let phAssets = assets.compactMap { $0.asset }
        phAssets.forEach {
            cachedAssetIdentifiers.removeValue(forKey: $0.localIdentifier)
        }
        imageManager.stopCachingImages(for: phAssets, targetSize: targetSize, contentMode: imageContentMode, options: requestOptions)
    }
    
    func stopCaching() {
        imageManager.stopCachingImagesForAllAssets()
    }
    
    @discardableResult
    func requestImage(for asset: PGLAsset, targetSize: CGSize, completion: @escaping ((image: UIImage?, isLowerQuality: Bool)?) -> Void) ->
        PHImageRequestID? {
       let phAsset = asset.asset
//           else {
//                completion(nil)
//                return nil
//            }
        NSLog("PGLCachedImageMgr requestImage: \(phAsset.localIdentifier)")
        let requestID = imageManager.requestImage(for: phAsset, targetSize: targetSize, contentMode: imageContentMode, options: requestOptions) { image, info in
            if let error = info?[PHImageErrorKey] as? (any Error) {
                logger.error("CachedImageManager requestImage error: \(error.localizedDescription)")
                completion(nil)
            } else if let cancelled = (info?[PHImageCancelledKey] as? NSNumber)?.boolValue, cancelled {
                logger.debug("CachedImageManager request canceled")
                completion(nil)
            } else if let image = image {
                let isLowerQualityImage = (info?[PHImageResultIsDegradedKey] as? NSNumber)?.boolValue ?? false
                let result = ( image, isLowerQuality: isLowerQualityImage)
                completion(result)
            } else {
                completion(nil)
            }
        }
        return requestID
    }
    
    func cancelImageRequest(for requestID: PHImageRequestID) {
        imageManager.cancelImageRequest(requestID)
    }
}

fileprivate let logger = Logger(subsystem: "com.apple.swiftplaygroundscontent.capturingphotos", category: "CachedImageManager")

