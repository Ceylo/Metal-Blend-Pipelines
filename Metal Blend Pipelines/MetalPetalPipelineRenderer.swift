//
//  MetalPetalPipelineRenderer.swift
//  Metal Blend Pipelines
//
//  Created by Ceylo on 15/05/2024.
//

import SwiftUI
import MetalKit
import MetalPetal

final class MetalPetalPipelineRenderer : NSObject, MTLRenderer {
    let drawablePixelFormat: MTLPixelFormat = .bgra8Unorm_srgb
    let drawableIsWritable: Bool = true
    let drawableColorSpace: CGColorSpace = .init(name: CGColorSpace.sRGB)!
    
    let helper: MetalHelper
    let commandQueue: MTLCommandQueue
    // MetalPetal doesn't give the option to render with a provided MTLCommandBuffer,
    // so this is not used
    var executionMode: MTLCommandScheduler.Mode = .unconstrained
    let context: MTIContext
    
    override init() {
        let helper = MetalHelper.shared
        let device = helper.device
        self.helper = helper
        self.commandQueue = device.makeCommandQueue()!
        
        let options = MTIContextOptions()
        options.coreImageContextOptions = [
            .cacheIntermediates: NSNumber(value: false),
            .outputColorSpace: drawableColorSpace,
            .workingColorSpace: drawableColorSpace,
            .outputPremultiplied: NSNumber(value: false)
        ]
        options.workingPixelFormat = .rgba16Float
        options.enablesRenderGraphOptimization = true
        
        context = try! MTIContext(
            device: device,
            options: options
        )
        
        super.init()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        let cb = commandQueue.makeCommandBuffer()!

        guard let drawable = view.currentDrawable else {
            return
        }

        let graph = buildRenderingGraph()
            .cropped(to: .pixel(CGRect(origin: .zero, size: view.drawableSize)))!
        
        try! context.startTask(toRender: graph, to: drawable.texture, destinationAlphaType: .nonPremultiplied)
        
        cb.present(drawable)
        cb.commit()
    }
    
    func buildRenderingGraph() -> MTIImage {
        var output = helper.layers[0].mtiImage
        
        for layer in helper.layers.dropFirst().dropLast() {
            output = encodeBlend(of: output, and: layer.mtiImage)
        }
        
        output = encodeBlend(of: output, and: helper.layers.last!.mtiImage)
        return output
    }
    
    func encodeBlend(of tex1: MTIImage, and tex2: MTIImage) -> MTIImage {
        MetalPetalCustomBlendFilter(foregroundImage: tex2, backgroundImage: tex1)
            .outputImage!
    }
}

extension MTLTexture {
    var mtiImage: MTIImage {
        MTIImage(texture: self, alphaType: .nonPremultiplied)
            .withCachePolicy(.transient)
    }
}

class MetalPetalCustomBlendFilter: MTIFilter {
    var outputPixelFormat: MTLPixelFormat = .rgba8Unorm_srgb
    
    internal init(foregroundImage: MTIImage, backgroundImage: MTIImage) {
        self.foregroundImage = foregroundImage
        self.backgroundImage = backgroundImage
    }
    
    var foregroundImage: MTIImage
    var backgroundImage: MTIImage
    
    private static let kernel: MTIRenderPipelineKernel = {
        MTIRenderPipelineKernel(
            vertexFunctionDescriptor: .passthroughVertex,
            fragmentFunctionDescriptor: .init(name: "metalPetalBlend", in: Bundle.main)
        )
    }()
    
    var outputImage: MTIImage? {
        Self.kernel.apply(
            to: [backgroundImage, foregroundImage],
            outputDimensions: backgroundImage.dimensions,
            outputPixelFormat: outputPixelFormat
        )
    }
}
