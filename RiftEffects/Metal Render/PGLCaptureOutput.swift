//
//  PGLCaptureOutput.swift
//  RiftEffects
//
//  Created by Will on 5/6/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//

import Foundation
import Photos
import AVFoundation

@MainActor
class PGLCaptureOutput {

    var currentTime = CMTime.zero
    var frameCount: Int = 0
    var maxFrames = 5
    let videoPath = FileManager.default.temporaryDirectory.appendingPathComponent("video.mov")
    var writerInput: AVAssetWriterInput!
    var writer: AVAssetWriter!
    var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    let framesPerSecond: Int = 30
    var metalContext: CIContext!

    init(context: CIContext, size: CGSize) {
        self.metalContext = context

        if FileManager.default.fileExists(atPath: videoPath.path) {
            do {
                try FileManager.default.removeItem(atPath: videoPath.path)
            } catch {
                fatalError("Unable to delete file: \(error) : \(#function).")
            }
        }

        writer = try? AVAssetWriter(outputURL: videoPath, fileType: .mov)
        if writer == nil {
             fatalError("AVAssetWriter error")
        }

        let settings = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: NSNumber(value: Float(size.width)),
            AVVideoHeightKey: NSNumber(value: Float (size.height ))
            ] as [String : Any]
        guard writer.canApply(outputSettings: settings, forMediaType: .video) else
        {
           fatalError("Cannot apply output settings to AVAssetWriter")
             }
        writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)

        let sourcePixelBufferAttributes =
            [
                (kCVPixelBufferPixelFormatTypeKey as String) : kCVPixelFormatType_32RGBA,
                (kCVPixelBufferWidthKey as String) : NSNumber(value: Float(size.width)),
                (kCVPixelBufferHeightKey as String) :  NSNumber(value: Float(size.height)),
            ]   as [String : Any]

        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: sourcePixelBufferAttributes)
        if writer.canAdd(writerInput) {
            writer.add(writerInput)
        }

        if writer.status == .failed {
            NSLog ("AVAssetWriter failed to initialize: \(writer.error?.localizedDescription ?? "Unknown error")") }

        let writeSuccess = writer.startWriting()
        if writeSuccess {
            NSLog ("AVAssetWriter started writing")
            writer.startSession(atSourceTime: CMTime.zero)
            assert(writer.status == .writing)
            assert(pixelBufferAdaptor.pixelBufferPool != nil)
        } else {
//                NSLog ("AVAssetWriter failed status : \(writer.status ?? "Unknown error")")
            NSLog ("AVAssetWriter failed to start writing: \(writer.error?.localizedDescription ?? "Unknown error")")

        }

    }


    func addFrame(_ frame: CIImage) -> Bool {

        if frameCount < maxFrames {
            addVideoFrame(frame)
            NSLog("Saving still image")
        } else {
                // save the video to photoLibrary
            finishVideo()
            NSLog("Saving video to photo library")
            }
        // add the video frame
        let shouldContinue = addFrameCount()
        return shouldContinue
    }


    func addFrameCount() -> Bool {
        frameCount = frameCount + 1
        if frameCount > maxFrames {
            frameCount = 0
            return false
        } else {
            return true
        }
    }

    func finishVideo() {

        Task { [writer, videoPath] in
            guard let localWriter = writer else { return }
            let localVideoPath = videoPath
            writerInput.markAsFinished()
            await localWriter.finishWriting()

            createLivePhoto(videoURL: localVideoPath) { livePhoto in
                guard let livePhoto = livePhoto else {
                    print("Failed to create Live Photo")
                    return
                }

                PHPhotoLibrary.shared().performChanges {
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    let options = PHAssetResourceCreationOptions()

        //            creationRequest.addResource(with: .photo, fileURL: photoURL, options: options)
                    creationRequest.addResource(with: .fullSizeVideo, fileURL: localVideoPath, options: options)
                }
//                { success, error in
//                    if success {
//                        print("Live Photo saved successfully")
//                    } else if let error = error {
//                        print("Error saving Live Photo: \(error.localizedDescription)")
//                    }
//
//                }

//                saveToPhotos(videoURL: localVideoPath, completion: { success, error in
//                    if success {
//                        print("Live Photo saved successfully")
//                    } else if let error = error {
//                        print("Error saving Live Photo: \(error.localizedDescription)")
//                    }
//                })

            }

        }  // end task

    }

    func addVideoFrame(_ frame: CIImage) -> Void {

            let frameDuration = CMTime(value: 1, timescale: CMTimeScale(framesPerSecond))

            var pixelBuffer: CVPixelBuffer? = nil
            if pixelBufferAdaptor.pixelBufferPool == nil {
                print("Failed to create pixel buffer: pixelBufferPool is nil")
                return
                    //                pixelBufferAdaptor.pixelBufferPool = createPixelBufferPool()
            }

            let status = CVPixelBufferPoolCreatePixelBuffer(
                kCFAllocatorDefault,
                pixelBufferAdaptor.pixelBufferPool!,
                &pixelBuffer
            )

            if status == kCVReturnSuccess, let pixelBuffer = pixelBuffer {
                let managedPixelBuffer = pixelBuffer
                CVPixelBufferLockBaseAddress(managedPixelBuffer, [])
                metalContext.render(frame, to: pixelBuffer)
                CVPixelBufferUnlockBaseAddress(managedPixelBuffer, [])
                pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: currentTime)
            } else {
                print("Failed to create pixel buffer: \(status)")
            }

    }

//     Combine the still image and video into a LivePhoto
    func createLivePhoto( videoURL: URL, completion: @escaping (PHLivePhoto?) -> Void) {
        PHLivePhoto.request(withResourceFileURLs: [ videoPath], placeholderImage: nil, targetSize: TargetSize, contentMode: .aspectFit) { livePhoto, info in
            completion(livePhoto)
        }
    }

    // Save LivePhoto to Photos Library
//    func saveToPhotos(photoURL: URL, videoURL: URL, completion: @escaping (Bool, (any Error)?) -> Void) {
//    func saveToPhotos( videoURL: URL, completion: @escaping (Bool, (any Error)?) -> Void) {
//
//        completionHandler:  (success, error) in
//           completion(success, error)
//
//    }

//    func createPixelBufferPool() -> CVPixelBufferPool? {
//            // Step 1: Define pixel buffer attributes
//            let pixelBufferAttributes: [String: Any] = [
//                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
//                kCVPixelBufferWidthKey as String: 1920,
//                kCVPixelBufferHeightKey as String: 1080,
//                kCVPixelBufferIOSurfacePropertiesKey as String: [:] // Required for Metal compatibility
//            ]
//
//            // Step 2: Create the pixel buffer pool
//            var pixelBufferPool: CVPixelBufferPool?
//            let poolAttributes: [String: Any] = [
//                kCVPixelBufferPoolMinimumBufferCountKey as String: 5 // Minimum number of buffers
//            ]
//            let status = CVPixelBufferPoolCreate(
//                kCFAllocatorDefault,
//                poolAttributes as CFDictionary,
//                pixelBufferAttributes as CFDictionary,
//                &pixelBufferPool
//            )
//
//            guard status == kCVReturnSuccess, let pool = pixelBufferPool else {
//                fatalError("Failed to create pixel buffer pool: \(status)")
//            }
//
//            // Step 3: Create a pixel buffer from the pool
//            var pixelBuffer: CVPixelBuffer?
//            let bufferStatus = CVPixelBufferPoolCreatePixelBuffer(
//                kCFAllocatorDefault,
//                pool,
//                &pixelBuffer
//            )
//
//            if bufferStatus == kCVReturnSuccess, let buffer = pixelBuffer {
//                // Use the pixel buffer (e.g., render into it or process it)
//                print("Pixel buffer created successfully")
//            } else {
//                print("Failed to create pixel buffer: \(bufferStatus)")
//            }
//            return pixelBufferPool
//
//    }



}
