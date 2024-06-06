//
//  ContentView.swift
//  Metal Blend Pipelines
//
//  Created by Ceylo on 04/06/2024.
//

import SwiftUI
import os

let signposter = OSSignposter(subsystem: "Metal Blend Pipelines", category: "Renderer")

struct ContentView: View {
#if os(macOS)
    let pickerPadding = 10.0
#elseif os(iOS)
    let pickerPadding = 0.0
#endif
    
    enum Renderer: String, Hashable, Identifiable, CaseIterable {
        case renderPipeline = "Render (1 encoder/layer)"
        case renderPipelineFusedEncoder = "Render (1 encoder, 1 draw/layer)"
        case renderPipelineWithTiles = "Render (1 encoder, 1 draw/layer, tile memory)"
        case computePipeline = "Compute (1 dispatch/layer)"
        case computeTiledPipeline = "Compute (1 dispatch/layer, 4 tiles)"
        case computedMonolithicPipeline = "Compute (1 dispatch, monolithic kernel)"
        case coreImagePipeline = "Core Image"
        case metalPetalPipeline = "Metal Petal"
        
        var id: Self { self }
    }
    
    @State private var token: OSSignpostIntervalState = signposter.beginInterval("Renderer", "\(Renderer.renderPipeline.rawValue)")
    @State private var displayedRenderer: Renderer = .renderPipeline
    @State private var sequentialCommandBuffers: Bool = false
    @State private var maxDrawableCount = 2
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Pipeline:", selection: $displayedRenderer) {
                    ForEach(Renderer.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                
                Divider()
                Toggle(isOn: $sequentialCommandBuffers) {
                    Text("Sequential command buffers")
                }
                .disabled(!displayedRenderer.supportsSequentialCommandBuffers)
                
                Divider()
                Picker("Max drawable count:", selection: $maxDrawableCount) {
                    Text("2").tag(2)
                    Text("3").tag(3)
                }
            }
            .padding(pickerPadding)
            .fixedSize()
            
            switch displayedRenderer {
            case .renderPipeline:
                MetalView<RenderPipelineRenderer>(
                    sequentialCommandBuffers: sequentialCommandBuffers,
                    maximumDrawableCount: maxDrawableCount
                )
            case .renderPipelineFusedEncoder:
                MetalView<RenderPipelineFusedEncoderRenderer>(
                    sequentialCommandBuffers: sequentialCommandBuffers,
                    maximumDrawableCount: maxDrawableCount
                )
            case .renderPipelineWithTiles:
                MetalView<RenderPipelineWithTileMemoryRenderer>(
                    sequentialCommandBuffers: sequentialCommandBuffers,
                    maximumDrawableCount: maxDrawableCount
                )
            case .computePipeline:
                MetalView<ComputePipelineRenderer>(
                    sequentialCommandBuffers: sequentialCommandBuffers,
                    maximumDrawableCount: maxDrawableCount
                )
            case .computeTiledPipeline:
                MetalView<ComputeTiledPipelineRenderer>(
                    sequentialCommandBuffers: sequentialCommandBuffers,
                    maximumDrawableCount: maxDrawableCount
                )
            case .computedMonolithicPipeline:
                MetalView<ComputeMonolithicPipelineRenderer>(
                    sequentialCommandBuffers: sequentialCommandBuffers,
                    maximumDrawableCount: maxDrawableCount
                )
            case .coreImagePipeline:
                MetalView<CoreImagePipelineRenderer>(
                    sequentialCommandBuffers: true,
                    maximumDrawableCount: maxDrawableCount
                )
            case .metalPetalPipeline:
                MetalView<MetalPetalPipelineRenderer>(
                    sequentialCommandBuffers: sequentialCommandBuffers,
                    maximumDrawableCount: maxDrawableCount
                )
            }
        }
        .onChange(of: displayedRenderer) { oldValue, newValue in
            signposter.endInterval("Renderer", token, "\(oldValue.rawValue)")
            token = signposter.beginInterval("Renderer", "\(newValue.rawValue)")
            
            switch newValue {
            case .coreImagePipeline:
                sequentialCommandBuffers = true
            case .metalPetalPipeline:
                sequentialCommandBuffers = false
            default:
                break
            }
        }
    }
}

extension ContentView.Renderer {
    var supportsSequentialCommandBuffers: Bool {
        switch self {
        case .coreImagePipeline, .metalPetalPipeline:
            false
        default:
            true
        }
    }
}

#Preview {
    ContentView()
}
