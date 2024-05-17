//
//  MetalView.swift
//  TBDR
//
//  Created by Ceylo on 15/05/2024.
//

import SwiftUI
import MetalKit
import MetalMath

struct MetalView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: NSViewRepresentableContext<MetalView>) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.device = MTLCreateSystemDefaultDevice()!
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.colorPixelFormat = context.coordinator.pixelFormat
        mtkView.colorspace = context.coordinator.colorSpace
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: NSViewRepresentableContext<MetalView>) {
    }
    
    class Coordinator : NSObject, MTKViewDelegate {
        let parent: MetalView
        let device: MTLDevice
        let isidor: MTLTexture
        let cats: MTLTexture
        let commandQueue: MTLCommandQueue
        let pipelineState: MTLRenderPipelineState
        let pixelFormat: MTLPixelFormat = .bgra8Unorm_srgb
        let colorSpace: CGColorSpace = .init(name: CGColorSpace.sRGB)!
        let vertices: [Vertex]
        
        init(_ parent: MetalView) {
            self.parent = parent
            self.device = MTLCreateSystemDefaultDevice()!
            self.commandQueue = device.makeCommandQueue()!
            
            let loader = MTKTextureLoader(device: device)
            isidor = try! loader.newTexture(
                name: "Isidor",
                scaleFactor: 1,
                bundle: nil,
                options: [.origin: MTKTextureLoader.Origin.bottomLeft]
            )
            cats = try! loader.newTexture(
                name: "cats",
                scaleFactor: 1,
                bundle: nil,
                options: [.origin: MTKTextureLoader.Origin.bottomLeft]
            )
            
            let library = device.makeDefaultLibrary()!
            let vertexFunc = library.makeFunction(name: "vertexFunc")!
            let fragmentFunc = library.makeFunction(name: "fragmentFunc")!
            
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vertexFunc
            desc.fragmentFunction = fragmentFunc
            desc.colorAttachments[0].pixelFormat = pixelFormat
            
            pipelineState = try! device.makeRenderPipelineState(descriptor: desc)
            vertices = [
                Vertex(position: float4(-1, -1, 0.5, 1), texCoord: float2(0, 0)),
                Vertex(position: float4( 1, -1, 0.5, 1), texCoord: float2(1, 0)),
                Vertex(position: float4( 1,  1, 0.5, 1), texCoord: float2(1, 1)),
                Vertex(position: float4(-1, -1, 0.5, 1), texCoord: float2(0, 0)),
                Vertex(position: float4(-1,  1, 0.5, 1), texCoord: float2(0, 1))
            ]
            
            super.init()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        }
        
        func draw(in view: MTKView) {
            let cb = commandQueue.makeCommandBuffer()!
            guard let renderPass = view.currentRenderPassDescriptor else { return }
            renderPass.colorAttachments[0].loadAction = .dontCare
            let encoder = cb.makeRenderCommandEncoder(descriptor: renderPass)!
            for _ in 0..<10 {
                encodeBlend(of: isidor, and: cats, using: encoder)
            }
            encoder.endEncoding()
            
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
            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBytes(
                vertices,
                length: MemoryLayout<Vertex>.stride * vertices.count,
                index: 0
            )
            encoder.setFragmentTexture(tex1, index: 0)
            encoder.setFragmentTexture(tex2, index: 1)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 5)
        }
        
    }
}

#Preview {
    MetalView()
}
