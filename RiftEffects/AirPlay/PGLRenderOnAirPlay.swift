//
//  PGLRenderAirPlayDevice.swift
//  RiftEffects
//
//  Created by Loew-Blosser on 6/2/25.
//  Copyright © 2025 Will Loew-Blosser. All rights reserved.
//

import MetalKit
import os
import AVFoundation


/// renders just to an external airPlay device from the same frame as parent
@MainActor
class PGLRenderOnAirPlay: Renderer {
    var thisFrame: CIImage?
    var myView: MTKView?

    convenience init(globalAppStack: PGLAppStack) {
        self.init()
        appStack = globalAppStack
        filterStack = { self.appStack.outputOrViewFilterStack() }

        let imageViewWillAppearNotification = Notification(name:PGLImageViewWillAppear)
        NotificationCenter.default.post(imageViewWillAppearNotification)

            //        needsRedraw.appStackVideoMgr = appStack.videoMgr
    }
    
    override func set(metalView: MTKView) {
        super.set(metalView: metalView)
        myView = metalView
    }

    func drawInAirPlay() {
        guard let realView = myView
            else { return }

        drawBasicCentered(in: realView )

    }

    func airPlayHideOnDoNotDraw() {
        if  myView?.isHidden == DoNotDraw
            { return }

        myView?.isHidden = DoNotDraw

    }

    override func drawBasicCentered(in view: MTKView) {
            // adapted from sample app RenderMetalDestinationView
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        let desc = MTLCommandBufferDescriptor()
        desc.retainedReferences = true // forces strong refs to vars
        // in ver 3.5 there are memory crashes on the .makeCommandBuffer for bad memory acccess

        desc.errorOptions = .encoderExecutionStatus
        if let commandBuffer = commandQueue?.makeCommandBuffer(descriptor: desc)
        {
                // Add a completion handler that signals `inFlightSemaphore` when Metal and the GPU have fully
                // finished processing the commands that the app encoded for this frame.
                // This completion indicates that Metal and the GPU no longer need the dynamic buffers that
                // Core Image writes to in this frame.
                // Therefore, the CPU can overwrite the buffer contents without corrupting any rendering operations.
            let semaphore = inFlightSemaphore

                // added @Sendable per DTS Engineer Quinn to the below completionHandler
                // otherwise a hidden assert in the Swift 6 will crash the app
                // see https://developer.apple.com/forums/thread/764777?answerId=807248022#807248022
            commandBuffer.addCompletedHandler { @Sendable (_ commandBuffer)-> Swift.Void in
                if let error = commandBuffer.error as NSError? {
                    NSLog("%@", error)
                }
             semaphore.signal()
            }
            if let drawable = view.currentDrawable {
                let dSize = view.drawableSize

                    // Create a destination the Core Image context uses to render to the drawable's Metal texture.
                let destination = CIRenderDestination(width: Int(dSize.width),
                                                      height: Int(dSize.height),
                                                      pixelFormat: view.colorPixelFormat,
                                                      commandBuffer: commandBuffer,
                                                      mtlTextureProvider: { () -> (any MTLTexture) in
                        // Core Image calls the texture provider block lazily when starting a task to render to the destination.
                    return drawable.texture
                })
                    //                destination.isFlipped = false

                    // Determine EDR headroom and fallback to SDR, as needed.
                    // Note: The headroom must be determined every frame to include changes in environmental lighting conditions.
//                let screen = view.window?.screen
//#if os(iOS)
//                var headroom = CGFloat(1.0)
//                if #available(iOS 16.0, *) {
//                    headroom = screen?.currentEDRHeadroom ?? 1.0
//                }
//#else
//                let headroom = screen?.maximumExtendedDynamicRangeColorComponentValue ?? 1.0
//#endif
                    /// get an image to draw
//                guard let currentStack = filterStack()
//                else { return }
                
                let backBounds = CGRect(x: 0, y: 0, width: dSize.width, height: dSize.height)
                let ciOutputImage = thisFrame ?? CIImage.empty()
//                NSLog(#function, "stackOutputImage = \(ciOutputImage)")
                if view.isHidden {
                        // check if there is now an image to show
                    if ciOutputImage == CIImage.empty() {
                            // skip the render on empty image
                        return
                    } else {
                            // there is an image to show..
                        view.isHidden = false
                    }
                }

                    // Start a task that renders to the texture destination.
                _ = try? self.ciMetalContext.startTask(toRender: ciOutputImage, from: backBounds,
                    to: destination,
                    at: CGPoint.zero)

                    // Insert a command to present the drawable when the buffer has been scheduled for execution.
                commandBuffer.present(drawable)

                    // Commit the command buffer so that the GPU executes the work that the Core Image Render Task issues.
                commandBuffer.commit()

            }
        }
    }

    override func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            //        NSLog("Renderer mtkView drawableSize = \(view.drawableSize) drawableSizeWillChange = \(size)")
        if !((size.width > 0) && (size.height > 0)) {
            Logger(subsystem: LogSubsystem, category: LogCategory).fault("Renderer #drawableSizeWillChange size.width or height = 0 error")
                // this will cause Renderer draw fatalError (Render did not get the renderEncoder - draw(in: view
                // and [CAMetalLayer nextDrawable] returning nil because allocation failed.
        }
        if mtkViewSize != nil, mtkViewSize == size {
                // no change needed
            return
        }

        Logger(subsystem: LogSubsystem, category: LogNavigation).info(("\( String(describing: self) + " drawableSizeWillChange to \(String(describing: size))") "))

//        let translate = CGAffineTransform.init(translationX:  (size.width - TargetSize.width)/2, y:  (size.height - TargetSize.height)/2)
            // this uses the old TargetSize compared to the new size
//        FullScreenTargetTransform = translate
        mtkViewSize = size
            // mktViewSize is instance var - with AirPlay there are two instances.

//        TargetSize = size
            // in AirPlay mode just output let the mainScreen set this value

        outputZoomPanFilter = initZoomPanFilter() // inits with new center

// appStack does not have the new scale for the AirPlay device
        // CHANGE this
//        appStack.resetDrawableSize(newScale: FullScreenTargetTransform)
    }


}
