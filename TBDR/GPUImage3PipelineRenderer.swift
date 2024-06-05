//
//  GPUImage3PipelineRenderer.swift
//  TBDR
//
//  Created by Ceylo on 15/05/2024.
//


// https://github.com/BradLarson/GPUImage3
// Actually skipped because:
// - seems like it's not designed to render to a texture and wants to use its RenderView (MTKView subclass) instead. I tried to copy the RenderView code to adapt it but
// it's then pulling other internal dependencies.
// - custom kernel isn't supported without modifying GPUImage sources: https://github.com/BradLarson/GPUImage3/issues/76
