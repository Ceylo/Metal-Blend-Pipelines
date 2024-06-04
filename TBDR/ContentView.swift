//
//  ContentView.swift
//  TBDR
//
//  Created by Ceylo on 04/06/2024.
//

import SwiftUI
import os

let signposter = OSSignposter(subsystem: "TBDR", category: "Renderer")

struct ContentView: View {
#if os(macOS)
    let pickerPadding = 10.0
#elseif os(iOS)
    let pickerPadding = 0.0
#endif
    
    enum Renderer: String, Hashable, Identifiable, CaseIterable {
        case renderPipeline = "Render (1 encoder/layer)"
        case renderPipelineFusedEncoder = "Render (1 encoder, 1 draw/layer)"
        case renderPipelineWithTiles = "Render (1 encoder,  1 draw/layer, tile memory)"
        case computePipeline = "Compute (1 dispatch/layer)"
        case computeTiledPipeline = "Compute (1 dispatch/layer, 4 tiles)"
        case computedAggregatedPipeline = "Compute (1 dispatch, monolithic kernel)"
        case coreImagePipeline = "Core Image"
        
        var id: Self { self }
    }
    
    @State private var token: OSSignpostIntervalState = signposter.beginInterval("Renderer", "\(Renderer.renderPipeline.rawValue)")
    @State private var displayedRenderer: Renderer = .renderPipeline
    @State private var serialGPUWork: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle(isOn: $serialGPUWork) {
                    Text("Serial GPU work")
                }
                .disabled(displayedRenderer == .coreImagePipeline)
                
                Divider()
                Picker("Pipeline:", selection: $displayedRenderer) {
                    ForEach(Renderer.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
            }
            .padding(pickerPadding)
            .fixedSize()
            
            switch displayedRenderer {
            case .renderPipeline:
                MetalView<RenderPipelineRenderer>(serialGPUWork: serialGPUWork)
            case .renderPipelineFusedEncoder:
                MetalView<RenderPipelineFusedEncoderRenderer>(serialGPUWork: serialGPUWork)
            case .renderPipelineWithTiles:
                MetalView<RenderPipelineWithTileMemoryRenderer>(serialGPUWork: serialGPUWork)
            case .computePipeline:
                MetalView<ComputePipelineRenderer>(serialGPUWork: serialGPUWork)
            case .computeTiledPipeline:
                MetalView<ComputeTiledPipelineRenderer>(serialGPUWork: serialGPUWork)
            case .computedAggregatedPipeline:
                MetalView<ComputeAggregatedPipelineRenderer>(serialGPUWork: serialGPUWork)
            case .coreImagePipeline:
                MetalView<CoreImagePipelineRenderer>(serialGPUWork: true)
            }
        }
        .onChange(of: displayedRenderer) { oldValue, newValue in
            signposter.endInterval("Renderer", token, "\(oldValue.rawValue)")
            token = signposter.beginInterval("Renderer", "\(newValue.rawValue)")
            
            if newValue == .coreImagePipeline {
                serialGPUWork = true
            }
        }
    }
}

#Preview {
    ContentView()
}
