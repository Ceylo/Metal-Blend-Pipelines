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
                .newTexture(name: "block_\(i)", scaleFactor: 1, bundle: nil, options: textureOptions)
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

import SwiftImage

func generateLayers() {
    let layerCount = 50
    let width = 4000
    let height = 2000
    let pixelPerBlock = (width * height) / layerCount
    let blockSize = Int(floor(sqrt(Float(pixelPerBlock))))
    let blocksPerLine = width / blockSize
    
    DispatchQueue.concurrentPerform(iterations: layerCount) { blockIndex in
        let yStart = (blockIndex / blocksPerLine) * blockSize
        let xStart = (blockIndex % blocksPerLine) * blockSize
        let yEnd = yStart + blockSize
        let xEnd = xStart + blockSize
        
        let img = Image<RGBA<UInt8>>(width: width, height: height) { x, y in
            if x >= xStart && x < xEnd && y >= yStart && y < yEnd {
                switch (x % 8, y % 8) {
                case (0..<4, 0..<4): return .init(red: 255, green: 0, blue: 0, alpha: 255)
                case (0..<4, 4..<8): return .init(red: 0, green: 255, blue: 0, alpha: 255)
                case (4..<8, 4..<8): return .init(red: 0, green: 0, blue: 255, alpha: 255)
                case (4..<8, 0..<4): return .init(gray: 0, alpha: 0)
                case (_, _):
                    fatalError()
                }
            } else {
                return .init(gray: 0, alpha: 0)
            }
        }
        let url = URL.temporaryDirectory.appending(component: "block_\(blockIndex).png")
        print(url)
        try! img.write(to: url, atomically: true, format: .png)
    }
}
