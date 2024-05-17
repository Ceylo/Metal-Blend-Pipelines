//
//  MetalView.swift
//  TBDR
//
//  Created by Ceylo on 15/05/2024.
//

import SwiftUI
import MetalKit

#if os(macOS)
typealias ViewRepresentable = NSViewRepresentable
typealias ViewRepresentableContext = NSViewRepresentableContext
#elseif os(iOS)
typealias ViewRepresentable = UIViewRepresentable
typealias ViewRepresentableContext = UIViewRepresentableContext
#endif

struct MetalView: ViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
#if os(iOS)
    func makeUIView(context: ViewRepresentableContext<MetalView>) -> MTKView {
        makeView(context: context)
    }
#elseif os(macOS)
    func makeNSView(context: ViewRepresentableContext<MetalView>) -> MTKView {
        makeView(context: context)
    }
#endif
    
    private func makeView(context: ViewRepresentableContext<MetalView>) -> MTKView
    {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.device = MTLCreateSystemDefaultDevice()!
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.colorPixelFormat = context.coordinator.pixelFormat
#if os(macOS)
        mtkView.colorspace = context.coordinator.colorSpace
#endif
        return mtkView
    }
    
#if os(iOS)
    func updateUIView(_ uiView: MTKView, context: Context) {}
#elseif os(macOS)
    func updateNSView(_ nsView: MTKView, context: ViewRepresentableContext<MetalView>) {}
#endif
    
    class Coordinator : NSObject, MTKViewDelegate {
        let parent: MetalView
        let device: MTLDevice
        let cat: MTLTexture
        // Multiple textures to simulate layers with distinct data
        let isidors: [MTLTexture]
        var intermediateImage: MTLTexture
        let commandQueue: MTLCommandQueue
        // Make several pipelines states to simulate different blend functions
        let pipelineStates: [MTLRenderPipelineState]
        let pixelFormat: MTLPixelFormat = .bgra8Unorm_srgb
        let colorSpace: CGColorSpace = .init(name: CGColorSpace.sRGB)!
        let vertices: MTLBuffer
        
        init(_ parent: MetalView) {
            self.parent = parent
            let device = MTLCreateSystemDefaultDevice()!
            self.device = device
            self.commandQueue = device.makeCommandQueue()!
            
            let loader = MTKTextureLoader(device: device)
            let textureOptions: [MTKTextureLoader.Option : Any] = [
                .origin: MTKTextureLoader.Origin.topLeft,
                .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue),
                // read-write as layers are typicallyed mutated
                .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.union(.shaderWrite).rawValue)
            ]
            
            cat = try! loader
                .newTexture(name: "cats", scaleFactor: 1, bundle: nil, options: textureOptions)
            cat.label = "Cat"
            isidors = (0..<200).map { i in
                let cat = try! loader
                    .newTexture(name: "Isidor", scaleFactor: 1, bundle: nil, options: textureOptions)
                cat.label = "Isidor #\(i)"
                return cat
            }
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
            
            let library = device.makeDefaultLibrary()!
            
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = library.makeFunction(name: "vertexFunc")!
            desc.fragmentFunction = library.makeFunction(name: "fragmentFunc")!
            desc.colorAttachments[0].pixelFormat = pixelFormat
            
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
            
            super.init()
            
//            #if DEBUG
//            Task { @MainActor in
//                try await Task.sleep(for: .seconds(3))
//                
//                let desc = MTLCaptureDescriptor()
//                desc.captureObject = device
//                try MTLCaptureManager.shared().startCapture(with: desc)
//                try await Task.sleep(for: .seconds(2))
//                MTLCaptureManager.shared().stopCapture()
//            }
//            #endif
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        }
        
        var drawCalls = 0
        func draw(in view: MTKView) {
            let cb = commandQueue.makeCommandBuffer()!
            guard let renderPass = view.currentRenderPassDescriptor else { return }
            renderPass.colorAttachments[0].loadAction = .dontCare
            
            drawCalls = 0
            defer {
                print("Encoded \(drawCalls) draw calls")
            }
            var input1 = cat
            
            let desc = MTLRenderPassDescriptor()
            desc.colorAttachments[0].texture = intermediateImage
            desc.colorAttachments[0].loadAction = .dontCare
            
            let encoder1 = cb.makeRenderCommandEncoder(descriptor: desc)!
            encoder1.label = "Merge render"
            for isidor in isidors {
                encodeBlend(of: input1, and: isidor, using: encoder1)
                input1 = intermediateImage
            }
            encoder1.endEncoding()
            
            let encoder2 = cb.makeRenderCommandEncoder(descriptor: renderPass)!
            encoder2.label = "Final render"
            encodeBlend(of: input1, and: isidors.last!, using: encoder2)
            encoder2.endEncoding()
            
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
}

#Preview {
    MetalView()
}
