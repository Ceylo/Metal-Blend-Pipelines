//
//  RenderPipelineRenderer.swift
//  TBDR
//
//  Created by Ceylo on 15/05/2024.
//

import SwiftUI
import MetalKit

class RenderPipelineWithTileMemoryRenderer : NSObject, MTLRenderer {
    let drawablePixelFormat: MTLPixelFormat = .bgra8Unorm_srgb
    let drawableIsWritable: Bool = false
    let drawableColorSpace: CGColorSpace = .init(name: CGColorSpace.sRGB)!
    
    let helper: MetalHelper
    var intermediateImages: [MTLTexture]
    let commandQueue: MTLCommandQueue
    // Make several pipelines states to simulate different blend functions
    let initPipelineStates: [MTLRenderPipelineState]
    let pipelineStates: [MTLRenderPipelineState]
    let vertices: MTLBuffer
    let workingSize = MTLSize(width: 4000, height: 2000, depth: 1)
    
    required override init() {
        let helper = MetalHelper.shared
        let device = helper.device
        self.helper = helper
        self.commandQueue = device.makeCommandQueue()!
        
        let textureDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm_srgb,
            width: workingSize.width,
            height: workingSize.height,
            mipmapped: false
        )
        textureDesc.usage = [.shaderRead, .renderTarget]
        textureDesc.storageMode = .memoryless
        // Two intermediate textures, used either as source or dst in the shader as,
        // just like for regular textures, reading and writing to/from the same texture
        // within a draw call is undefined behavior.
        // Theoretically we could use the framebuffer as tile buffer but we'd then need to be
        // careful to always write to the framebuffer in the last pass.
        // Given that memoryless textures are… memoryless, let's keep it simple :)
        intermediateImages = [
            device.makeTexture(descriptor: textureDesc)!,
            device.makeTexture(descriptor: textureDesc)!
        ]
        intermediateImages[0].label = "Intermediate image 0"
        intermediateImages[1].label = "Intermediate image 1"
        
        let desc = MTLRenderPipelineDescriptor()
        let library = device.makeDefaultLibrary()!
        desc.vertexFunction = library.makeFunction(name: "vertexFunc")!
        desc.fragmentFunction = library.makeFunction(name: "tiledFragmentFunc")!
        desc.colorAttachments[0].pixelFormat = drawablePixelFormat
        desc.colorAttachments[1].pixelFormat = drawablePixelFormat
        desc.colorAttachments[2].pixelFormat = drawablePixelFormat
        
        pipelineStates = (0..<10).map { i in
            desc.label = "Tiled render pipeline #\(i)"
            let state = try! device.makeRenderPipelineState(descriptor: desc)
            return state
        }
        
        desc.fragmentFunction = library.makeFunction(name: "tiledFragmentInit")!
        initPipelineStates = (0..<10).map { i in
            desc.label = "Init tiled render pipeline #\(i)"
            let state = try! device.makeRenderPipelineState(descriptor: desc)
            return state
        }
        
        let w = Float(workingSize.width)
        let h = Float(workingSize.height)
        let vertices = [
            Vertex(position: float4(0, 0, 0, 1), texCoord: float2(0, 1)),
            Vertex(position: float4(w, 0, 0, 1), texCoord: float2(1, 1)),
            Vertex(position: float4(w, h, 0, 1), texCoord: float2(1, 0)),
            Vertex(position: float4(0, 0, 0, 1), texCoord: float2(0, 1)),
            Vertex(position: float4(0, h, 0, 1), texCoord: float2(0, 0))
        ]
        self.vertices = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<Vertex>.stride * vertices.count,
            options: [.storageModeShared]
        )!
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    var drawCalls = 0
    func draw(in view: MTKView) {
        let cb = commandQueue.makeCommandBuffer()!
        guard let renderPass = view.currentRenderPassDescriptor else { return }
        renderPass.colorAttachments[0].loadAction = .clear
        
        renderPass.colorAttachments[1].texture = intermediateImages[0]
        renderPass.colorAttachments[1].loadAction = .clear
        renderPass.colorAttachments[1].storeAction = .dontCare
        renderPass.colorAttachments[2].texture = intermediateImages[1]
        renderPass.colorAttachments[2].loadAction = .clear
        renderPass.colorAttachments[2].storeAction = .dontCare
        
        drawCalls = 0
        defer {
            print("Encoded \(drawCalls) draw calls")
        }
        
        cb.encodeRender("Render", descriptor: renderPass) { encoder in
            let size = renderPass.colorAttachments[0].texture!.size
            encodeInitBlend(of: helper.layers[0], and: helper.layers[1], using: encoder, drawableSize: size)
            for (index, layer) in helper.layers.dropFirst(2).enumerated() {
                encodeBlend(of: layer, using: encoder, drawableSize: size, passIndex: index)
            }
        }
        
        guard let drawable = view.currentDrawable else {
            return
        }
        cb.present(drawable)
        cb.commit()
    }
    
    func encodeBlend(
        of tex1: MTLTexture,
        using encoder: MTLRenderCommandEncoder,
        drawableSize: MTLSize,
        passIndex: Int
    ) {
        assert(drawableSize.depth == 1)
        var drawableSizeBytes = float2(Float(drawableSize.width), Float(drawableSize.height))
        var yOffset = Float(drawableSize.height - workingSize.height)
        var passIndex = UInt16(passIndex)
        
        encoder.setRenderPipelineState(pipelineStates[drawCalls % pipelineStates.count])
        encoder.setVertexBuffer(vertices, offset: 0, index: 0)
        encoder.setVertexBytes(&drawableSizeBytes, length: MemoryLayout<float2>.stride, index: 1)
        encoder.setVertexBytes(&yOffset, length: MemoryLayout<Float>.stride, index: 2)
        encoder.setFragmentTexture(tex1, index: 0)
        encoder.setFragmentTexture(nil, index: 1)
        encoder.setFragmentBytes(&passIndex, length: MemoryLayout<UInt16>.stride, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 5)
        drawCalls += 1
    }
    
    func encodeInitBlend(
        of tex1: MTLTexture,
        and tex2: MTLTexture,
        using encoder: MTLRenderCommandEncoder,
        drawableSize: MTLSize
    ) {
        assert(drawableSize.depth == 1)
        var drawableSizeBytes = float2(Float(drawableSize.width), Float(drawableSize.height))
        var yOffset = Float(drawableSize.height - workingSize.height)
        
        encoder.setRenderPipelineState(initPipelineStates[drawCalls % pipelineStates.count])
        encoder.setVertexBuffer(vertices, offset: 0, index: 0)
        encoder.setVertexBytes(&drawableSizeBytes, length: MemoryLayout<float2>.stride, index: 1)
        encoder.setVertexBytes(&yOffset, length: MemoryLayout<Float>.stride, index: 2)
        encoder.setFragmentTexture(tex1, index: 0)
        encoder.setFragmentTexture(tex2, index: 1)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 5)
        drawCalls += 1
    }
}

#Preview {
    MetalView<RenderPipelineWithTileMemoryRenderer>()
}
