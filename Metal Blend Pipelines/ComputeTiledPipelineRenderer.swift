//
//  ComputeTiledPipelineRenderer.swift
//  Metal Blend Pipelines
//
//  Created by Ceylo on 31/05/2024.
//

import SwiftUI
import MetalKit

final class ComputeTiledPipelineRenderer : NSObject, MTLRenderer {
    let drawablePixelFormat: MTLPixelFormat = .bgra8Unorm_srgb
    let drawableIsWritable: Bool = true
    let drawableColorSpace: CGColorSpace = .init(name: CGColorSpace.sRGB)!
    
    let helper: MetalHelper
    var intermediateImages: [MTLTexture]
    let commandQueue: MTLCommandQueue
    var scheduler: MTLCommandScheduler
    var executionMode: MTLCommandScheduler.Mode = .unconstrained {
        didSet { scheduler = .init(device: helper.device, mode: executionMode) }
    }
    // Make several pipelines states to simulate different blend functions
    let pipelineStates: [MTLComputePipelineState]
    static let workingSize = MTLSize(width: 4000, height: 2000, depth: 1)
    static let tileCount = 4
    static var tileSize: MTLSize { .init(width: workingSize.width / 2, height: workingSize.height / 2, depth: workingSize.depth)}
    
    override init() {
        let helper = MetalHelper.shared
        let device = helper.device
        self.helper = helper
        self.commandQueue = device.makeCommandQueue()!
        self.scheduler = .init(device: device, mode: executionMode)
        
        let textureDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: Self.tileSize.width,
            height: Self.tileSize.height,
            mipmapped: false
        )
        textureDesc.usage = [.shaderRead, .shaderWrite]
        textureDesc.storageMode = .private
        intermediateImages = (0..<Self.tileCount).map { i in
            let texture = device.makeTexture(descriptor: textureDesc)!
            texture.label = "Intermediate image #\(i)"
            return texture
        }
        
        let library = device.makeDefaultLibrary()!
        let kernelFunc = library.makeFunction(name: "kernelFuncTiled")!
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
        var input1 = Array(repeating: helper.layers[0], count: Self.tileCount)
        
        let drawable: CAMetalDrawable? = scheduler.withManagedCommandsScheduling(for: cb) {
            cb.encodeCompute("Merge render") { encoder in
                for layer in helper.layers.dropFirst().dropLast() {
                    // A bit hacky… src1 is a full image on the first pass only, and is then a tile,
                    // because we skipped making tiles for all input textures, and tile output is the input in next pass.
                    let src1NeedsTileIndex = input1[0].size.width > Self.tileSize.width
                    for tile in 0..<Self.tileCount {
                        encodeBlend(
                            of: input1[tile],
                            and: layer,
                            into: intermediateImages[tile],
                            using: encoder,
                            src1TileIndex: src1NeedsTileIndex ? tile : 0,
                            src2TileIndex: tile,
                            dstTileIndex: 0
                        )
                    }
                    input1 = intermediateImages
                }
            }
            
            guard let drawable = view.currentDrawable else {
                return nil
            }
            
            cb.encodeCompute("Final render") { encoder in
                for tile in 0..<Self.tileCount {
                    encodeBlend(
                        of: input1[tile],
                        and: helper.layers.last!,
                        into: drawable.texture,
                        using: encoder,
                        src1TileIndex: 0,
                        src2TileIndex: tile,
                        dstTileIndex: tile,
                        gridSize: Self.tileSize
                    )
                }
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
        using encoder: MTLComputeCommandEncoder,
        src1TileIndex: Int,
        src2TileIndex: Int,
        dstTileIndex: Int,
        gridSize: MTLSize? = nil
    ) {
        let pipelineState = pipelineStates[dispatchCalls % pipelineStates.count]
        let gridSize = gridSize ?? output.size
        
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(tex1, index: 0)
        encoder.setTexture(tex2, index: 1)
        encoder.setTexture(output, index: 2)
        var params = TiledComputeBlendParams(
            src1TileIndex: UInt16(src1TileIndex),
            src2TileIndex: UInt16(src2TileIndex),
            dstTileIndex: UInt16(dstTileIndex),
            tileWidth: UInt16(Self.tileSize.width),
            tileHeight: UInt16(Self.tileSize.height)
        )
        encoder.setBytes(&params, length: MemoryLayout<TiledComputeBlendParams>.stride, index: 0)
        encoder.dispatchThreadsForWorking(on: gridSize, with: pipelineState)
        dispatchCalls += 1
    }
}
