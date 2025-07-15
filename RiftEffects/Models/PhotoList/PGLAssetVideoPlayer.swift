//
//  PGLAssetVideoPlayer.swift
//  RiftEffects
//
//  Created by Will on 2/9/24.
//  Copyright © 2024 Will Loew-Blosser. All rights reserved.
//

import Foundation   

import UIKit
import Photos
import CoreImage
import os
import Combine


let PGLVideoLoaded = NSNotification.Name(rawValue: "PGLVideoLoaded")
let PGLVideoReadyToPlay = NSNotification.Name(rawValue: "PGLVideoReadyToPlay")
let PGLPlayVideo =  NSNotification.Name(rawValue: "PGLPlayVideo")
let PGLVideoRunning = NSNotification.Name(rawValue: "PGLVideoRunning")
let PGLStopVideo = NSNotification.Name(rawValue: "PGLStopVideo")
let PGLVideoSourceStateChanged = NSNotification.Name(rawValue: "PGLVideoSourceStateChanged")

enum VideoSourceState: Int {
    case None
    case Ready
    case Running
    case Pause

}

@MainActor
class PGLAssetVideoPlayer: Equatable, Hashable {

    var parentAsset: PGLAsset

    init(parentAsset: PGLAsset) {
        self.parentAsset = parentAsset
    }
    weak var videoMgr: PGLVideoMgr?
    var videoLocalURL: URL?
    var videoPlayer: AVQueuePlayer? // subclass of AVPlayer
    var avPlayerItem: AVPlayerItem!

    var playerLooper: AVPlayerLooper?
        /// current video frame from the displayLinkCopyPixelBuffer
    var videoCIFrame: CIImage?
//    var statusObserver: NSKeyValueObservation?
    var cancellables = [AnyCancellable]()

    var playVideoToken: (any NSObjectProtocol)?
    var stopVideoToken: (any NSObjectProtocol)?

    var imageOrientation = PGLDevicePosition()
    lazy var videoPropertyOrientation =  propertyOrientation()

    //MARK: Equatable, Hashable
    nonisolated static func == (lhs: PGLAssetVideoPlayer, rhs: PGLAssetVideoPlayer) -> Bool {
        // two players could be playing the same video asset
        return lhs === rhs
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
// MARK: Create/Release

    func releaseVars() {

        postVideoRemove()
        videoMgr?.removeVideoAsset(oldVideo: self)
        
        if playVideoToken != nil {
            NotificationCenter.default.removeObserver(playVideoToken!)
        }
        if stopVideoToken != nil {
            NotificationCenter.default.removeObserver(stopVideoToken!)
        }
        if videoPlayer != nil {
            NSLog("PGLAssetVideoPlayer releaseVars video")
            videoPlayer?.isMuted = true
            videoPlayer!.pause()
            playerLooper?.disableLooping()
            playerLooper = nil
            videoPlayer!.removeAllItems() // should stop all playback
            videoPlayer = nil

            cancellables.first?.cancel()
            avPlayerItem = nil
            videoCIFrame = nil
        }
        if videoLocalURL != nil {
            try? FileManager.default.removeItem(at: videoLocalURL!)
            videoLocalURL = nil
        }
    }

//MARK: Setup options
    func createAVPlayerOptions() -> PHVideoRequestOptions? {
        let videoColorProperties = [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_P3_D65,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_Linear,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020
        ]
        let outPutSettings = [
            AVVideoAllowWideColorKey: true,
            AVVideoColorPropertiesKey: videoColorProperties,
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_64RGBAHalf)
        ] as? PHVideoRequestOptions
        outPutSettings?.isNetworkAccessAllowed = true

        return outPutSettings

    }

    fileprivate func createPlayerItemVideoOutput() -> AVPlayerItemVideoOutput{
        /*
         A dictionary providing information about the status of the request. See Image Result Info Keys for possible keys and values
         */

        let videoColorProperties = [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_P3_D65,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_Linear,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020
        ]
        let outPutSettings = [
            AVVideoAllowWideColorKey: true,
            AVVideoColorPropertiesKey: videoColorProperties,
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_64RGBAHalf),
            kCVPixelBufferWidthKey as String: NSNumber(value: parentAsset.asset.pixelWidth),
            kCVPixelBufferHeightKey as String: NSNumber(value: parentAsset.asset.pixelHeight)
        ] as [String : Any]

        return AVPlayerItemVideoOutput(outputSettings: outPutSettings)
    }


    


    func videoRequestOptions() -> PHVideoRequestOptions {
        
        let videoRequestOptions = PHVideoRequestOptions()
//        videoRequestOptions.version = .original
//        videoRequestOptions.isNetworkAccessAllowed = true
//        videoRequestOptions.deliveryMode = .highQualityFormat
        videoRequestOptions.isNetworkAccessAllowed = true


        return videoRequestOptions
    }

        /// convert the UIDeviceOrientation to a CGImagePropertyOrientation
    func propertyOrientation()-> CGImagePropertyOrientation {
        var result = CGImagePropertyOrientation.up
            // default
        switch (imageOrientation.orientation, imageOrientation.device) {
            case (.unknown,.unspecified) :
                result = CGImagePropertyOrientation.up

            case (.portrait, .front) :
                result = CGImagePropertyOrientation.right
            case (.portraitUpsideDown, .front):
                result = CGImagePropertyOrientation.right
            case (.landscapeLeft, .front) :
                result = CGImagePropertyOrientation.up
            case (.landscapeRight, .front) :
                result = CGImagePropertyOrientation.up

            case (.portrait, .back) :
                result = CGImagePropertyOrientation.right
            case (.portraitUpsideDown, .back):
                result = CGImagePropertyOrientation.left
            case (.landscapeLeft, .back) :
                result = CGImagePropertyOrientation.down
            case (.landscapeRight, .back) :
                result = CGImagePropertyOrientation.up

            default:
                return result // default .up
        }
        return result
    }

    //MARK: setup Video
    fileprivate func avSetUpVideoBasicOnReadSuccess(newAsset: AVPlayerItem?) {
        NSLog(#function + " newAsset=\(String(describing: newAsset) )")
        if (newAsset == nil) { return }
        self.videoPlayer = AVQueuePlayer()
        self.avPlayerItem = newAsset


//        self.avPlayerItem = AVPlayerItem(
//            asset: newAsset!,
//            automaticallyLoadedAssetKeys: [.tracks, .duration, .commonMetadata] )
        if (avPlayerItem == nil)  {
            return
        }
                // && (progressResult >= 1.0)  {
                // callback handler will run again..
                // Register to observe the status property before associating with player.
                // from https://developer.apple.com/documentation/avfoundation/controlling-the-transport-behavior-of-a-player

            avPlayerItem.publisher(for: \.status)
                .removeDuplicates()
//                .receive(on: DispatchQueue.main)
                .sink { [weak self] status in
                    guard let self else { return }
                    switch status {
                        case .readyToPlay:
//                            MainActor.assumeIsolated(
//                                {
                                    NSLog("PGLAssetVideoPlayer avSetUpVideoBasicOnReadSuccess  .readyToPlay")
                                    for aRepeatingItem in self.videoPlayer!.items() {
                                        aRepeatingItem.add( self.createPlayerItemVideoOutput() )
                                    }
                                        // move displayLink

                                    self.setUpReadyToPlay()

                                    // now trigger the listner in readyToPlay to play
                                    let notification = Notification(name: PGLPlayVideo)
                                    NotificationCenter.default.post(name: notification.name, object: self, userInfo: [ : ])
//                                }
//                           )
                      case .failed:
                        // A failure while loading media occurred.
                          self.closeWaitingIndicator()
                      default:
                        break
                    }

                } // sink close

                .store(in: &cancellables)

        // Set the item as the player's current item.
//        avPlayerItem.add( self.createPlayerItemVideoOutput() )
//        videoPlayer?.replaceCurrentItem(with: avPlayerItem)
        self.playerLooper = AVPlayerLooper(player: self.videoPlayer! , templateItem: avPlayerItem)
        videoPlayer?.replaceCurrentItem(with: avPlayerItem)

    }



    func setUpVideoPlayAssets() {
            // Create a display link
            // automaticallyLoadedAssetKeys - array
            // An NSArray of NSStrings, each representing a property key defined by
            //   AVAsset. See AVAsset.h for property keys, e.g. duration
        var progressResult: Double = 0
        let thePHAsset = parentAsset.asset
        let options = videoRequestOptions()
        options.progressHandler  = { progress, error, stop, info in
            if let error = error {
                NSLog("Download error: \(error.localizedDescription)")
            }
            NSLog("setUpVideoPlayAssets progress = \(progress)")
            progressResult = progress
        }

       PHImageManager.default().requestPlayerItem(forVideo: thePHAsset , options: options) { avAsset, info in
//        PHImageManager.default().requestAVAsset(forVideo: thePHAsset, options: options) { avAsset, mix, info in

           NSLog("PGLAssetVideoPlayer requestPlayerItemForVideo completionHandler")
            if let info = info {
                NSLog("PGLAssetVideoPlayer requestPlayerItemForVideo info = \(info)")
            }
            if avAsset == nil {
                return
            }

           NSLog("PGLAssetVideoPlayer requestPlayerItemForVideo avAsset = \(String(describing: avAsset)) ")
           self.avSetUpVideoBasicOnReadSuccess(newAsset: avAsset)
        }
        NSLog("PGLAssetVideoPlayer AFTER requestPlayerItemForVideo ")


    }




    func getVideoPreferredTransform(callBack: @escaping (PGLDevicePosition) -> Void ) {

        Task {
            let devicePosition = await avPlayerItem.asset.videoOrientation()
            callBack(devicePosition)
        }
    }




    //MARK: Output Video
    func imageFrom() -> CIImage? {
        if videoPlayer != nil {
             if videoPlayer?.status ==  .readyToPlay  {
                    /// set the videoCIFrame from the pixelBuffer
             displayLinkCopyPixelBuffers()
                }
        }
        return videoCIFrame


    }

    func displayLinkCopyPixelBuffers()
       {
//           NSLog("PGLAssetVideoPlayer #displayLinkCopyPixelBuffers start")
               // really need to get the current item in the videoPlayer
               // ask for it's videoOutput
           guard let currentVideoOutputs = videoPlayer?.currentItem?.outputs
           else {
               NSLog("PGLAssetVideoPlayer #displayLinkCopyPixelBuffers fails on currentItem?.outputs")
               return }

           guard let theVideoOutput = currentVideoOutputs.first as? AVPlayerItemVideoOutput
           else {  NSLog("PGLAssetVideoPlayer #displayLinkCopyPixelBuffers fails on theVideoOutput")
               return }

//           NSLog("PGLAssetVideoPlayer #displayLinkCopyPixelBuffers has videoOutput \(String(describing: theVideoOutput))")
           let currentTime = theVideoOutput.itemTime(forHostTime: CACurrentMediaTime())

           if theVideoOutput.hasNewPixelBuffer(forItemTime: currentTime)
            {

             if let buffer  = theVideoOutput.copyPixelBuffer(forItemTime: currentTime,
                                                     itemTimeForDisplay: nil)
                 {
//                  NSLog("PGLAssetVideoPlayer #displayLinkCopyPixelBuffers videoOutput new buffer ")
                     ///cache the video frame for the next Renderer image request
                let sourceFrame = CIImage(cvPixelBuffer: buffer)

                 let neededTransform = sourceFrame.orientationTransform(for: videoPropertyOrientation)
                 videoCIFrame = sourceFrame.transformed(by: neededTransform)
//                     NSLog("PGLAssetVideoPlayer #displayLinkCopyPixelBuffers videoCIFrame set")

                }
         }
       }

    //MARK: Notifications

    func setUpReadyToPlay() {

        let center = NotificationCenter.default
        let mainQueue = OperationQueue.main

        // now listen for the play command
        playVideoToken = center.addObserver(
            forName: PGLPlayVideo,
            object: nil,
            queue: mainQueue) {[weak self] notification in
                MainActor.assumeIsolated( {
                    NSLog("PGLAssetVideoPlayer setUpReadyToPlay notification PGLPlayVideo handler triggered")
                    if self?.videoPlayer?.status == .readyToPlay {
                            // one player may be starting while a current one is running

                        self?.videoPlayer?.isMuted = false
                        self?.videoPlayer?.play()
                        Logger(subsystem: LogSubsystem, category: LogNavigation).info(("\( String(describing: self.debugDescription) + " PLAYING") "))
                        self?.postVideoAdd()
                            // notify PGLRedraw videoSourceStateChange +1
                    }

                    self?.notifyVideoStarted()
//                    NSLog("PGLAssetVideoPlayer setUpReadyToPlay  videoPlayer?.play")
                })
            }
        NSLog("PGLAssetVideoPlayer setUpReadyToPlay calls #postVideoLoaded")
        postVideoLoaded()

            // center.removeObserver(observer)
        setupStopVideoListener()
    }

    func setupStopVideoListener() {
        let center = NotificationCenter.default
        let mainQueue = OperationQueue.main

        stopVideoToken = center.addObserver(
            forName: PGLStopVideo,
            object: nil,
            queue: mainQueue) { notification in
                MainActor.assumeIsolated( {
                    self.videoPlayer?.pause()
                    self.videoPlayer?.isMuted = true
                    NSLog("\(self) PAUSED")
                })

            }
    }

    func notifyVideoStarted() {

        let runningNotification = Notification(name:PGLVideoRunning)
        NotificationCenter.default.post(name: runningNotification.name, object: self, userInfo: [ : ])
        Logger(subsystem: LogSubsystem, category: LogNavigation).info(("\( String(describing: self) + " Notify PGLVideoRunning") "))

    }
    
        ///  notify the imageController to show the play  button.
    func postVideoLoaded() {

        let loadButtonNotification = Notification(name:PGLVideoLoaded)

        NotificationCenter.default.post(name: loadButtonNotification.name, object: self, userInfo: [ : ])


    }

    func postVideoAdd() {
        let updateNotification = Notification(name:PGLVideoSourceStateChanged)
        NotificationCenter.default.post(name: updateNotification.name, object: nil, userInfo: ["videoSourceStateChange" : +1 ])
    }

    func postVideoRemove() {
        let updateNotification = Notification(name:PGLVideoSourceStateChanged)
        NotificationCenter.default.post(name: updateNotification.name, object: nil, userInfo: ["videoSourceStateChange" : -1 ])
    }

    fileprivate func closeWaitingIndicator() {
        DispatchQueue.main.async {
            let myAppDelegate =  UIApplication.shared.delegate as! AppDelegate
            myAppDelegate.closeWaitingIndicator()
        }
    }


}

