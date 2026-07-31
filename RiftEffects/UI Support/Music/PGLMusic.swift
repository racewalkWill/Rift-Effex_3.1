//
//  PGLMusic.swift
//  RiftEffects
//
//  Created by Will on 7/7/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//

import Foundation

import UIKit
import MediaPlayer



extension PGLImageController {

//    @objc func optimizeStack(controllerMusicBtn: UIBarButtonItem?) {
//        appStack?.optimizeStack()
//    }


    @objc func musicButtonTapped(controllerMusicBtn: UIBarButtonItem?) {

        let controller = MPMediaPickerController(mediaTypes: .music)
           controller.allowsPickingMultipleItems = true
        controller.popoverPresentationController?.sourceView = controllerMusicBtn?.customView
           controller.delegate = self
           present(controller, animated: true)
    }

    nonisolated func mediaPicker(_ mediaPicker: MPMediaPickerController,
                     didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        // Get the system application music player.
        let musicPlayer = MPMusicPlayerController.applicationMusicPlayer
        musicPlayer.setQueue(with: mediaItemCollection)

            // OR   et the music player.
//            let musicPlayer = MPMusicPlayerApplicationController.applicationQueuePlayer
//            // Add a playback queue containing all songs on the device.
//            musicPlayer.setQueue(with: .songs())

        Task {
            await mediaPicker.dismiss(animated: true) }
        // Begin playback.
        if mediaItemCollection.items.isEmpty {
            musicPlayer.stop()
        }
        else {
            musicPlayer.play()
        }
    }


   nonisolated func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
       let musicPlayer = MPMusicPlayerController.applicationMusicPlayer
            //  the class var applicationMusicPlayer

       musicPlayer.stop()
       Task {
           await mediaPicker.dismiss(animated: true)
       }

    }
}


