//
//  Renderer.swift
//  Glance
//
//  Created by Will on 2/27/19.
//  Copyright © 2019 Will Loew-Blosser. All rights reserved.
//  Based on Apple Sample App "BasicTexturing"


import MetalKit
import os
import AVFoundation

let PGLVideoHasSavedNotification = NSNotification.Name(rawValue: "PGLVideoHasSavedNotification")
let PGLVideoSaveProgressNotification = NSNotification.Name(rawValue: "PGLVideoSaveProgressNotification")
    // userInfo: ["secondsElapsed": Int, "secondsTotal": Int] - posted by PGLCaptureOutput
    // at most once per elapsed second while a video capture session is running.


@MainActor var TargetSize = CGSize(width: 1040, height: 768)
@MainActor var FullScreenTargetTransform = CGAffineTransform.identity
@MainActor var DoNotDraw = false




///RenderDestinationMetalView drawBasic var
let maxBuffersInFlight = 3

enum VertexInputIndex : Int {
    case vertices = 0
    case viewportSize = 1
}

enum TextureIndex : Int {
    case baseColor = 0
}
struct RenderVertex {
    var position: simd_float2
        //  A vector of two 32-bit floating-point numbers.
    var textureCoordinate: simd_float2
}

@MainActor
class Renderer: NSObject, MTKViewDelegate {

    var device: (any MTLDevice)?
    var commandQueue: (any MTLCommandQueue)?
    var colorPixelFormat: MTLPixelFormat!
        //    var texture: MTLTexture!
    var needsRedraw: PGLRedraw!

        /// RenderDestinationMetalView drawBasic vars

    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    let opaqueBackground: CIImage = CIImage.black


    /// mtkViewSize is in native pixels..  much bigger that the view.frame size
    var mtkViewSize: CGSize!
    var isFullScreen = false {
        didSet{
            if !isFullScreen {
                outputZoomPanFilter = nil
            }
            needsRedraw.isFullScreen = isFullScreen
            // turns off/on drawing on every frame for pinch zoom & drag
        }
    }


    var ciMetalContext: CIContext!
    static var ciContext: CIContext!  // global for filter detectors
    var appStack: PGLAppStack! = nil  // model object
    var filterStack: () -> PGLFilterStack?  = { PGLFilterStack() } // a function is assigned to this var that answers the filterStack
    let debugRender = false

    var currentPhotoFileFormat: PhotoLibSaveFormat!
    var offScreenRender: PGLOffScreenRender = PGLOffScreenRender()
        //    var numVerticesInt: Int!
    var outputZoomPanFilter: PGLScaleDownFrame?
    var myCaptureSession: PGLCaptureOutput?
    var DoCapture = false
    var childDeviceRenderer: PGLRenderOnAirPlay?
    // metalView is temp set for measuringLuminance
    // normally nil
    var metalView: MTKView?
//    var lastRenderedImage: CIImage? added by Claude, not used

    var lastStackOutputImage: CIImage?


    @MainActor
    private func resetMetalPipeline() {
        let newDevice = MTLCreateSystemDefaultDevice()!
        let newQueue = newDevice.makeCommandQueue()!
        self.device = newDevice
        self.commandQueue = newQueue
        self.ciMetalContext = CIContext(mtlCommandQueue: newQueue,
                                        options: [.name: "Renderer",
                                                  .cacheIntermediates: false,
                                                  .allowLowPower: true])
    }


    override init() {
            /// RenderDestinationMetalView

        self.device = MTLCreateSystemDefaultDevice()!
        self.commandQueue = self.device?.makeCommandQueue()!

            // Set up the Core Image context's options:
            // - Name the context to make CI_PRINT_TREE debugging easier.
            // - Disable caching because the image differs every frame.
            // - Allow the context to use the low-power GPU, if available.
        self.ciMetalContext = CIContext(mtlCommandQueue: self.commandQueue! ,
                                        options: [.name: "Renderer",
                                                  .cacheIntermediates: false,
                                                  .allowLowPower: true])

        let fileType = UserDefaults.standard.string(forKey:  "photosFileType")
        currentPhotoFileFormat = PhotoLibSaveFormat.init(rawValue: fileType ?? "HEIF")

        needsRedraw = PGLRedraw()
        super.init()
//        NSLog("\((self .debugDescription) + #function)" )

    }
    func initZoomPanFilter() -> PGLScaleDownFrame {
        return PGLScaleDownFrame.initZoomPanFilter()
    }

    // MARK: Optimize stacks
    func shouldMeasureLuminance() -> Bool {
        return metalView != nil

    }

    func isAverageLuminanceNearZero(threshold : CGFloat = 0.0, viewSize: CGSize) -> Bool {
        // Use lastStackOutputImage (before compositing over black background)
        // to avoid infinite extent from CIImage.black compositing
        NSLog (#function, String(describing: self))
        if let ciOutput = lastStackOutputImage?.cropForInfiniteExtent(cropSize:(viewSize)) {
            let extent = ciOutput.extent
                // CIAreaAverage returns a 1x1 image with RGBA average
            // need to render the ciOutput
          guard let areaAverageFilter = CIFilter(name: "CIAreaAverage") else { return false }
          areaAverageFilter.setValue(ciOutput, forKey: kCIInputImageKey)
          areaAverageFilter.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)

            guard let outputImage = areaAverageFilter.outputImage else { return false }

                var bitmap = [UInt8](repeating: 0, count: 4)
                ciMetalContext.render(outputImage,
                               toBitmap: &bitmap,
                               rowBytes: 4,
                               bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                               format: .RGBA8,
                               colorSpace: CGColorSpace(name: CGColorSpace.sRGB))

                let r = CGFloat(bitmap[0]) / 255.0
                let g = CGFloat(bitmap[1]) / 255.0
                let b = CGFloat(bitmap[2]) / 255.0

                // Compute perceived luminance
                let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
                return luminance <= threshold

        }
        else { return false }
    }

    fileprivate func postRunLuminanceNotification() {
        let runMeasureNotification = Notification(name: PGLRunLuminanceMeasureFlag)
        
        NotificationCenter.default.post(runMeasureNotification)
        NSLog(#function , "PGLRunLuminanceMeasureFlag posted")
    }
    
    func useLuminanceMeasurementForStacks(myView: MTKView?)  {
        // will be set to nil after optimize has the luminanceMeasures
        metalView = myView
        if metalView != nil {
            postRunLuminanceNotification()
        }
        
    }

//    func currentDrawableAsCIImage(from view: MTKView) -> CIImage? {
//        // Safely get the current drawable from the MTKView
//        guard let drawable = view.currentDrawable else { return nil }
//        let texture = drawable.texture
//
//        // Layer colorspace from set(metalView:) setup code
//        let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
//
//        // Try to construct from the texture
//        if let imageFromTexture = CIImage(mtlTexture: texture, options: [.colorSpace: colorSpace as Any]) {
//            // Adjust orientation if needed
//            return imageFromTexture.oriented(.downMirrored)
//        } else {
//            return nil
//        }
//    }
    // MARK: Save support
    func captureImage() throws -> UIImage? {
            // capture the current image in the context
            // provide a UIImage for save to photoLibrary
            // uses existing ciContext in a background process..

        if let ciOutput = filterStack()?.stackOutputImage(false) {
            let currentRect = CGRect(x: 0, y: 0, width: TargetSize.width, height: TargetSize.height)
            Logger(subsystem: LogSubsystem, category: LogCategory).debug ("Renderer #captureImage currentRect ")
            let croppedOutput = ciOutput.cropped(to: currentRect)
            guard let currentOutputImage = ciMetalContext.createCGImage(croppedOutput, from: croppedOutput.extent) else { return nil }

            Logger(subsystem: LogSubsystem, category: LogCategory).debug("Renderer #captureImage croppedOutput = \(croppedOutput)")
            filterStack()?.setThumbnail(image: ciOutput)
            // Prefer a scale derived from context (deprecated: UIScreen.main)
            let contextScale: CGFloat = { 
                // Try to derive from an on-screen context; captureImage is usually called from a view controller context.
                // Use the most recently used MTKView if available, otherwise fall back.
                if let view = self.metalView, 
                   let scale = view.window?.windowScene?.screen.scale { 
                    return scale 
                } 
                // As a secondary option, try the current trait collection on the key window if accessible.
                if let scale = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow?.traitCollection.displayScale { 
                    return scale 
                } 
                // Safe fallback when no UI context is available (e.g., offscreen capture). 
                return 1.0 
            }()
            return UIImage(cgImage: currentOutputImage, scale: contextScale, orientation: .up)
                // kaliedoscope needs down.. portraits need up.. why.. they both look .up in the imageController

                // let theOrientation = CGImagePropertyOrientation(theImage.imageOrientation)
                //             pickedCIImage = convertedImage.oriented(theOrientation)

        } else {
            throw savePhotoError.jpegError}

    }

    func captureHEIFImage() throws -> Data? {
            // capture the current image in the context
            // provide a UIImage for save to photoLibrary
            // uses existing ciContext in a background process..
        let cropSize = TargetSize
        if let ciOutput = filterStack()?.stackOutputImage(false)

        {
            let widthEven = (Int(cropSize.width) / 2) * 2
            let heightEven = (Int(cropSize.height) / 2) * 2
            let evenRect = CGRect(origin: .zero,
                                  size: CGSize(width: widthEven, height: heightEven))

            // 2) Crop to finite, even extent
            var output = ciOutput.cropped(to: evenRect)

            output = output.applyingFilter("CIColorClamp",
                                           parameters: [
                                               "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                                               "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                                           ])

                // 4) Remove alpha by compositing over an opaque background
                let bg = CIImage(color: .black).cropped(to: evenRect)
                output = output.composited(over: bg)

                // 5) Use sRGB and 8-bit format
                let rgbSpace = CGColorSpace(name: CGColorSpace.sRGB)!


            let options: [CIImageRepresentationOption: Any] = [
                kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 1.0 as CGFloat
            ]
            guard let heifData = ciMetalContext.heifRepresentation(
                of: output,
                format: .RGBAh,
                colorSpace: rgbSpace,
                options: options
            ) else {
                throw savePhotoError.nilReturn
            }

            Logger(subsystem: LogSubsystem, category: LogCategory).debug("Renderer #captureHEIFImage ")

            return heifData


                // kaliedoscope needs down.. portraits need up.. why.. they both look .up in the imageController

        } else {
            throw savePhotoError.heifError}

    }

    /// true if any of these conditions
    /// viewWillAppear || parmControllerIsOpen || transitionFilterExists || varyTimerIsRunning || filterChanged || videoExists() || isFullScreen
    func isRunningFrameUpdates () -> Bool {
       return self.needsRedraw.redrawNow()
    }

    // MARK: init

    convenience init(globalAppStack: PGLAppStack) {
        self.init()
        appStack = globalAppStack
        // [weak self]: filterStack is a stored closure property; `{ self... }` would
        // retain-cycle (self -> filterStack -> closure -> self) and leak the renderer.
        filterStack = { [weak self] in self?.appStack.outputOrViewFilterStack() }
        needsRedraw.appStackVideoMgr = appStack.videoMgr
    }

    func set(metalView: MTKView) {
        metalView.device = device
        metalView.framebufferOnly = false
            // "To optimize a drawable from an MTKView for GPU access, set the view's framebufferOnly
            // property to true. This property configures the texture exclusively
            //  as a render target and displayable resource."
            // in WWDC 2020 "Optimize the Core Image pipeline for your video app" suggest false setting
            // see code at 7:24

        metalView.delegate = self
        if let layer = metalView.layer as? CAMetalLayer {
            // Enable EDR with a color space that supports values greater than SDR.
            if #available(iOS 16.0, *) {
                layer.wantsExtendedDynamicRangeContent = true
            }
            layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
            // Ensure the render view supports pixel values in EDR.
            metalView.colorPixelFormat = MTLPixelFormat.rgba16Float
//             metalView.colorPixelFormat = MTLPixelFormat.rgba32Sint
                // MTLPixelFormat.rgba16Float
//            kCVPixelFormatType_32BGRA
        }



        Renderer.ciContext = ciMetalContext
        metalView.autoResizeDrawable = true


            //        metalView.clearColor = MTLClearColor(red: 0.5, green: 0.5,  blue: 0.8, alpha: 0.5)

    }



    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            //        NSLog("Renderer mtkView drawableSize = \(view.drawableSize) drawableSizeWillChange = \(size)")
        if !((size.width > 0) && (size.height > 0)) {
            Logger(subsystem: LogSubsystem, category: LogCategory).fault("Renderer #drawableSizeWillChange size.width or height = 0 error")
                // this will cause Renderer draw fatalError (Render did not get the renderEncoder - draw(in: view
                // and [CAMetalLayer nextDrawable] returning nil because allocation failed.
        }
        if mtkViewSize != nil, mtkViewSize == size {
                // no change needed
            Logger(subsystem: LogSubsystem, category: LogNavigation).info(("\( String(describing: self) + " no change needed drawableSizeWillChange to \(String(describing: size))") "))
            return
        }
        Logger(subsystem: LogSubsystem, category: LogNavigation).info(("\( String(describing: self) + " drawableSizeWillChange from \(String(describing: self.mtkViewSize))") "))
        Logger(subsystem: LogSubsystem, category: LogNavigation).info(("\( String(describing: self) + " drawableSizeWillChange to \(String(describing: size))") "))

        let translate = CGAffineTransform.init(translationX:  (size.width - TargetSize.width)/2, y:  (size.height - TargetSize.height)/2)
            // this uses the old TargetSize compared to the new size
        FullScreenTargetTransform = translate
        mtkViewSize = size
        TargetSize = size
        outputZoomPanFilter = initZoomPanFilter() // inits with new center
        appStack.resetDrawableSize(newScale: FullScreenTargetTransform)
            // reset positionControls here?
    }

    func hideAirPlay() {
        childDeviceRenderer?.airPlayHideOnDoNotDraw()
    }

    func draw(in view: MTKView) {
//        NSLog (#function, String(describing: self) + " draw")
        if DoNotDraw {
            view.isHidden = DoNotDraw
                // view.isHidden for iPhone navigation to different mtkViews
                // view.isHidden = true so both mktViews are black.
                // reset to false if there is an image to show from the stack.. see below
                // and notification PGLImageCollectionOpen

            return }

        // Re-sync when this view's drawable does not match the last reported size.
        // A covered MTKView is resized by rotation (viewWillTransition runs
        // layoutIfNeeded on off-screen views) while another MTKView is on screen;
        // the interleaved drawableSizeWillChange callbacks from the two views can
        // leave TargetSize and the scaled image caches stale for the view that is
        // drawing now - image too small or offset in the view after rotations.
        let currentDrawableSize = view.drawableSize
        if currentDrawableSize.width > 0, currentDrawableSize.height > 0,
            mtkViewSize != currentDrawableSize {
            mtkView(view, drawableSizeWillChange: currentDrawableSize)
            needsRedraw.filterChanged = true
                // force render of fresh frames at the new size
        }

        if !needsRedraw.redrawNow() {
            return
        }
        if needsRedraw.shouldPauseAnimation() {
            if !needsRedraw.filterChanged {
                return  // skip drawing again
            }  // else go ahead to the drawBasic

        }

        drawBasicCentered(in: view)
            // get this frame drawn

        if needsRedraw.filterChanged {
//            needsRedraw.viewWillAppear = true
            needsRedraw.toggleFilterChanged()
        }
            // increment a couple frame draws then stop
        if needsRedraw.viewWillAppear {
            needsRedraw.toggleViewWillAppear()
        }



    }



     func startCaptureSession(_ secondsToCapture: Int = 2, onFinished: ((URL) -> Void)? = nil) {
         // default to 2 second save
            // Do NOT size the writer from TargetSize here: this can run before
            // DoNotDraw is cleared and the draw loop has re-synced TargetSize to
            // the view's current drawableSize, which previously baked in a stale
            // (often much smaller) size and produced a badly cropped/zoomed video.
            // PGLCaptureOutput now sizes itself from the actual frame it receives.
        myCaptureSession = PGLCaptureOutput(context: ciMetalContext)
        myCaptureSession?.maxFrames = secondsToCapture * 60 // assuming 60 frames per second
            // onFinished lets a caller (e.g. PGLAppStack #saveToPhotoLibrary) attach
            // the stackName/exportAlbum handling used for still photos; if omitted,
            // PGLCaptureOutput falls back to a plain, un-albumed Photos save.
        if let onFinished {
            myCaptureSession?.onCaptureFinished = onFinished
        }

    }

    // Called by PGLImageController's cancel button to abandon a long-running
    // video capture. Discards the partially-encoded file instead of saving it.
    func cancelCaptureSession() {
        myCaptureSession?.cancelSession()
        myCaptureSession = nil
        DoCapture = false
    }
    
    func drawBasicCentered(in view: MTKView) {
            // adapted from sample app RenderMetalDestinationView
//        NSLog (#function, String(describing: self))
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
//                    NSLog("%@", error)
                    Logger(subsystem: LogSubsystem, category: LogMetal).error("\(#function): Metal command buffer resetting after error: \(error, privacy: .public)")
                    Task { @MainActor in
                        self.resetMetalPipeline()
                    }
                }
             semaphore.signal()
             return // .. reset needs to run
                
            }
            if let drawable = view.currentDrawable {
                let dSize = view.drawableSize

                    // Calculate the content scale factor for the view so Core Image can render at Retina resolution.
//                var contentScaleFactor: CGFloat = 1.0
//#if os(macOS)
//                    // Determine the scale factor converting a point size to a pixel size.
//                contentScaleFactor = view.convertToBacking(CGSize(width: 1.0, height: 1.0)).width
//#else
//                contentScaleFactor = view.contentScaleFactor
//#endif
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
                guard let currentStack = filterStack()
                else { return }
                let backBounds = CGRect(x: 0, y: 0, width: dSize.width, height: dSize.height)
                var ciOutputImage = currentStack.stackOutputImage((appStack.showFilterImage))
                lastStackOutputImage = ciOutputImage
                // if external device running - show the outputImage
                childDeviceRenderer?.thisFrame = ciOutputImage
                childDeviceRenderer?.drawInAirPlay()

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

                    // Blend the image over an opaque background image.
                    // This is needed if the image is smaller than the view, or if it has transparent pixels.
                if isFullScreen { 
                    // perform zoom/pan from gestures
                    // let cropSize = TargetSize
//                    let cropSize = backBounds.size
                    ciOutputImage = ciOutputImage.cropForInfiniteExtent(cropSize: dSize)
                    outputZoomPanFilter?.setInput(image: ciOutputImage, source: nil)
                    outputZoomPanFilter?.setInputImageParmState(newState: ParmInputState.inputPhoto)

                    ciOutputImage = outputZoomPanFilter?.outputImage() ?? CIImage.empty()

                        // PGLScaleDownFrame does a composited(over opaqueBackground)

                } else {
                    ciOutputImage = ciOutputImage.composited(over: self.opaqueBackground)
                }


//                lastRenderedImage = ciOutputImage

                    // Start a task that renders to the texture destination.
                _ = try? self.ciMetalContext.startTask(toRender: ciOutputImage, from: backBounds,
                    to: destination,
                    at: CGPoint.zero)

                    // Insert a command to present the drawable when the buffer has been scheduled for execution.
                commandBuffer.present(drawable)

                    // Commit the command buffer so that the GPU executes the work that the Core Image Render Task issues.
                commandBuffer.commit()
                if DoCapture {
                        // add to the output queue to save

                        if myCaptureSession == nil {
                            startCaptureSession()
                                // CGSize(width: 1936.0, height: 1520.0 )
                        }
                        DoCapture =  myCaptureSession?.addFrame(ciOutputImage, size: dSize) ?? false
                            // add to the output queue to save
                            // if maxFrames captured then stop
                        if !DoCapture {
                            myCaptureSession = nil
                            NSLog("Renderer myCaptureSession set to nil")
                            displaySaveCompletionAlert()

                        }


                }
                if shouldMeasureLuminance() {
                    if currentStack.isEmptyStack() {
                        metalView = nil // end this measure loop -- no stack
                        return
                    }
                    let luminanceIsNearZero = self.isAverageLuminanceNearZero(threshold: 0.0, viewSize: dSize)
                    currentStack.currentFilter().isAverageLuminanceNearZero = luminanceIsNearZero
                    NSLog(#function + " luminanceIsNearZero: \(luminanceIsNearZero)")
                    self.postRunLuminanceNotification()
                        // trigger next filter change

                }

            }
        }
    }

    func displaySaveCompletionAlert() {

        DispatchQueue.main.async {
                // put back on the main UI loop for the user alert

            let videoHasSavedNotification = Notification(name: PGLVideoHasSavedNotification)
            NotificationCenter.default.post(videoHasSavedNotification)

        }

    }

    func animationState() -> PGLAnimationState {
        return needsRedraw.animationState()
    }
}

class Primitive {
    class func cube(device: any MTLDevice, size: Float) -> MDLMesh {
        let allocator = MTKMeshBufferAllocator(device: device)
        let mesh = MDLMesh(boxWithExtent: [size, size, size],
                           segments: [1, 1, 1],
                           inwardNormals: false, geometryType: .triangles,
                           allocator: allocator)
        return mesh
    }
}

