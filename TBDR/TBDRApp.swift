//
//  TBDRApp.swift
//  TBDR
//
//  Created by Ceylo on 15/05/2024.
//

import SwiftUI

@main
struct TBDRApp: App {
    #if os(macOS)
    let pickerPadding = 10.0
    #elseif os(iOS)
    let pickerPadding = 0.0
    #endif
    
    enum Renderer: String, Hashable, Identifiable, CaseIterable {
        case renderPipeline = "Render Pipeline"
        case computePipeline = "Compute Pipeline"
        
        var id: Self { self }
    }
    
    @State private var displayedRenderer: Renderer = .renderPipeline
    
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 0) {
                Picker("", selection: $displayedRenderer) {
                    ForEach(Renderer.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .padding(pickerPadding)
                
                switch displayedRenderer {
                case .renderPipeline:
                    MetalView<RenderPipelineRenderer>()
                case .computePipeline:
                    MetalView<ComputePipelineRenderer>()
                }
            }
        }
    }
}
