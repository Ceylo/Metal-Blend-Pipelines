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
    var executionMode: MTLCommandScheduler.Mode { get set }
}

#if os(macOS)
typealias ViewRepresentable = NSViewRepresentable
#elseif os(iOS)
typealias ViewRepresentable = UIViewRepresentable
#endif


struct MetalView<Renderer: MTLRenderer>: ViewRepresentable {
    let sequentialCommandBuffers: Bool
    let maximumDrawableCount: Int
    
    private var preferredFramesPerSecond: Int {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return 1
        } else {
            return 240
        }
    }
    
    func makeCoordinator() -> Renderer {
        Renderer()
    }
    
#if os(iOS)
    func makeUIView(context: Context) -> MTKView {
        makeView(context: context)
    }
#elseif os(macOS)
    func makeNSView(context: Context) -> MTKView {
        makeView(context: context)
    }
#endif
    
    private func makeView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.device = MTLCreateSystemDefaultDevice()!
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.colorPixelFormat = context.coordinator.drawablePixelFormat
        mtkView.framebufferOnly = !context.coordinator.drawableIsWritable
        mtkView.preferredFramesPerSecond = preferredFramesPerSecond
        let layer = mtkView.layer as! CAMetalLayer
#if os(macOS)
        layer.displaySyncEnabled = false
        mtkView.colorspace = context.coordinator.drawableColorSpace
#endif
        return mtkView
    }
    
#if os(iOS)
    func updateUIView(_ uiView: MTKView, context: Context) { updateView(uiView, context: context) }
#elseif os(macOS)
    func updateNSView(_ nsView: MTKView, context: Context) { updateView(nsView, context: context) }
#endif
    
    private func updateView(_ view: MTKView, context: Context) {
        context.coordinator.executionMode = sequentialCommandBuffers ? .serial : .unconstrained
        let layer = view.layer as! CAMetalLayer
        layer.maximumDrawableCount = maximumDrawableCount
    }
}
