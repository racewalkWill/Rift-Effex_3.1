//
//  MetalFilters.swift
//  Filterpedia
//
//  Created by Simon Gladman on 24/01/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.

//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>

import CoreImage
import os

#if !arch(i386) && !arch(x86_64)

import Metal
import MetalKit
    
// MARK: MetalPixellateFilter

class MetalPixellateFilter: MetalImageFilter
{
    init()
    {
        super.init(functionName: "pixellate")
    }

    required init?(coder aDecoder: NSCoder)
    {   super.init(coder: aDecoder)
//        fatalError("init(coder:) has not been implemented")
    }

    @objc var inputPixelWidth: CGFloat = 50
    @objc var inputPixelHeight: CGFloat = 25
    
    override func setDefaults()
    {
        inputPixelWidth = 50
        inputPixelHeight = 25
    }
    
    override var attributes: [String : Any]
    {
        return [
            kCIAttributeFilterDisplayName: "Metal Pixellate",
        
            "inputImage": [kCIAttributeIdentity: 0,
                kCIAttributeClass: "CIImage",
                kCIAttributeDisplayName: "Image",
                               kCIAttributeType: kCIAttributeTypeImage] as [String : Any],
            
            "inputPixelWidth": [kCIAttributeIdentity: 0,
                kCIAttributeClass: "NSNumber",
                kCIAttributeDefault: 50,
                kCIAttributeDisplayName: "Pixel Width",
                kCIAttributeMin: 0,
                kCIAttributeSliderMin: 0,
                kCIAttributeSliderMax: 100,
                                    kCIAttributeType: kCIAttributeTypeScalar] as [String : Any],
            
            "inputPixelHeight": [kCIAttributeIdentity: 1,
                kCIAttributeClass: "NSNumber",
                kCIAttributeDefault: 25,
                kCIAttributeDisplayName: "Pixel Height",
                kCIAttributeMin: 0,
                kCIAttributeSliderMin: 0,
                kCIAttributeSliderMax: 100,
                                     kCIAttributeType: kCIAttributeTypeScalar] as [String : Any]
        ]
    }
}

// MARK: Perlin Noise

class MetalPerlinNoise: MetalGeneratorFilter
{
    init()
    {
        super.init(functionName: "perlin")
    }
    
    required init?(coder aDecoder: NSCoder)
    {    super.init(coder: aDecoder)
//        fatalError("init(coder:) has not been implemented")
    }

    @objc var inputReciprocalScale = CGFloat(50)
    @objc var inputOctaves = CGFloat(2)
    @objc var inputPersistence = CGFloat(0.5)
    
    @objc var inputColor0 = CIColor(red: 0.5, green: 0.25, blue: 0)
    @objc var inputColor1 = CIColor(red: 0, green: 0, blue: 0.15)
    
    @objc var inputZ = CGFloat(0)
    
    override func setDefaults()
    {
        inputReciprocalScale = 50
        inputOctaves = 2
        inputPersistence = 0.5
        
        inputColor0 = CIColor(red: 0.5, green: 0.25, blue: 0)
        inputColor1 = CIColor(red: 0, green: 0, blue: 0.15)
    }
    
    override var attributes: [String : Any]
    {
        return [
            kCIAttributeFilterDisplayName: "Metal Perlin Noise",
            
            "inputReciprocalScale": [kCIAttributeIdentity: 0,
                kCIAttributeClass: "NSNumber",
                kCIAttributeDefault: 50,
                kCIAttributeDisplayName: "Scale",
                kCIAttributeMin: 10,
                kCIAttributeSliderMin: 10,
                kCIAttributeSliderMax: 100,
                                         kCIAttributeType: kCIAttributeTypeScalar] as [String : Any],
            
            "inputOctaves": [kCIAttributeIdentity: 1,
                kCIAttributeClass: "NSNumber",
                kCIAttributeDefault: 2,
                kCIAttributeDisplayName: "Octaves",
                kCIAttributeMin: 1,
                kCIAttributeSliderMin: 1,
                kCIAttributeSliderMax: 16,
                                 kCIAttributeType: kCIAttributeTypeScalar] as [String : Any],
            
            "inputPersistence": [kCIAttributeIdentity: 2,
                kCIAttributeClass: "NSNumber",
                kCIAttributeDefault: 0.5,
                kCIAttributeDisplayName: "Persistence",
                kCIAttributeMin: 0,
                kCIAttributeSliderMin: 0,
                kCIAttributeSliderMax: 1,
                                     kCIAttributeType: kCIAttributeTypeScalar] as [String : Any],
            
            "inputColor0": [kCIAttributeIdentity: 3,
                kCIAttributeClass: "CIColor",
                kCIAttributeDefault: CIColor(red: 0.5, green: 0.25, blue: 0),
                kCIAttributeDisplayName: "Color One",
                                kCIAttributeType: kCIAttributeTypeColor] as [String : Any],
            
            "inputColor1": [kCIAttributeIdentity: 4,
                kCIAttributeClass: "CIColor",
                kCIAttributeDefault: CIColor(red: 0, green: 0, blue: 0.15),
                kCIAttributeDisplayName: "Color Two",
                                kCIAttributeType: kCIAttributeTypeColor] as [String : Any],
            
            "inputZ": [kCIAttributeIdentity: 5,
                kCIAttributeClass: "NSNumber",
                kCIAttributeDefault: 1,
                kCIAttributeDisplayName: "Z Position",
                kCIAttributeMin: 0,
                kCIAttributeSliderMin: 0,
                kCIAttributeSliderMax: 1024,
                           kCIAttributeType: kCIAttributeTypeScalar] as [String : Any],
            
            "inputWidth": [kCIAttributeIdentity: 2,
                kCIAttributeClass: "NSNumber",
                kCIAttributeDefault: 640,
                kCIAttributeDisplayName: "Width",
                kCIAttributeMin: 100,
                kCIAttributeSliderMin: 100,
                kCIAttributeSliderMax: 2048,
                               kCIAttributeType: kCIAttributeTypeScalar] as [String : Any],
            
            "inputHeight": [kCIAttributeIdentity: 2,
                kCIAttributeClass: "NSNumber",
                kCIAttributeDefault: 640,
                kCIAttributeDisplayName: "Height",
                kCIAttributeMin: 100,
                kCIAttributeSliderMin: 100,
                kCIAttributeSliderMax: 2048,
                                kCIAttributeType: kCIAttributeTypeScalar] as [String : Any],
        ]
    }
}

// MARK: MetalKuwaharaFilter

class MetalKuwaharaFilter: MetalImageFilter
{
    init()
    {
        super.init(functionName: "kuwahara")
    }
    
    required init?(coder aDecoder: NSCoder)
    {       super.init(coder: aDecoder)
//        fatalError("init(coder:) has not been implemented")
    }
    
    @objc var inputRadius: CGFloat = 15
    
    override func setDefaults()
    {
        inputRadius = 15
    }
    
    override var attributes: [String : Any]
    {
        return [
            kCIAttributeFilterDisplayName: "Metal Kuwahara",
            
            "inputImage": [kCIAttributeIdentity: 0,
                kCIAttributeClass: "CIImage",
                kCIAttributeDisplayName: "Image",
                               kCIAttributeType: kCIAttributeTypeImage] as [String : Any],
            
            "inputRadius": [kCIAttributeIdentity: 0,
                kCIAttributeClass: "NSNumber",
                kCIAttributeDefault: 15,
                kCIAttributeDisplayName: "Radius",
                kCIAttributeMin: 0,
                kCIAttributeSliderMin: 0,
                kCIAttributeSliderMax: 30,
                                kCIAttributeType: kCIAttributeTypeScalar] as [String : Any],
        ]
    }
}

// MARK: MetalFilter types

class MetalGeneratorFilter: MetalFilter
{
    @objc var inputWidth: CGFloat = 640
    @objc var inputHeight: CGFloat = 640
    
    override func textureInvalid() -> Bool
    {
        if let textureDescriptor = textureDescriptor,
            textureDescriptor.width != Int(inputWidth)  ||
                textureDescriptor.height != Int(inputHeight)
        {
            return true
        }
        
        return false
    }
}

class MetalImageFilter: MetalFilter
{
    @objc var inputImage: CIImage?
    
    override func textureInvalid() -> Bool
    {
        if let textureDescriptor = textureDescriptor,
            let inputImage = inputImage,
            textureDescriptor.width != Int(inputImage.extent.width)  ||
                textureDescriptor.height != Int(inputImage.extent.height)
        {
            return true
        }
        
        return false
    }
}

// MARK: Base class

/// `MetalFilter` is a Core Image filter that uses a Metal compute function as its engine.
/// This version supports a single input image and an arbritrary number of `NSNumber`
/// parameters. Numeric parameters require a properly set `kCIAttributeIdentity` which
/// defines their buffer index into the Metal kernel.

class MetalFilter: CIFilter, MetalRenderable
{
    class override var supportsSecureCoding: Bool { get {
        // subclasses must  implement this
        // Core Data requires secureCoding to store the filter
        return true
    }}
    
    let device: MTLDevice = MTLCreateSystemDefaultDevice()!
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    
    lazy var ciMetalContext: CIContext =
    {
        [unowned self] in
        
        return CIContext(mtlDevice: self.device)
    }()
    
    lazy var commandQueue: MTLCommandQueue =
    {
        [unowned self] in
        
        return self.device.makeCommandQueue()
    }()!
    
    lazy var defaultLibrary: MTLLibrary =
    {
        [unowned self] in
        
        return self.device.makeDefaultLibrary()!
    }()
    
    var pipelineState: MTLComputePipelineState!
    
    let functionName: String
    
    var threadsPerThreadgroup: MTLSize!
    
    var threadgroupsPerGrid: MTLSize?
    
    var textureDescriptor: MTLTextureDescriptor?
    var kernelInputTexture: MTLTexture?
    var kernelOutputTexture: MTLTexture?

    override var outputImage: CIImage!
    {
        if textureInvalid()
        {
            self.textureDescriptor = nil
        }
        
        if let imageFilter = self as? MetalImageFilter,
            let inputImage = imageFilter.inputImage
        {
            return imageFromComputeShader(width: inputImage.extent.width,
                height: inputImage.extent.height,
                inputImage: inputImage)
        }
        
        if let generatorFilter = self as? MetalGeneratorFilter
        {
            return imageFromComputeShader(width: generatorFilter.inputWidth,
                height: generatorFilter.inputHeight,
                inputImage: nil)
        }
        
        return nil
    }
    
    init(functionName: String)
    {
        self.functionName = functionName
        
        super.init()
        
        let kernelFunction = defaultLibrary.makeFunction(name: self.functionName)!
        
        do
        {
            pipelineState = try self.device.makeComputePipelineState(function: kernelFunction)
            
            let maxTotalThreadsPerThreadgroup = Double(pipelineState.maxTotalThreadsPerThreadgroup)
            let threadExecutionWidth = Double(pipelineState.threadExecutionWidth)
            
            let threadsPerThreadgroupSide = stride(from: 0,
                to: Int(sqrt(maxTotalThreadsPerThreadgroup)),
                by: 1).reduce(16)
            {
                return (Double($1 * $1) / threadExecutionWidth).truncatingRemainder(dividingBy: 1) == 0 ? $1 : $0
            }
  
            threadsPerThreadgroup = MTLSize(width:threadsPerThreadgroupSide,
                height:threadsPerThreadgroupSide,
                depth:1)
        }
        catch
        {
//            fatalError("Unable to create pipeline state for kernel function \(functionName)")
            Logger(subsystem: LogSubsystem, category: LogCategory).fault("MetalFilter Unable to create pipeline state for kernel function \(functionName)")
        }
        
        
        
        if !(self is MetalImageFilter) && !(self is MetalGeneratorFilter)
        {
//            fatalError("MetalFilters must subclass either MetalImageFilter or MetalGeneratorFilter")
            Logger(subsystem: LogSubsystem, category: LogCategory).fault("MetalFilter MetalFilters must subclass either MetalImageFilter or MetalGeneratorFilter")
        }
    }
    
    required init?(coder aDecoder: NSCoder)
    {       functionName = "emptyInitString"
            super.init(coder: aDecoder)
//        fatalError("init(coder:) has not been implemented")
    }
    
    func textureInvalid() -> Bool
    {    return false
//        fatalError("textureInvalid() not implemented in MetalFilter")
    }
    
    func imageFromComputeShader(width: CGFloat, height: CGFloat, inputImage: CIImage?) -> CIImage
    {
        if textureDescriptor == nil
        {
            textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                width: Int(width),
                height: Int(height),
                mipmapped: false)
            
            kernelInputTexture = device.makeTexture(descriptor: textureDescriptor!)
            kernelOutputTexture = device.makeTexture(descriptor: textureDescriptor!)
            
            threadgroupsPerGrid = MTLSizeMake(
                textureDescriptor!.width / threadsPerThreadgroup.width,
                textureDescriptor!.height / threadsPerThreadgroup.height, 1)
        }

        let commandBuffer = commandQueue.makeCommandBuffer()

        if let imageFilter = self as? MetalImageFilter,
            let inputImage = imageFilter.inputImage
        {
            ciMetalContext.render(inputImage,
                             to: kernelInputTexture!,
                commandBuffer: commandBuffer,
                bounds: inputImage.extent,
                colorSpace: colorSpace)
        }
        
        let commandEncoder = commandBuffer?.makeComputeCommandEncoder()
        
        commandEncoder?.setComputePipelineState(pipelineState)
        
        // populate float buffers using kCIAttributeIdentity as buffer index
        for inputKey in inputKeys where (attributes[inputKey] as! [String:AnyObject])[kCIAttributeClass] as? String == "NSNumber"
        {
            if let bufferIndex = (attributes[inputKey] as! [String:AnyObject])[kCIAttributeIdentity] as? Int,
                var bufferValue = value(forKey: inputKey) as? Float
            {
                let buffer = device.makeBuffer(bytes: &bufferValue,
                                               length: MemoryLayout<Float>.size.self,
                    options: MTLResourceOptions(rawValue: UInt(MTLCPUCacheMode.defaultCache.rawValue)))
                
                commandEncoder?.setBuffer(buffer, offset: 0, index: bufferIndex)
            }
        }
        
        // populate color buffers using kCIAttributeIdentity as buffer index
        for inputKey in inputKeys where (attributes[inputKey] as! [String:AnyObject])[kCIAttributeClass] as? String == "CIColor"
        {
            if let bufferIndex = (attributes[inputKey] as! [String:AnyObject])[kCIAttributeIdentity] as? Int,
                let bufferValue = value(forKey: inputKey) as? CIColor
            {
                var color = SIMD4(Float(bufferValue.red),
                    Float(bufferValue.green),
                    Float(bufferValue.blue),
                    Float(bufferValue.alpha))
                
                let buffer = device.makeBuffer(bytes: &color,
                                               length: MemoryLayout<SIMD4<Float>>.size.self,
                    options: MTLResourceOptions(rawValue: UInt(MTLCPUCacheMode.defaultCache.rawValue)))
                
                commandEncoder?.setBuffer(buffer, offset: 0, index: bufferIndex)
            }
        }

        if self is MetalImageFilter
        {
            commandEncoder?.setTexture(kernelInputTexture, index: 0)
            commandEncoder?.setTexture(kernelOutputTexture, index: 1)
        }
        else if self is MetalGeneratorFilter
        {
            commandEncoder?.setTexture(kernelOutputTexture, index: 0)
        }

        commandEncoder?.dispatchThreadgroups(threadgroupsPerGrid!,
            threadsPerThreadgroup: threadsPerThreadgroup)
        
        commandEncoder?.endEncoding()
        
        commandBuffer?.commit()
     
        return CIImage(mtlTexture: kernelOutputTexture!,
                       options: [CIImageOption.colorSpace: colorSpace])!
    }
}

#else
    class MetalFilter: CIFilter
    {
    }
    
#endif

protocol MetalRenderable {
    
}
