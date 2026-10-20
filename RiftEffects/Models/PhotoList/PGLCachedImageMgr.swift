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
        guard let phAsset = asset.asset
            else {
                // transient picker-only asset - use #loadImage(from:)
                completion(nil)
                return nil
            }
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
    
    /// Request one image and answer the PHImageManager error instead of only logging it.
    ///
    /// #requestImage(for:targetSize:completion:) reports every failure as nil. This
    /// variant keeps the PHImageErrorKey error so diagnostics (the cloud import tests)
    /// can report why an asset did not load. A degraded (lower quality) callback is
    /// skipped - the continuation resumes only on the final callback.
    func requestImageResult(for asset: PGLAsset, targetSize: CGSize) async -> Result<UIImage, CachedImageManagerError> {
        guard let phAsset = asset.asset else { return .failure(.failed) }
        return await withCheckedContinuation { continuation in
            imageManager.requestImage(for: phAsset, targetSize: targetSize, contentMode: imageContentMode, options: requestOptions) { image, info in
                if let error = info?[PHImageErrorKey] as? (any Error) {
                    continuation.resume(returning: .failure(.error(error)))
                } else if let cancelled = (info?[PHImageCancelledKey] as? NSNumber)?.boolValue, cancelled {
                    continuation.resume(returning: .failure(.cancelled))
                } else if (info?[PHImageResultIsDegradedKey] as? NSNumber)?.boolValue ?? false {
                    return // the final image follows in another callback
                } else if let image = image {
                    continuation.resume(returning: .success(image))
                } else {
                    continuation.resume(returning: .failure(.failed))
                }
            }
        }
    }

    /// Load a picker-only image. In limited library mode a photo picked outside the
    /// allowed selection has no PHAsset, only the PHPickerResult item provider.
    /// Not cached by the PHCachingImageManager; the PGLAsset keeps the decoded ciImage.
    /// nonisolated - no actor state is used and the non-Sendable provider stays with the caller.
    nonisolated func loadImage(from provider: NSItemProvider, completion: @escaping @Sendable (UIImage?) -> Void) {
        guard provider.canLoadObject(ofClass: UIImage.self) else {
            completion(nil)
            return
        }
        provider.loadObject(ofClass: UIImage.self) { object, error in
            if let error = error {
                logger.error("CachedImageManager loadImage error: \(error.localizedDescription)")
            }
            completion(object as? UIImage)
        }
    }

    func cancelImageRequest(for requestID: PHImageRequestID) {
        imageManager.cancelImageRequest(requestID)
    }
}

fileprivate let logger = Logger(subsystem: "com.apple.swiftplaygroundscontent.capturingphotos", category: "CachedImageManager")

