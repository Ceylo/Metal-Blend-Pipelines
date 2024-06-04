//
//  ComputePipelineRenderer.swift
//  TBDR
//
//  Created by Ceylo on 15/05/2024.
//

import SwiftUI
import MetalKit

final class ComputePipelineRenderer : NSObject, MTLRenderer {
    let drawablePixelFormat: MTLPixelFormat = .bgra8Unorm_srgb
    let drawableIsWritable: Bool = true
    let drawableColorSpace: CGColorSpace = .init(name: CGColorSpace.sRGB)!
    
    let helper: MetalHelper
    var intermediateImage: MTLTexture
    let commandQueue: MTLCommandQueue
    var scheduler: MTLCommandScheduler
    var executionMode: MTLCommandScheduler.Mode = .unconstrained {
        didSet { scheduler = .init(device: helper.device, mode: executionMode) }
    }
    // Make several pipelines states to simulate different blend functions
    let pipelineStates: [MTLComputePipelineState]
    
    override init() {
        let helper = MetalHelper.shared
        let device = helper.device
        self.helper = helper
        self.commandQueue = device.makeCommandQueue()!
        self.scheduler = .init(device: device, mode: executionMode)
        
        let textureDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: 4000,
            height: 2000,
            mipmapped: false
        )
        textureDesc.usage = [.shaderRead, .shaderWrite]
        textureDesc.storageMode = .private
        intermediateImage = device.makeTexture(descriptor: textureDesc)!
        intermediateImage.label = "Intermediate image"
        
        let library = device.makeDefaultLibrary()!
        let kernelFunc = library.makeFunction(name: "kernelFunc")!
        pipelineStates = (0..<10).map { i in
            try! device.makeComputePipelineState(
                function: kernelFunc,
                label: "Compute pipeline #\(i)"
            )
        }
        
        super.init()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    var dispatchCalls = 0
    func draw(in view: MTKView) {
        let cb = commandQueue.makeCommandBuffer()!
        dispatchCalls = 0
        var input1 = helper.layers[0]
        
        let drawable: CAMetalDrawable? = scheduler.withManagedCommandsScheduling(for: cb) {
            cb.encodeCompute("Merge render") { encoder in
                for layer in helper.layers.dropFirst().dropLast() {
                    encodeBlend(of: input1, and: layer, into: intermediateImage, using: encoder)
                    input1 = intermediateImage
                }
            }
            
            guard let drawable = view.currentDrawable else {
                return nil
            }
            
            cb.encodeCompute("Final render") { encoder in
                encodeBlend(of: input1, and: helper.layers.last!, into: drawable.texture, using: encoder)
            }
            return drawable
        }
        
        if let drawable {
            cb.present(drawable)
        }
        cb.commit()
    }
    
    func encodeBlend(
        of tex1: MTLTexture,
        and tex2: MTLTexture,
        into output: MTLTexture,
        using encoder: MTLComputeCommandEncoder
    ) {
        let pipelineState = pipelineStates[dispatchCalls % pipelineStates.count]
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(tex1, index: 0)
        encoder.setTexture(tex2, index: 1)
        encoder.setTexture(output, index: 2)
        encoder.dispatchThreadsForWorking(on: output, with: pipelineState)
        dispatchCalls += 1
    }
}

#Preview {
    MetalView<ComputePipelineRenderer>(serialGPUWork: true)
}
