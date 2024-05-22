//
//  Shaders.metal
//  TBDR
//
//  Created by Ceylo on 15/05/2024.
//

#include <metal_stdlib>
#include "Shared.hpp"

using namespace metal;

vertex Vertex vertexFunc(unsigned int vertexId [[vertex_id]],
                         device const Vertex* vertices [[buffer(0)]],
                         constant float2& drawableSize [[buffer(1)]],
                         constant float& yOffset [[buffer(2)]]) {
    Vertex mapped = vertices[vertexId];
    // Metal origin is bottom left but here we want to draw with top left origin
    mapped.position.xy = (mapped.position.xy + float2(0, yOffset)) / (0.5 * drawableSize) - 1;
    return mapped;
}

fragment half4 fragmentFunc(const Vertex vert [[stage_in]],
                            texture2d<half, access::sample> tex1 [[texture(0)]],
                            texture2d<half, access::sample> tex2 [[texture(1)]])
{
    constexpr sampler s(address::clamp_to_zero, filter::linear);
    const auto p1 = tex1.sample(s, vert.texCoord);
    const auto p2 = tex2.sample(s, vert.texCoord);
    return (p1 + p2) / 2;
}

kernel void kernelFunc(texture2d<half, access::sample> tex1 [[texture(0)]],
                       texture2d<half, access::sample> tex2 [[texture(1)]],
                       texture2d<half, access::write> output [[texture(2)]],
                       ushort2 gid [[thread_position_in_grid]])
{
    constexpr sampler s(coord::pixel, address::clamp_to_zero, filter::linear);
    const auto texCoord = float2(gid) + 0.5;
    const auto p1 = tex1.sample(s, texCoord);
    const auto p2 = tex2.sample(s, texCoord);
    const auto out = (p1 + p2) / 2;
    output.write(out, gid);
}
