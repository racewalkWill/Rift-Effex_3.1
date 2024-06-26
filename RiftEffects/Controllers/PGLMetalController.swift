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

@MainActor var FullScreenAspectFillMode = false

class PGLMetalController: UIViewController {

    var appStack: PGLAppStack! = nil  // model object

    var filterStack: () -> PGLFilterStack?  = { PGLFilterStack() } // a function is assigned to this var that answers the filterStack
    var metalRender: Renderer!
        // Metal View setup for Core Image Rendering
        // see listing 1-7 in
        // https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/CoreImaging/ci_tasks/ci_tasks.html#//apple_ref/doc/uid/TP30001185-CH3-SW5

        /// in full screen mode the MetalController uses GestureRecogniziers
    var isFullScreen = false
    override var prefersStatusBarHidden: Bool {
        get {
            return true
        }
    }
    var tap1Gesture: UITapGestureRecognizer?
    var tap2Gesture: UITapGestureRecognizer?
    var pinchGesture: UIPinchGestureRecognizer?
    var panGesture: UIPanGestureRecognizer?

    var currentPinchScale: CGFloat?
    var startingPinchScale: CGFloat = 1.0
    var startingPanCenter: CGPoint?


    //MARK: View Load/Unload

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpMetalRender()
        updateDrawableSize()

    }

    func setUpMetalRender() {
        // called by viewDidLoad and viewWillAppear
        guard let myAppDelegate =  UIApplication.shared.delegate as? AppDelegate
            else { Logger(subsystem: LogSubsystem, category: LogCategory).fault ( "PGLMetalController viewDidLoad fatalError AppDelegate not loaded")
                return
        }
        appStack = myAppDelegate.appStack
        filterStack = { self.appStack.outputOrViewFilterStack() }

        guard let metalView = view as? MTKView else {
            Logger(subsystem: LogSubsystem, category: LogCategory).fault ( "PGLMetalController viewDidLoad fatalError(metal view not set up in storyboard")
            return
        }

        metalRender = appStack.appRenderer
        metalRender.set(metalView: metalView)

//        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")
        metalRender.needsRedraw.toggleViewWillAppear()


         metalRender.isFullScreen = isFullScreen
//         if isFullScreen {
//             view.insetsLayoutMarginsFromSafeArea = true
//             view.sizeToFit()
//         }
            // toggles to redraw 2 times
        metalRender.drawBasicCentered(in: metalView)
            // draw once so that the view has the current stack output image
            // then normal 60 fps drawing is controlled by the PGLNeedsRedraw

        if isFullScreen {
            // add dismiss tap recognizier
            setGestureRecogniziers()
        }

    }
    override func resetVars() {

        filterStack = { nil }
        metalRender = nil
    }

    override func viewWillDisappear(_ animated: Bool) {
        removeGestureRecogniziers()
        super.viewWillDisappear(animated)
    }
    override func viewWillAppear(_ animated: Bool) {
        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")
        super.viewWillAppear(animated)
        setUpMetalRender()
        updateDrawableSize()

    }
    
    override func viewDidDisappear(_ animated: Bool) {
        resetVars()
    }


        ///  image load and doubleTap to full screen and back need size change
    func updateDrawableSize() {
        guard let metalView = view as? MTKView
        else { return }
        NSLog( "\(self.debugDescription)" + #function)
        if metalRender == nil {
            setUpMetalRender()
        }
        metalRender.mtkView(metalView, drawableSizeWillChange: metalView.drawableSize)
    }

    func setGestureRecogniziers() {
        if tap1Gesture == nil {
            tap1Gesture = UITapGestureRecognizer(target: self, action: #selector(PGLMetalController.userSingleTap ))
            if tap1Gesture != nil {
                tap1Gesture?.numberOfTapsRequired = 1
                view.addGestureRecognizer(tap1Gesture!)
            }
        }

        if tap2Gesture == nil {
            tap2Gesture = UITapGestureRecognizer(target: self, action: #selector(PGLMetalController.userDoubleTap ))
            if tap2Gesture != nil {
                tap2Gesture?.numberOfTapsRequired = 2
                view.addGestureRecognizer(tap2Gesture!)
            }
        }

        if pinchGesture == nil {
            pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(PGLMetalController.userPinch ))
            view.addGestureRecognizer(pinchGesture!)
        }
        if panGesture == nil {
            panGesture = UIPanGestureRecognizer(target: self, action: #selector(PGLMetalController.userPan ))
            view.addGestureRecognizer(panGesture!)
        }
    }

    func removeGestureRecogniziers() {

        if tap1Gesture != nil {
            view.removeGestureRecognizer(tap1Gesture!)
            tap1Gesture!.removeTarget(self, action: #selector(PGLMetalController.userSingleTap ))
            tap1Gesture = nil
        }
        if tap2Gesture != nil {
            view.removeGestureRecognizer(tap2Gesture!)
            tap2Gesture!.removeTarget(self, action: #selector(PGLMetalController.userDoubleTap ))
            tap2Gesture = nil
        }

        if pinchGesture != nil {
            view.removeGestureRecognizer(pinchGesture!)
            pinchGesture!.removeTarget(self, action: #selector(PGLMetalController.userPinch ))
            pinchGesture = nil
        }

        if panGesture != nil {
            view.removeGestureRecognizer(panGesture!)
            panGesture!.removeTarget(self, action: #selector(PGLMetalController.userPan ))
            panGesture = nil

        }

    }

    /// expand to AspectFill to all corners of the view
    @objc func userSingleTap(sender: UITapGestureRecognizer) {
            // double tap is required to fail before the single tap is tested
        // toggle back and forth on the single tap
        FullScreenAspectFillMode = !FullScreenAspectFillMode
        let translate = CGAffineTransform.identity
        // parm changes...?
        appStack.resetDrawableSize(newScale: translate)

    }

    @objc func userDoubleTap(sender: UITapGestureRecognizer) {
        // two taps dismiss
//        NSLog("\(self.debugDescription) " + #function + " dismiss")
        FullScreenAspectFillMode = false
        metalRender.isFullScreen = FullScreenAspectFillMode

        self.dismiss(animated: true)
    }

    @objc func userPinch(sender: UIPinchGestureRecognizer) {
        switch sender.state {
            case .began:
                // should use the filter current scale as the starting point?
                startingPinchScale = ((metalRender?.outputZoomPanFilter?.localFilter.value(forKey: kCIInputScaleKey) ?? 1.0) as! CGFloat)

            case .changed:
                currentPinchScale = sender.scale 
//                        + (startingPinchScale )
                metalRender?.outputZoomPanFilter?.localFilter.setValue(currentPinchScale, forKey: kCIInputScaleKey)

            case .ended, .cancelled, .failed, .possible,.recognized:
                return
            default:
                return
        }
//        NSLog("PGLMetalController #userPinch currentPinchScale = \(String(describing: currentPinchScale))")
    }

    @objc func userPan(sender: UIPanGestureRecognizer) {
//        let gesturePoint = sender.location(in: view)
        guard let viewPanFilter  = metalRender?.outputZoomPanFilter
        else { return }

        switch sender.state {
            case .began:
                 startingPanCenter = viewPanFilter.centerPoint
            case .changed:
                guard let startCenter = startingPanCenter
                    else { return }
                let changeFromStartPoint = sender.translation(in: view)
                let currentPoint = CGPoint.init(x: (startCenter.x + changeFromStartPoint.x), y: (startCenter.y - changeFromStartPoint.y))
                // need to invert y axis for LLO
               viewPanFilter.centerPoint = currentPoint
            default:
                return
        }
    }


}
