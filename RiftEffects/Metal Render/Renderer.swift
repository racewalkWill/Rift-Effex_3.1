//
//  Renderer.swift
//  Glance
//
//  Created by Will on 2/27/19.
//  Copyright © 2019 Will Loew-Blosser. All rights reserved.
//  Based on Apple Sample App "BasicTexturing"


import MetalKit
import os

var TargetSize = CGSize(width: 1040, height: 768)
var DoNotDraw = false

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


class Renderer: NSObject, MTKViewDelegate {

    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var colorPixelFormat: MTLPixelFormat!
        //    var texture: MTLTexture!
    var needsRedraw = PGLRedraw()

        /// RenderDestinationMetalView drawBasic vars

    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    let opaqueBackground: CIImage = CIImage.clear
        // end RenderDestinationMetalView drawBasic

        //    static let quadVertices: [Float] = [
        //        -1,  1,  0,    // triangle 1
        //         1, -1,  0,
        //        -1, -1,  0,
        //        -1,  1,  0,    // triangle 2
        //         1,  1,  0,
        //         1, -1,  0
        //      ]

        //    var translation: matrix_float4x4


        //    var pipelineState: MTLRenderPipelineState!
        //
        //    let colorSpace = CGColorSpaceCreateDeviceRGB() // or CGColorSpaceCreateDeviceCMYK() ?

    /// mtkViewSize is in native pixels..  much bigger that the view.frame size
    var mtkViewSize: CGSize!

        /// size before a frame change
//    var viewOldSize: CGSize?
        //    var viewportSize: vector_uint2!
        //
        //    var library: MTLLibrary!
        //    var textureLoader: MTKTextureLoader!
        //    var vertexFunction: MTLFunction!
        //    var fragmentFunction: MTLFunction!
        //    var pipelineStateDescriptor: MTLRenderPipelineDescriptor! = MTLRenderPipelineDescriptor()
        //    var vertices: MTLBuffer?
        //    var numVertices: UInt32!

    var ciMetalContext: CIContext!
    static var ciContext: CIContext!  // global for filter detectors
    var appStack: PGLAppStack! = nil  // model object
    var filterStack: () -> PGLFilterStack?  = { PGLFilterStack() } // a function is assigned to this var that answers the filterStack
    let debugRender = false

    var currentPhotoFileFormat: PhotoLibSaveFormat!
    var offScreenRender: PGLOffScreenRender = PGLOffScreenRender()
        //    var numVerticesInt: Int!

    override init() {
            /// RenderDestinationMetalView

        self.device = MTLCreateSystemDefaultDevice()!
        self.commandQueue = self.device.makeCommandQueue()!

            // Set up the Core Image context's options:
            // - Name the context to make CI_PRINT_TREE debugging easier.
            // - Disable caching because the image differs every frame.
            // - Allow the context to use the low-power GPU, if available.
        self.ciMetalContext = CIContext(mtlCommandQueue: self.commandQueue,
                                        options: [.name: "Renderer",
                                                  .cacheIntermediates: false,
                                                  .allowLowPower: true])

        let fileType = UserDefaults.standard.string(forKey:  "photosFileType")
        currentPhotoFileFormat = PhotoLibSaveFormat.init(rawValue: fileType ?? "HEIF")
        super.init()
        NSLog("\((self .debugDescription) + #function)" )
    }

    func captureImage() throws -> UIImage? {
            // capture the current image in the context
            // provide a UIImage for save to photoLibrary
            // uses existing ciContext in a background process..

        if let ciOutput = filterStack()?.stackOutputImage(false) {
            let currentRect = filterStack()!.fullScreenRect
            Logger(subsystem: LogSubsystem, category: LogCategory).debug ("Renderer #captureImage currentRect ")
            let croppedOutput = ciOutput.cropped(to: currentRect)
            guard let currentOutputImage = ciMetalContext.createCGImage(croppedOutput, from: croppedOutput.extent) else { return nil }

            Logger(subsystem: LogSubsystem, category: LogCategory).debug("Renderer #captureImage croppedOutput = \(croppedOutput)")

            return UIImage( cgImage: currentOutputImage, scale: UIScreen.main.scale, orientation: .up)
                // kaliedoscope needs down.. portraits need up.. why.. they both look .up in the imageController

                // let theOrientation = CGImagePropertyOrientation(theImage.imageOrientation)
                //             pickedCIImage = convertedImage.oriented(theOrientation)

        } else {
            throw savePhotoError.jpegError}

    }

    convenience init(globalAppStack: PGLAppStack) {
        self.init()
        appStack = globalAppStack
        filterStack = { self.appStack.outputOrViewFilterStack() }
        needsRedraw.appStackVideoMgr = appStack.videoMgr
    }

    func set(metalView: MTKView) {
        metalView.device = device
        metalView.framebufferOnly = false
            // "To optimize a drawable from an MTKView for GPU access, set the view’s framebufferOnly
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
        }



        Renderer.ciContext = ciMetalContext
        metalView.autoResizeDrawable = true


            //        metalView.clearColor = MTLClearColor(red: 0.5, green: 0.5,  blue: 0.8, alpha: 0.5)

    }

    func captureHEIFImage() throws -> Data? {
            // capture the current image in the context
            // provide a UIImage for save to photoLibrary
            // uses existing ciContext in a background process..

        if let ciOutput = filterStack()?.stackOutputImage(false).cropForInfiniteExtent()
            // cropForInfiniteExtent returns image
            // if infinite then crops to TargetSize
        {

            let rgbSpace = CGColorSpaceCreateDeviceRGB()
            let options = [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 1.0 as CGFloat]
            guard let heifData =  ciMetalContext.heifRepresentation(of: ciOutput, format: .RGBA8, colorSpace: rgbSpace, options: options)
            else {
                throw savePhotoError.nilReturn
            }

            Logger(subsystem: LogSubsystem, category: LogCategory).debug("Renderer #captureHEIFImage ")

            return heifData


                // kaliedoscope needs down.. portraits need up.. why.. they both look .up in the imageController

        } else {
            throw savePhotoError.heifError}

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
            return
        }

        Logger(subsystem: LogSubsystem, category: LogNavigation).info(("\( String(describing: self) + " drawableSizeWillChange to \(String(describing: size))") "))

        let translate = CGAffineTransform.init(translationX:  (size.width - TargetSize.width)/2, y:  (size.height - TargetSize.height)/2)
            // this uses the old TargetSize compared to the new size

        mtkViewSize = size
        TargetSize = size

        appStack.resetDrawableSize(newScale: translate)
    }

    func draw(in view: MTKView) {

        if DoNotDraw {
            view.isHidden = DoNotDraw
                // view.isHidden for iPhone navigation to different mtkViews
                // view.isHidden = true so both mktViews are black.
                // reset to false if there is an image to show from the stack.. see below
                // and notification PGLImageCollectionOpen

            return }
        if !needsRedraw.redrawNow() {
            return
        }
        if needsRedraw.shouldPauseAnimation() {
            return
        }

        drawBasicCentered(in: view)
            // get this frame drawn

        if needsRedraw.filterChanged {
            needsRedraw.filter(changed: false)
                // filter change has been drawn
        }

        needsRedraw.toggleViewWillAppear()

    }



    func drawBasicCentered(in view: MTKView) {
            // adapted from sample app RenderMetalDestinationView
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        if let commandBuffer = commandQueue.makeCommandBuffer() {

                // Add a completion handler that signals `inFlightSemaphore` when Metal and the GPU have fully
                // finished processing the commands that the app encoded for this frame.
                // This completion indicates that Metal and the GPU no longer need the dynamic buffers that
                // Core Image writes to in this frame.
                // Therefore, the CPU can overwrite the buffer contents without corrupting any rendering operations.
            let semaphore = inFlightSemaphore
            commandBuffer.addCompletedHandler { (_ commandBuffer)-> Swift.Void in
                semaphore.signal()
            }

            if let drawable = view.currentDrawable {
                let dSize = view.drawableSize

                    // Calculate the content scale factor for the view so Core Image can render at Retina resolution.
                var contentScaleFactor: CGFloat = 1.0
#if os(macOS)
                    // Determine the scale factor converting a point size to a pixel size.
                contentScaleFactor = view.convertToBacking(CGSize(width: 1.0, height: 1.0)).width
#else
                contentScaleFactor = view.contentScaleFactor
#endif
                    // Create a destination the Core Image context uses to render to the drawable's Metal texture.
                let destination = CIRenderDestination(width: Int(dSize.width),
                                                      height: Int(dSize.height),
                                                      pixelFormat: view.colorPixelFormat,
                                                      commandBuffer: commandBuffer,
                                                      mtlTextureProvider: { () -> MTLTexture in
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
                var ciOutputImage = currentStack.stackOutputImage((appStack.showFilterImage))
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

                    // Center the image in the view's visible area.
                //  3/3/3024 disable the centering - makes the point parms wrong
                //  kaliedscope filter has large negative origins so the shiftX shiftY equations are wrong.
                
                let backBounds = CGRect(x: 0, y: 0, width: dSize.width, height: dSize.height)

                    // Blend the image over an opaque background image.
                    // This is needed if the image is smaller than the view, or if it has transparent pixels.
                ciOutputImage = ciOutputImage.composited(over: self.opaqueBackground)

                    // Start a task that renders to the texture destination.
                _ = try? self.ciMetalContext.startTask(toRender: ciOutputImage, from: backBounds,
                                                       to: destination, at: CGPoint.zero)

                    // Insert a command to present the drawable when the buffer has been scheduled for execution.
                commandBuffer.present(drawable)

                    // Commit the command buffer so that the GPU executes the work that the Core Image Render Task issues.
                commandBuffer.commit()

            }
        }
    }
}

class Primitive {
    class func cube(device: MTLDevice, size: Float) -> MDLMesh {
        let allocator = MTKMeshBufferAllocator(device: device)
        let mesh = MDLMesh(boxWithExtent: [size, size, size],
                           segments: [1, 1, 1],
                           inwardNormals: false, geometryType: .triangles,
                           allocator: allocator)
        return mesh
    }
}
