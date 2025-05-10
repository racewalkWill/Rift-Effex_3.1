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

    init(context: CIContext) {
        self.metalContext = context

        do {
            let writer = try AVAssetWriter(outputURL: videoPath, fileType: .mov)
            let settings = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: TargetSize.width,
                AVVideoHeightKey: TargetSize.height
            ] as [String : Any]

             writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: [
                (kCVPixelBufferPixelFormatTypeKey as String) : kCVPixelFormatType_32RGBA,
                (kCVPixelBufferWidthKey as String) : TargetSize.width,
                (kCVPixelBufferHeightKey as String) : TargetSize.height])
            writer.add(writerInput)
            writer.startWriting()
            writer.startSession(atSourceTime: CMTime.zero)

        }
        catch {
            print("Failed to initialize AVAssetWriter: \(error)")
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

            var pixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(
                kCFAllocatorDefault,
                pixelBufferAdaptor.pixelBufferPool!,
                &pixelBuffer
            )

            if status == kCVReturnSuccess, let pixelBuffer = pixelBuffer {
                metalContext.render(frame, to: pixelBuffer)
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

}
