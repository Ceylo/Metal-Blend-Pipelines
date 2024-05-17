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
                            texture2d<half, access::read> tex1 [[texture(0)]],
                            texture2d<half, access::read> tex2 [[texture(1)]])
{
    const uint2 coord1 = {
        static_cast<unsigned int>(vert.texCoord.x * tex1.get_width()),
        static_cast<unsigned int>(vert.texCoord.y * tex1.get_height())
    };
    const uint2 coord2 = {
        static_cast<unsigned int>(vert.texCoord.x * tex2.get_width()),
        static_cast<unsigned int>(vert.texCoord.y * tex2.get_height())
    };
    
    const auto p1 = tex1.read(coord1);
    const auto p2 = tex2.read(coord2);
    return (p1 + p2) / 2;
}
