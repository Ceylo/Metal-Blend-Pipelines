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
                         device const Vertex* vertices [[buffer(0)]]) {
    return vertices[vertexId];
}

fragment half4 fragmentFunc(const Vertex vert [[stage_in]],
                            texture2d<half, access::sample> tex1 [[texture(0)]],
                            texture2d<half, access::sample> tex2 [[texture(1)]])
{
    constexpr sampler s(address::clamp_to_border, filter::linear);
    const auto p1 = tex1.sample(s, vert.texCoord);
    const auto p2 = tex2.sample(s, vert.texCoord);
    return (p1 + p2) / 2;
}

kernel void kernelFunc(texture2d<half, access::sample> tex1 [[texture(0)]],
                       texture2d<half, access::sample> tex2 [[texture(1)]],
                       texture2d<half, access::write> output [[texture(2)]],
                       ushort2 gid [[thread_position_in_grid]])
{
    const float2 coord = (float2(gid) + 0.5) / float2(output.get_width(), output.get_height());
    
    constexpr sampler s(address::clamp_to_border, filter::linear);
    const auto p1 = tex1.sample(s, coord);
    const auto p2 = tex2.sample(s, coord);
    const auto out = (p1 + p2) / 2;
    output.write(out, gid);
}
