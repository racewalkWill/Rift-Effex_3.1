//
//  PGLMetalDeviceController.swift
//  RiftEffects
//
//  Created by Loew-Blosser on 6/2/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//


//
//  PGLMetalController.swift
//  Glance
//
//  Created by Will on 1/20/19.
//  Copyright © 2019 Will Loew-Blosser. All rights reserved.
//


import MetalKit
import CoreGraphics
import UIKit
import simd
import os


/// Renders frame from the iOS device to attached AirPlay device
///  No user interaction - no tap, drag, pinch etc on external device
class PGLMetalDeviceController: PGLMetalController {

     // Metal View setup for Core Image Rendering
        // see listing 1-7 in
        // https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/CoreImaging/ci_tasks/ci_tasks.html#//apple_ref/doc/uid/TP30001185-CH3-SW5

        /// DeviceController does not have interaction



    //MARK: View Load/Unload

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpMetalRender()
        updateDrawableSize()


    }

  override  func setUpMetalRender() {
        // called by viewDidLoad and viewWillAppear
        guard let myAppDelegate =  UIApplication.shared.delegate as? AppDelegate
            else { Logger(subsystem: LogSubsystem, category: LogCategory).fault ( "PGLMetalController viewDidLoad fatalError AppDelegate not loaded")
                return
        }
        appStack = myAppDelegate.appStack

        guard let metalView = view as? MTKView else {
            Logger(subsystem: LogSubsystem, category: LogCategory).fault ( "PGLMetalController viewDidLoad fatalError(metal view not set up in storyboard")
            return
        }

        metalRender = Renderer(globalAppStack: appStack)
        metalRender.set(metalView: metalView)

        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")

        metalRender.isFullScreen = true // always fullscreen

            // toggles to redraw 2 times
        metalRender.drawBasicCentered(in: metalView)
            // draw once so that the view has the current stack output image
            // then normal 60 fps drawing is controlled by the PGLNeedsRedraw

    }



    override func viewWillAppear(_ animated: Bool) {
//        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")
        super.viewWillAppear(animated)

        setUpMetalRender()
        updateDrawableSize()
//        DoNotDraw = true
                // blank the screen briefly fixes fullscreen small to big jump

    }

//    override func viewDidAppear(_ animated: Bool) {
//
//        updateDrawableSize()
//        if isFullScreen {
//            // works fine when loading fullscreen
//            appStack.pointParms(shiftTransform: FullScreenTargetTransform)
//           NSLog ("\( String(describing: self) + "-" + #function)" + " pointParms shifted by \(FullScreenTargetTransform)")
//        }
//        DoNotDraw = false
//        super.viewDidAppear(animated)
//    }

    override func viewDidDisappear(_ animated: Bool) {
        resetVars()
    }


        ///  image load and doubleTap to full screen and back need size change
   override func updateDrawableSize() {
        guard let metalView = view as? MTKView
        else { return }
        NSLog( "\(self.debugDescription)" + #function)
        if metalRender == nil {
            setUpMetalRender()
        }
        metalRender.mtkView(metalView, drawableSizeWillChange: metalView.drawableSize)
    }

}
