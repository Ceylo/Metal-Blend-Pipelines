//
//  MetalView.swift
//  TBDR
//
//  Created by Ceylo on 15/05/2024.
//

import SwiftUI
import MetalKit

class RenderPipelineRenderer : NSObject, MTLRenderer {
    let drawablePixelFormat: MTLPixelFormat = .bgra8Unorm_srgb
    let drawableIsWritable: Bool = false
    let drawableColorSpace: CGColorSpace = .init(name: CGColorSpace.sRGB)!
    
    let helper: MetalHelper
    var intermediateImage: MTLTexture
    let commandQueue: MTLCommandQueue
    // Make several pipelines states to simulate different blend functions
    let pipelineStates: [MTLRenderPipelineState]
    let vertices: MTLBuffer
    
    required override init() {
        let helper = MetalHelper.shared
        let device = helper.device
        self.helper = helper
        self.commandQueue = device.makeCommandQueue()!
        
        let textureDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm_srgb,
            width: 4000,
            height: 2000,
            mipmapped: false
        )
        textureDesc.usage = [.shaderRead, .renderTarget]
        textureDesc.storageMode = .private
        intermediateImage = device.makeTexture(descriptor: textureDesc)!
        intermediateImage.label = "Intermediate image"
        
        let desc = MTLRenderPipelineDescriptor()
        let library = device.makeDefaultLibrary()!
        desc.vertexFunction = library.makeFunction(name: "vertexFunc")!
        desc.fragmentFunction = library.makeFunction(name: "fragmentFunc")!
        desc.colorAttachments[0].pixelFormat = drawablePixelFormat
        
        pipelineStates = (0..<10).map { i in
            desc.label = "Render pipeline #\(i)"
            let state = try! device.makeRenderPipelineState(descriptor: desc)
            return state
        }
        
        let vertices = [
            Vertex(position: float4(-1, -1, 0.5, 1), texCoord: float2(0, 1)),
            Vertex(position: float4( 1, -1, 0.5, 1), texCoord: float2(1, 1)),
            Vertex(position: float4( 1,  1, 0.5, 1), texCoord: float2(1, 0)),
            Vertex(position: float4(-1, -1, 0.5, 1), texCoord: float2(0, 1)),
            Vertex(position: float4(-1,  1, 0.5, 1), texCoord: float2(0, 0))
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
        renderPass.colorAttachments[0].loadAction = .dontCare
        
        drawCalls = 0
        defer {
            print("Encoded \(drawCalls) draw calls")
        }
        var input1 = helper.layers[0]
        
        let desc = MTLRenderPassDescriptor()
        desc.colorAttachments[0].texture = intermediateImage
        desc.colorAttachments[0].loadAction = .dontCare
        
        cb.encodeRender("Merge render", descriptor: desc) { encoder in
            for layer in helper.layers.dropFirst().dropLast() {
                encodeBlend(of: input1, and: layer, using: encoder)
                input1 = intermediateImage
            }
        }
        
        cb.encodeRender("Final render", descriptor: renderPass) { encoder in
            encodeBlend(of: input1, and: helper.layers.last!, using: encoder)
        }
        
        guard let drawable = view.currentDrawable else {
            return
        }
        cb.present(drawable)
        cb.commit()
    }
    
    func encodeBlend(
        of tex1: MTLTexture,
        and tex2: MTLTexture,
        using encoder: MTLRenderCommandEncoder
    ) {
        encoder.setRenderPipelineState(pipelineStates[drawCalls % pipelineStates.count])
        encoder.setVertexBuffer(vertices, offset: 0, index: 0)
        encoder.setFragmentTexture(tex1, index: 0)
        encoder.setFragmentTexture(tex2, index: 1)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 5)
        drawCalls += 1
    }
}

#Preview {
    MetalView<RenderPipelineRenderer>()
}
