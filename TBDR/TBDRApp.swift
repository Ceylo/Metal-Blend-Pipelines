//
//  TBDRApp.swift
//  TBDR
//
//  Created by Ceylo on 15/05/2024.
//

import SwiftUI
import os

let signposter = OSSignposter(subsystem: "TBDR", category: "Renderer")

@main
struct TBDRApp: App {
    #if os(macOS)
    let pickerPadding = 10.0
    #elseif os(iOS)
    let pickerPadding = 0.0
    #endif
    
    enum Renderer: String, Hashable, Identifiable, CaseIterable {
        case renderPipeline = "Render Pipeline"
        case renderPipelineFusedEncoder = "Render Pipeline + Single Encoder"
        case renderPipelineWithTiles = "Render Pipeline + Tile Memory"
        case computePipeline = "Compute Pipeline"
        case computeTiledPipeline = "Tiled Compute Pipeline"
        case computedAggregatedPipeline = "Aggregated Compute Pipeline"
        case coreImagePipeline = "Core Image Pipeline"
        
        var id: Self { self }
    }
    
    @State private var token: OSSignpostIntervalState = signposter.beginInterval("Renderer", "\(Renderer.renderPipeline.rawValue)")
    @State private var displayedRenderer: Renderer = .renderPipeline
    @State private var serialGPUWork: Bool = true
    
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 0) {
                HStack {
                    Toggle(isOn: $serialGPUWork) {
                        Text("Serial GPU work")
                    }
                    .disabled(displayedRenderer == .coreImagePipeline)
                    .padding(.leading)
                    
                    Picker("", selection: $displayedRenderer) {
                        ForEach(Renderer.allCases) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(pickerPadding)
                }
                
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
}
