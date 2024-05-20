//
//  MetalHelper.swift
//  TBDR
//
//  Created by Ceylo on 20/05/2024.
//

import Metal
import MetalKit

class MetalHelper {
    static let shared = MetalHelper()
    static let layerCount = 50
    
    let device: MTLDevice
    // Multiple textures to simulate layers with distinct data
    let layers: [MTLTexture]
    
    private init() {
        self.device = MTLCreateSystemDefaultDevice()!
        
        let loader = MTKTextureLoader(device: device)
        let textureOptions: [MTKTextureLoader.Option : Any] = [
            .origin: MTKTextureLoader.Origin.topLeft,
            .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue),
            // read-write as layers are typicallyed mutated
            .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.union(.shaderWrite).rawValue)
        ]
        
        self.layers = (0..<Self.layerCount).map { i in
            let cat = try! loader
                .newTexture(name: "Isidor", scaleFactor: 1, bundle: nil, options: textureOptions)
            cat.label = "Isidor #\(i)"
            return cat
        }
    }
}

extension MTLDevice {
    func makeComputePipelineState(function: MTLFunction, label: String) throws -> MTLComputePipelineState {
        let desc = MTLComputePipelineDescriptor()
        desc.computeFunction = function
        desc.label = label
        let state = try makeComputePipelineState(descriptor: desc, options: [])
        return state.0
    }
}

extension MTLCommandBuffer {
    func encodeCompute(_ label: String, _ closure: (_ encoder: MTLComputeCommandEncoder) -> Void) {
        let encoder = makeComputeCommandEncoder()!
        encoder.label = label
        closure(encoder)
        encoder.endEncoding()
    }
    
    func encodeRender(_ label: String, descriptor: MTLRenderPassDescriptor,
                _ closure: (_ encoder: MTLRenderCommandEncoder) -> Void) {
        let encoder = makeRenderCommandEncoder(descriptor: descriptor)!
        encoder.label = label
        closure(encoder)
        encoder.endEncoding()
    }
}

extension MTLComputeCommandEncoder {
    func dispatchThreadsForWorking(on texture: MTLTexture, with state: MTLComputePipelineState) {
        let w = state.threadExecutionWidth
        let h = state.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
        let threadsPerGrid = MTLSize(width: texture.width, height: texture.height, depth: 1)
        dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    }
}
