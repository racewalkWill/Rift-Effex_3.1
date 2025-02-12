//
//  PGLVideoFrame.swift
//  RiftEffects
//
//  Created by Will on 5/8/24.
//  Copyright © 2024 Will Loew-Blosser. All rights reserved.
//

import Foundation
import CoreImage

class PGLVideoFrameQueue {
    var currentVideoFrames = [CIImage]()
    
    func getCurrentVideoFrame()-> CIImage? {
        // answer first frame or nil if there are none
        // if there is only one frame return it but do not remove it
        let frameCount = currentVideoFrames.count
        switch frameCount {
            case 1:
                return currentVideoFrames.first
            case 0:
                return nil
            default:
                // more than one video frame
                // last one is the most recent
                let newestFrame = currentVideoFrames.last
                currentVideoFrames.removeSubrange(0..<frameCount)
                    // discard older frames - reduce to only the newest frame
                return newestFrame
        }

    }
    func setCurrentVideoFrame(newFrame: CIImage) {

        currentVideoFrames.append(newFrame)
    }
}
