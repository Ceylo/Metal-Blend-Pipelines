//
//  MetalView.swift
//  TBDR
//
//  Created by Ceylo on 20/05/2024.
//

import SwiftUI
import MetalKit

protocol MTLRenderer: MTKViewDelegate {
    init()
    var drawablePixelFormat: MTLPixelFormat { get }
    var drawableIsWritable: Bool { get }
    var drawableColorSpace: CGColorSpace { get }
}

#if os(macOS)
typealias ViewRepresentable = NSViewRepresentable
typealias ViewRepresentableContext = NSViewRepresentableContext
#elseif os(iOS)
typealias ViewRepresentable = UIViewRepresentable
typealias ViewRepresentableContext = UIViewRepresentableContext
#endif


struct MetalView<Renderer: MTLRenderer>: ViewRepresentable {
    func makeCoordinator() -> Renderer {
        Renderer()
    }
    
#if os(iOS)
    func makeUIView(context: ViewRepresentableContext<Self>) -> MTKView {
        makeView(context: context)
    }
#elseif os(macOS)
    func makeNSView(context: ViewRepresentableContext<Self>) -> MTKView {
        makeView(context: context)
    }
#endif
    
    private func makeView(context: ViewRepresentableContext<Self>) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.device = MTLCreateSystemDefaultDevice()!
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.colorPixelFormat = context.coordinator.drawablePixelFormat
        mtkView.framebufferOnly = !context.coordinator.drawableIsWritable
        mtkView.preferredFramesPerSecond = 240
        let layer = mtkView.layer as! CAMetalLayer
        layer.maximumDrawableCount = 2
#if os(macOS)
        layer.displaySyncEnabled = false
        mtkView.colorspace = context.coordinator.drawableColorSpace
#endif
        return mtkView
    }
    
#if os(iOS)
    func updateUIView(_ uiView: MTKView, context: Context) {}
#elseif os(macOS)
    func updateNSView(_ nsView: MTKView, context: ViewRepresentableContext<Self>) {}
#endif
}
