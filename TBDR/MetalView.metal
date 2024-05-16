//
//  MetalView.metal
//  TBDR
//
//  Created by Ceylo on 15/05/2024.
//

#include <metal_stdlib>
#include "Shared.hpp"

using namespace metal;

vertex Vertex vertexFunc(unsigned int vertexId [[vertex_id]],
                         constant Vertex* vertices [[buffer(0)]]) {
    return vertices[vertexId];
}

fragment half4 fragmentFunc(const Vertex vert [[stage_in]],
                            texture2d<half, access::read> tex [[texture(0)]])
{
    const uint2 coord = {
        static_cast<unsigned int>(vert.texCoord.x * tex.get_width()),
        static_cast<unsigned int>(vert.texCoord.y * tex.get_height())
    };
    return tex.read(coord);
}
