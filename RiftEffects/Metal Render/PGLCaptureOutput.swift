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
    var maxFrames: Int = 120  // 2 secs at 60 fps
    let videoPath = FileManager.default.temporaryDirectory.appendingPathComponent("video.mov")
    var writerInput: AVAssetWriterInput!
    var writer: AVAssetWriter!
    var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    let framesPerSecond: Int = 60
    var metalContext: CIContext!

    var framesToSave = [CIImage]()

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
            framesToSave.append(frame)
//            NSLog("Saving still image")
        } else {
                // save the video to photoLibrary
                //  finishVideo()
//            NSLog("MaxFrames captured ")

            saveVideoToLibrary(outputSize: TargetSize,
                               inContext: metalContext, framesToSave: framesToSave)
            framesToSave = [CIImage]() // clear the frame capture
//            NSLog("Saving video to photo library")
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
                guard livePhoto != nil else {
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



    func saveVideoToLibrary(outputSize: CGSize, inContext: CIContext, framesToSave: [CIImage])  {
        let images = framesToSave
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        guard let documentDirectory = urls.first else {
            fatalError("documentDir Error")
        }

        let videoOutputURL = documentDirectory.appendingPathComponent("OutputVideo.mov")

        if FileManager.default.fileExists(atPath: videoOutputURL.path) {
            do {
                try FileManager.default.removeItem(atPath: videoOutputURL.path)
            } catch {
                fatalError("Unable to delete file: \(error) : \(#function).")
            }
        }

        guard let videoWriter = try? AVAssetWriter(outputURL: videoOutputURL, fileType: AVFileType.mov) else {
            fatalError("AVAssetWriter error")
        }

        let outputSettings = [AVVideoCodecKey : AVVideoCodecType.h264, AVVideoWidthKey : NSNumber(value: Float(outputSize.width)), AVVideoHeightKey : NSNumber(value: Float(outputSize.height))] as [String : Any]

        guard videoWriter.canApply(outputSettings: outputSettings, forMediaType: AVMediaType.video) else {
            fatalError("Negative : Can't apply the Output settings...")
        }



        let videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings)
        let sourcePixelBufferAttributesDictionary = [
            kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: NSNumber(value: Float(outputSize.width)),
            kCVPixelBufferHeightKey as String: NSNumber(value: Float(outputSize.height))
        ]
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)

        if videoWriter.canAdd(videoWriterInput) {
            videoWriter.add(videoWriterInput)
        }
        videoWriterInput.expectsMediaDataInRealTime = false
        let fps: Int32 = 60  // fps frames per second
        /* the timescale specifies the fraction of a second each unit in the numerator occupies. Thus if the timescale is 4, each unit represents a quarter of a second; if the timescale is 10, each unit represents a tenth of a second, and so on. */
        let frameDuration = CMTimeMake(value: 2, timescale: fps)
        // 2/60 = 1/30 sec
            // now 10/60 = 1/6 sec
            // was  1/60th frame duration or 60 frames/second
        // was value: 100
        NSLog("saveVideo frameDuration = \(frameDuration)" )
        videoWriter.overallDurationHint = CMTimeMultiply(frameDuration, multiplier: Int32(framesToSave.count))
        var frameCount: Int64 = 10
            // skips the first ten frames that have a crop offset..
        var appendSucceeded = false

        if videoWriter.startWriting() {
            videoWriter.startSession(atSourceTime: CMTime.zero)
            assert(pixelBufferAdaptor.pixelBufferPool != nil)

            while (frameCount < (images.count - 1)) {
                NSLog (#function, " frameCount loop  \(frameCount)")
                if (videoWriterInput.isReadyForMoreMediaData) {
                    appendSucceeded = false // gets set to true on success of this loop
                    let nextPhoto = images[Int(frameCount)]

                    let lastFrameTime = CMTimeMake(value: frameCount, timescale: fps)
                    let presentationTime = frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)

                    NSLog("saveVideo lastFrameTime = \(lastFrameTime) ")
                    NSLog("saveVideo presentationTime = \(presentationTime)")

                    var pixelBuffer: CVPixelBuffer? = nil
                    let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferAdaptor.pixelBufferPool!, &pixelBuffer)

                    if let pixelBuffer = pixelBuffer, status == 0 {
                        let managedPixelBuffer = pixelBuffer

                        CVPixelBufferLockBaseAddress(managedPixelBuffer, [])

                        inContext.render(nextPhoto, to: managedPixelBuffer)

                        CVPixelBufferUnlockBaseAddress(managedPixelBuffer, [])

                        appendSucceeded = pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                        if appendSucceeded {
                            frameCount += 1
                            NSLog (" appendSucceeded - incrememt frameCount to \(frameCount)")
                            NSLog (" appendSucceeded presentationTime = \(presentationTime)")
                        }
                        // what if appendSucceeded is never true for some append step?? how to break
                    }
                } // else delay??
                
            }
            videoWriterInput.markAsFinished()

            videoWriter.finishWriting { () -> Void in
                NSLog(#function , "finishWriting ")

                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoOutputURL)
                }) { saved, error in

                    if let error = error {
                        NSLog (#function , "Error saving video to librayr: \(error.localizedDescription)")
                    }
                    if saved {
                        NSLog (#function , "Video save to library")

                    }
                }
            }
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




}
