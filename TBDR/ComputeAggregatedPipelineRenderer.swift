//
//  ComputeAggregatedPipelineRenderer.swift
//  TBDR
//
//  Created by Ceylo on 15/05/2024.
//

import SwiftUI
import MetalKit

class ComputeAggregatedPipelineRenderer : NSObject, MTLRenderer {
    let drawablePixelFormat: MTLPixelFormat = .bgra8Unorm_srgb
    let drawableIsWritable: Bool = true
    let drawableColorSpace: CGColorSpace = .init(name: CGColorSpace.sRGB)!
    
    let helper: MetalHelper
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLComputePipelineState
    
    override required init() {
        let helper = MetalHelper.shared
        let device = helper.device
        self.helper = helper
        self.commandQueue = device.makeCommandQueue()!
        
        let library = device.makeDefaultLibrary()!
        let kernelFunc = library.makeFunction(name: "aggregatedKernelFunc")!
        pipelineState = try! device.makeComputePipelineState(
            function: kernelFunc,
            label: "Aggregated compute pipeline"
        )
        
        super.init()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    var dispatchCalls = 0
    func draw(in view: MTKView) {
        let cb = commandQueue.makeCommandBuffer()!
        dispatchCalls = 0
        
        guard let drawable = view.currentDrawable else {
            return
        }
        
        cb.encodeCompute("Final render") { encoder in
            encodeBlend(of: helper.layers, into: drawable.texture, using: encoder)
        }
        
        cb.present(drawable)
        cb.commit()
    }
    
    func encodeBlend(
        of textures: [MTLTexture],
        into output: MTLTexture,
        using encoder: MTLComputeCommandEncoder
    ) {
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(output, index: 0)
        encoder.setTextures(textures, range: 1..<textures.count+1)
        encoder.dispatchThreadsForWorking(on: output, with: pipelineState)
        dispatchCalls += 1
    }
}

#Preview {
    MetalView<ComputeAggregatedPipelineRenderer>()
}
