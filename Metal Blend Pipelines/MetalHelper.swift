//
//  MetalHelper.swift
//  Metal Blend Pipelines
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
            let block = try! loader
                .newTexture(name: "block_\(i)", scaleFactor: 1, bundle: nil, options: textureOptions)
            block.label = "Block #\(i)"
            return block
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
        dispatchThreadsForWorking(on: texture.size, with: state)
    }
    
    func dispatchThreadsForWorking(on gridSize: MTLSize, with state: MTLComputePipelineState) {
        let w = state.threadExecutionWidth
        let h = state.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
        dispatchThreads(gridSize, threadsPerThreadgroup: threadsPerThreadgroup)
    }
}

extension MTLTexture {
    var size: MTLSize {
        MTLSize(width: width, height: height, depth: depth)
    }
}

extension MTLSize {
    static func /(size: MTLSize, denominator: Int) -> MTLSize {
        .init(width: size.width / denominator, height: size.height / denominator, depth: size.depth)
    }
}

class MTLCommandScheduler {
    private var lastEncodedSignalValue: UInt64?
    private let event: MTLEvent
    private let mode: Mode
    
    enum Mode {
        /// A scheduling mode where MTLCommandBuffers are always executed one after another.
        case serial
        /// A scheduling mode where GPU drivers are free to execute GPU work serially or concurrently.
        case unconstrained
    }
    
    init(device: MTLDevice, mode: Mode) {
        self.event = device.makeEvent()!
        self.mode = mode
    }
    
    func withManagedCommandsScheduling<T>(for commandBuffer: MTLCommandBuffer, _ gpuEncoding: () -> T) -> T {
        guard mode == .serial else {
            return gpuEncoding()
        }
        
        if let lastEncodedSignalValue {
            commandBuffer.encodeWaitForEvent(event, value: lastEncodedSignalValue)
        }
        let result = gpuEncoding()
        
        let newEventValue = (lastEncodedSignalValue ?? 0) + 1
        commandBuffer.encodeSignalEvent(event, value: newEventValue)
        lastEncodedSignalValue = newEventValue
        return result
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
