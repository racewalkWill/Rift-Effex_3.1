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

    let skipFrameCount = 10 // skip the first frames captured, they have a crop offset
    var framesWritten: Int64 = 0
    var lastReportedSecond = -1

        // Called with the finished video's file URL once encoding completes.
        // Defaults to a plain Photos save with no stack name or album, matching
        // the previous behavior. Renderer#startCaptureSession lets a caller (e.g.
        // PGLAppStack #saveToPhotoLibrary) replace this before capture starts so
        // the saved video gets the same stackName/exportAlbum treatment as
        // PGLAppStack #saveToHEIFPhotosLibrary gives still photos.
    var onCaptureFinished: (URL) -> Void = { outputURL in
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
        }) { saved, error in
            if let error {
                NSLog("PGLCaptureOutput #onCaptureFinished Error saving video to library: \(error.localizedDescription)")
            }
            if saved {
                NSLog("PGLCaptureOutput #onCaptureFinished Video saved to library")
            }
        }
    }

    init(context: CIContext) {
        self.metalContext = context

        if FileManager.default.fileExists(atPath: videoPath.path) {
            do {
                try FileManager.default.removeItem(atPath: videoPath.path)
            } catch {
                fatalError("Unable to delete file: \(error) : \(#function).")
            }
        }
    }


        // The writer is not configured until the first captured frame arrives.
        // Sizing it from RenderTargetSize at session-start time (e.g. from
        // startCaptureSession) can run before the draw loop has re-synced
        // RenderTargetSize to the view's current drawableSize, baking in a stale,
        // often much smaller size and producing a badly cropped/zoomed video.
        // Using the actual frame's size guarantees the buffer always matches
        // what was really rendered.
    func configureWriter(size: CGSize) {
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

            // BGRA is the pixel format CVPixelBufferPool/VideoToolbox actually has a
            // registered format description for when paired with a hardware H.264 encoder.
            // kCVPixelFormatType_32RGBA has no such description and fails pool creation
            // with "initWithPixelBufferDescription ... pixelFormatDesc is NULL" (err -6680).
        let sourcePixelBufferAttributes =
        [
            (kCVPixelBufferPixelFormatTypeKey as String) : kCVPixelFormatType_32BGRA,
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


    func addFrame(_ frame: CIImage, size: CGSize) -> Bool {

        if writer == nil {
            configureWriter(size: size)
        }

        if frameCount >= skipFrameCount {
            appendFrame(frame)
        }
        postProgressNotification(elapsedFrameCount: frameCount + 1)
            // add the video frame
        let shouldContinue = addFrameCount()
        if !shouldContinue {
            finishWritingToLibrary()
        }
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


        // Posted at most once per elapsed second so PGLImageController can drive
        // a progress bar from secondsElapsed/secondsTotal instead of polling.
    func postProgressNotification(elapsedFrameCount: Int) {
        let secondsTotal = maxFrames / framesPerSecond
        let secondsElapsed = min(elapsedFrameCount / framesPerSecond, secondsTotal)
        guard secondsElapsed != lastReportedSecond else { return }
        lastReportedSecond = secondsElapsed

        NotificationCenter.default.post(
            name: PGLVideoSaveProgressNotification,
            object: nil,
            userInfo: ["secondsElapsed": secondsElapsed, "secondsTotal": secondsTotal]
        )
    }


        // Renders and appends a single captured frame to the AVAssetWriter immediately,
        // rather than buffering every frame in memory to encode as one long batch at the end.
    func appendFrame(_ frame: CIImage) {
        guard writer.status == .writing,
              writerInput.isReadyForMoreMediaData,
              let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool else {
            NSLog(#function, "dropped a frame, writer not ready, status = \(writer.status.rawValue)")
            return
        }

        var pixelBuffer: CVPixelBuffer? = nil
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBuffer)
        guard let pixelBuffer, status == kCVReturnSuccess else {
            return
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        metalContext.render(frame, to: pixelBuffer)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        let presentationTime = CMTimeMake(value: framesWritten, timescale: Int32(framesPerSecond))
        if pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
            framesWritten += 1
        }
    }


        // Closes out the AVAssetWriter session and saves the already-encoded video
        // file straight to the photo library. Since frames were encoded as they were
        // captured, this is just a fast finalize + save instead of a long re-encode.
    func finishWritingToLibrary() {
        let outputURL = videoPath
        writerInput.markAsFinished()
        NSLog(#function , " markAsFinished ")

        writer.finishWriting { () -> Void in
            // This method returns immediately and causes its work to be performed asynchronously.
            // Hop back to the MainActor to read/call the (non-Sendable) onCaptureFinished
            // closure, rather than capturing it directly in this @Sendable completion handler.
            NSLog(#function , " finishWriting return handler block ")
            Task { @MainActor in
                self.onCaptureFinished(outputURL)
            }
        }
    }


        // Called when the user cancels a long running capture. Discards whatever
        // has been encoded so far rather than saving a partial video to the library.
    func cancelSession() {
        guard writer != nil, writer.status == .writing else { return }
        writer.cancelWriting()
        try? FileManager.default.removeItem(at: videoPath)
    }




//     Combine the still image and video into a LivePhoto
    func createLivePhoto( videoURL: URL, completion: @escaping (PHLivePhoto?) -> Void) {
        PHLivePhoto.request(withResourceFileURLs: [ videoPath], placeholderImage: nil, targetSize: RenderTargetSize, contentMode: .aspectFit) { livePhoto, info in
            completion(livePhoto)
        }
    }

}
