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
import Combine

@MainActor var FullScreenAspectFillMode = false

let  PGLMetalLuminanceMeasureFlag = NSNotification.Name(rawValue: "PGLMetalLuminanceMeasureFlag")

class PGLMetalController: UIViewController, UIGestureRecognizerDelegate {

    var appStack: PGLAppStack! = nil  // model object

//    var filterStack: () -> PGLFilterStack?  = { PGLFilterStack() } // a function is assigned to this var that answers the filterStack
    var metalRender: Renderer!
        // Metal View setup for Core Image Rendering
        // see listing 1-7 in
        // https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/CoreImaging/ci_tasks/ci_tasks.html#//apple_ref/doc/uid/TP30001185-CH3-SW5

        /// in full screen mode the MetalController uses GestureRecogniziers
    var isFullScreen = false

    /// The embedded (compact-column) MTKView this full-screen viewer covers,
    /// set by PGLImageController.fullScreenImage() before presenting. Both
    /// MTKViews share one Renderer instance (appStack.appRenderer); if both
    /// keep drawing at once, their drawableSizeWillChange callbacks
    /// interleave and each undoes the other's RenderTargetSize forever (the
    /// oscillating drawableSize / wrong-scale bug). Pausing the covered
    /// view's draw loop while this one is full-screen, and resuming it on
    /// dismiss, keeps only one view driving the shared renderer at a time.
    weak var coveredCompactMetalView: MTKView?
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

    var publishers = [any Cancellable]()
    var cancellable: (any Cancellable)?

    //MARK: View Load/Unload

//    override func viewDidLoad() {
//        super.viewDidLoad()
//        setUpMetalRender()
//        updateDrawableSize()
//
//
//    }

    func setUpMetalRender() {
        // called by viewDidLoad and viewWillAppear
        guard let myAppDelegate =  UIApplication.shared.delegate as? AppDelegate
            else { Logger(subsystem: LogSubsystem, category: LogCategory).fault ( "PGLMetalController viewDidLoad fatalError AppDelegate not loaded")
                return
        }
        myAppDelegate.mainMetalController = self
        appStack = myAppDelegate.appStack
//        filterStack = { self.appStack.outputOrViewFilterStack() }

        guard let metalView = view as? MTKView else {
            Logger(subsystem: LogSubsystem, category: LogCategory).fault ( "PGLMetalController viewDidLoad fatalError(metal view not set up in storyboard")
            return
        }

        metalRender = appStack.appRenderer
        metalRender.set(metalView: metalView)

        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")
        metalRender.needsRedraw.toggleViewWillAppear()


        metalRender.isFullScreen = isFullScreen
            // toggleViewWillAppear triggers the draw on the next display link callback
            // do not call drawBasicCentered directly — it can reuse a presented drawable
        // drawBasicCentered removed by Claude to fix doubleTap
        // see R227.7.1
//        metalRender.drawBasicCentered(in: metalView)
            // draw once so that the view has the current stack output image
            // then normal 60 fps drawing is controlled by the PGLNeedsRedraw

        if isFullScreen {
            // add dismiss tap recognizier
            setGestureRecogniziers()
        }

    }
    override func resetVars() {

//        filterStack = { nil }
        metalRender = nil
    }

    override func releaseNotifications() {
        for aCancel in publishers {
            aCancel.cancel()
        }
        publishers = [any Cancellable]()
    }

    override func viewWillDisappear(_ animated: Bool) {
        removeGestureRecogniziers()
        super.viewWillDisappear(animated)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // PGLWindowSceneDelegate's rotation handling only re-lays-out the
        // underlying split view's compact column; it does not know about
        // whatever is presented full-screen on top (this controller, when
        // showing the double-tap image viewer). Without this, the MTKView's
        // drawable size is never recalculated after rotating while
        // full-screen, so the image kept rendering at its pre-rotation size.
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.updateDrawableSize()
        }
    }
    override func viewWillAppear(_ animated: Bool) {
//        Logger(subsystem: LogSubsystem, category: LogNavigation).info("\( String(describing: self) + "-" + #function)")
        super.viewWillAppear(animated)

        setUpMetalRender()
        updateDrawableSize()

        let myCenter =  NotificationCenter.default
        cancellable = myCenter.publisher(for:  PGLMetalLuminanceMeasureFlag)
            .sink() { [weak self]
                myUpdate in
                guard let self = self else { return }

                if let userDataDict = myUpdate.userInfo {
                    if let flag  = userDataDict["measureFlag"] as? Bool  {
                        self.setMetalLuminanceFlag(flag: flag)
                        NSLog("\( String(describing: self) + "-" + #function)" + " setMetalLuminanceFlag to \(flag)")
                    }
                }
            }
        publishers.append(cancellable!)
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
        releaseNotifications()
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

        if tap2Gesture == nil {
            tap2Gesture = UITapGestureRecognizer(target: self, action: #selector(PGLMetalController.userDoubleTap ))
            if tap2Gesture != nil {
                tap2Gesture?.numberOfTapsRequired = 2
                view.addGestureRecognizer(tap2Gesture!)
            }
        }

        if tap1Gesture == nil {
            tap1Gesture = UITapGestureRecognizer(target: self, action: #selector(PGLMetalController.userSingleTap ))
            if tap1Gesture != nil {
                tap1Gesture?.numberOfTapsRequired = 1
                view.addGestureRecognizer(tap1Gesture!)
            }
            tap1Gesture?.delegate = self  // so the gestureRecognizer(shouldRequireFailure.. is run
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

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
             shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
       // Don't recognize a single tap until a double-tap fails.
       if gestureRecognizer == self.tap1Gesture &&
              otherGestureRecognizer == self.tap2Gesture {
          return true
       }
       return false
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
 
        // parm changes...?
        appStack.resetDrawableSize()

    }

    @objc func userDoubleTap(sender: UITapGestureRecognizer) {
        // two taps dismiss
        NSLog("\(self.debugDescription) " + #function + " dismiss FullScreenAspectFillMode = false ")
        FullScreenAspectFillMode = false
        metalRender.isFullScreen = FullScreenAspectFillMode

        // Stop this view from drawing before the covered view resumes, so
        // only one MTKView drives the shared renderer at a time.
        (view as? MTKView)?.isPaused = true
        coveredCompactMetalView?.isPaused = false

        self.dismiss(animated: true) {
            // Dismissal is not a rotation event, but the revealed compact
            // column may still be holding a frame from before a rotation
            // that happened while this viewer covered it (that rotation
            // deliberately skipped the covered column — see
            // PGLWindowSceneDelegate). Force it to catch up now.
            //
            // Deferred one run-loop tick: right at the dismiss completion,
            // presentedViewController bookkeeping was not reliably cleared
            // yet, which made the relayout mistake this controller for
            // still-presented content and skip resizing the compact column
            // entirely.
            DispatchQueue.main.async {
                NSLog("PGLMetalController.userDoubleTap dismiss completion: calling relayoutForCurrentWindowBounds, windowSceneDelegate=\(String(describing: (UIApplication.shared.delegate as? AppDelegate)?.windowSceneDelegate))")
                (UIApplication.shared.delegate as? AppDelegate)?.windowSceneDelegate?.relayoutForCurrentWindowBounds()
            }
        }
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

        //MARK: Optimize luminance
    func setMetalLuminanceFlag(flag:Bool)
    {
        // setting metalRender view to nil will turn off luminance capture
        guard let myMetalView = view as? MTKView else
        {
            metalRender?.useLuminanceMeasurementForStacks(myView: nil)
            return
        }
        if flag {
            metalRender?.useLuminanceMeasurementForStacks(myView: myMetalView)
        } else {
            metalRender?.useLuminanceMeasurementForStacks(myView: nil)
        }
    }

}
