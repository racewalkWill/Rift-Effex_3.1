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

    /// The compact column's MTKView, paused by PGLImageController.fullScreenImage()
    /// before this controller is presented, and resumed here on dismiss.
    /// Renderer.isFullScreen is one flag shared by the single Renderer
    /// instance both MTKViews delegate to - while this controller is
    /// presented it stays true for every draw(in:) call, including any the
    /// covered compact view still makes if left running. That covered view
    /// then hits the fullscreen-only branch in Renderer.drawBasicCentered
    /// (cropForInfiniteExtent + the shared outputZoomPanFilter, sized for
    /// whichever view drew most recently) using its own different drawable
    /// size, which is what produces "the image extent and destination extent
    /// do not intersect" - reported as a repeating error loop specifically in
    /// landscape once the compact view became full-bleed and started
    /// redrawing continuously behind the fullscreen presentation.
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
        dismissFullScreen(animated: true)
    }

    private var isDismissingForRotation = false

    /// Any size change while presented full-screen (device rotation, or an
    /// iPad multitasking resize) closes full-screen immediately and lets the
    /// normal window's own rotation handling take over, rather than trying to
    /// keep this presented controller in sync with an orientation it was not
    /// entered in. That resume-while-rotated case is what previously required
    /// pausing the covered view, deferring its resume to dismiss's completion
    /// handler, and forcing an explicit redraw to un-stick it - none of that
    /// is reachable anymore once rotation always exits full-screen first, so
    /// dismissFullScreen(animated:) below no longer needs any of it.
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        guard isFullScreen, !isDismissingForRotation else { return }
        isDismissingForRotation = true
        dismissFullScreen(animated: false)
    }

    private func dismissFullScreen(animated: Bool) {
        NSLog("\(self.debugDescription) " + #function + " dismiss FullScreenAspectFillMode = false ")
        FullScreenAspectFillMode = false
        metalRender.isFullScreen = FullScreenAspectFillMode
        coveredCompactMetalView?.isPaused = false
        coveredCompactMetalView = nil
        self.dismiss(animated: animated)
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
