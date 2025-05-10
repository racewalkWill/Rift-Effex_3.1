//
//  DemoLivePhoto.swift
//  RiftEffects
//
//  Created by Will on 5/7/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//  from github.com/copilot session
//  How can I create a LivePhoto from MTKView?
/*
Step-by-Step Guide

1. Capture Frames from MTKView

Use MTKView to render and capture Metal frames as an image.
For each frame:
Synchronize with the GPU to fetch the content of the currentDrawable.texture.
Convert this texture into a UIImage or CGImage.
2. Prepare Media Assets for LivePhoto

Still Image:
Save the captured Metal frame as a .jpeg file using UIImageJPEGRepresentation or CGImageDestination.
Video:
Render a sequence of Metal frames to create a video.
Use AVAssetWriter to encode frames into a .mov file.
3. Create Live Photo Resources

Apple requires a pairing of:

A JPEG image for the photo (photo.jpg).
A short MOV video for the motion (photo.mov).
Ensure the video has metadata linking it to the still image. Use AVAssetWriter's metadata for this.

4. Generate the Live Photo

Use the PHLivePhoto.request(withResourceFileURLs:) API to combine the still image and video into a PHLivePhoto object.

*/


import Foundation
import MetalKit
@preconcurrency import AVFoundation
import Photos

@MainActor
class PGLMTKViewCapture {
    private let mtkView: MTKView
//    private let outputDirectory: URL

    init(mtkView: MTKView) {
        self.mtkView = mtkView
//        self.outputDirectory = FileManager.default.temporaryDirectory
    }

    // Capture a still image from MTKView
    func captureStillImage(metalContext: CIContext) -> CIImage? {
        guard let texture = mtkView.currentDrawable?.texture else { return nil }
        let ciImage = CIImage(mtlTexture: texture, options: nil)
//        let context = CIContext()
//        let returnImage =  ciImage.flatMap { metalContext.createCGImage($0, from: $0.extent) }
        return ciImage

    }

//     Record a video using rendered frames

}
