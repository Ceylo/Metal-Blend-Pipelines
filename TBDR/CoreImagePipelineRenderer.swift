//
//  CoreImagePipelineRenderer.swift
//  TBDR
//
//  Created by Ceylo on 15/05/2024.
//

import SwiftUI
import MetalKit
import OpenGL.GL.Macro // Required to make Swift/C++ interop happy o_o
import CoreImage
import CoreImage.CIFilterBuiltins

class CoreImagePipelineRenderer : NSObject, MTLRenderer {
    let drawablePixelFormat: MTLPixelFormat = .bgra8Unorm_srgb
    let drawableIsWritable: Bool = true
    let drawableColorSpace: CGColorSpace = .init(name: CGColorSpace.sRGB)!
    
    let helper: MetalHelper
    let commandQueue: MTLCommandQueue
    // Make several pipelines states to simulate different blend functions
    let context: CIContext
    
    override required init() {
        let helper = MetalHelper.shared
        let device = helper.device
        self.helper = helper
        self.commandQueue = device.makeCommandQueue()!
        
        context = CIContext(
            mtlDevice: device,
            options: [
                .cacheIntermediates: NSNumber(value: false),
                .outputColorSpace: drawableColorSpace,
                .workingColorSpace: drawableColorSpace,
                .outputPremultiplied: NSNumber(value: false)
            ]
        )
        
        super.init()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        let cb = commandQueue.makeCommandBuffer()!

        guard let drawable = view.currentDrawable else {
            return
        }
        
        let destination = CIRenderDestination(mtlTexture: drawable.texture, commandBuffer: cb)
        destination.colorSpace = drawableColorSpace
        destination.isFlipped = true
        let graph = buildRenderingGraph()
        try! context.startTask(toRender: graph, to: destination)
        
        cb.present(drawable)
        cb.commit()
    }
    
    func buildRenderingGraph() -> CIImage {
        var output = CIImage(mtlTexture: helper.layers[0])!
        
        for layer in helper.layers.dropFirst().dropLast() {
            output = encodeBlend(of: output, and: CIImage(mtlTexture: layer)!)
        }
        
        output = encodeBlend(of: output, and: CIImage(mtlTexture: helper.layers.last!)!)
        return output
    }
    
    func encodeBlend(of tex1: CIImage, and tex2: CIImage) -> CIImage {
        let add = CIFilter.additionCompositing()
        add.backgroundImage = tex1
        add.inputImage = tex2
        return add.outputImage!
    }
}

#Preview {
    MetalView<CoreImagePipelineRenderer>()
}
