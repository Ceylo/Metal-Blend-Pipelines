//
//  RenderPipelineRenderer.swift
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
    var intermediateImages: [MTLTexture]
    let commandQueue: MTLCommandQueue
    // Make several pipelines states to simulate different blend functions
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
        textureDesc.storageMode = .private
        intermediateImages = [
            device.makeTexture(descriptor: textureDesc)!,
            device.makeTexture(descriptor: textureDesc)!
        ]
        intermediateImages[0].label = "Intermediate image 0"
        intermediateImages[1].label = "Intermediate image 1"
        
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
        renderPass.colorAttachments[0].loadAction = .dontCare
        
        drawCalls = 0
        defer {
            print("Encoded \(drawCalls) draw calls")
        }
        var input1 = helper.layers[0]
        let intermediateImageSize = intermediateImages[0].size
        
        for (index, layer) in helper.layers.dropFirst().dropLast().enumerated() {
            let desc = MTLRenderPassDescriptor()
            let output = intermediateImages[index % 2]
            desc.colorAttachments[0].texture = output
            desc.colorAttachments[0].loadAction = .dontCare
            
            cb.encodeRender("Merge render", descriptor: desc) { encoder in
                encodeBlend(of: input1, and: layer, using: encoder, drawableSize: intermediateImageSize)
                input1 = output
            }
        }
        
        cb.encodeRender("Final render", descriptor: renderPass) { encoder in
            let size = renderPass.colorAttachments[0].texture!.size
            encodeBlend(of: input1, and: helper.layers.last!, using: encoder, drawableSize: size)
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
        using encoder: MTLRenderCommandEncoder,
        drawableSize: MTLSize
    ) {
        assert(drawableSize.depth == 1)
        var drawableSizeBytes = float2(Float(drawableSize.width), Float(drawableSize.height))
        var yOffset = Float(drawableSize.height - workingSize.height)
        
        encoder.setRenderPipelineState(pipelineStates[drawCalls % pipelineStates.count])
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
    MetalView<RenderPipelineRenderer>()
}
