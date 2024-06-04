//
//  Shaders.metal
//  TBDR
//
//  Created by Ceylo on 15/05/2024.
//

#include <metal_stdlib>
#include "Shared.hpp"

using namespace metal;

constant constexpr half attenuation = 1.1;

vertex Vertex vertexFunc(unsigned int vertexId [[vertex_id]],
                         device const Vertex* vertices [[buffer(0)]],
                         constant float2& drawableSize [[buffer(1)]],
                         constant float& yOffset [[buffer(2)]]) {
    Vertex mapped = vertices[vertexId];
    // Framebuffer origin is bottom left but here we want to draw with top left origin
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
    return (p1 + p2) / attenuation;
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
    const auto out = (p1 + p2) / attenuation;
    output.write(out, gid);
}

kernel void kernelFuncTiled(texture2d<half, access::sample> tex1 [[texture(0)]],
                            texture2d<half, access::sample> tex2 [[texture(1)]],
                            texture2d<half, access::write> output [[texture(2)]],
                            constant const TiledComputeBlendParams& params [[buffer(0)]],
                            ushort2 gid [[thread_position_in_grid]])
{
    constexpr sampler s(coord::pixel, address::clamp_to_zero, filter::linear);
    const auto texCoord = float2(gid) + 0.5;
    const auto p1 = tex1.sample(s, texCoord + float2(params.Src1StartPosition()));
    const auto p2 = tex2.sample(s, texCoord + float2(params.Src2StartPosition()));
    const auto out = (p1 + p2) / attenuation;
    output.write(out, gid + params.DstStartPosition());
}


kernel void aggregatedKernelFunc(texture2d<half, access::write> output [[texture(0)]],
                                 array<texture2d<half, access::sample>, 50> inputs [[texture(1)]],
                                 ushort2 gid [[thread_position_in_grid]])
{
    constexpr sampler s(coord::pixel, address::clamp_to_zero, filter::linear);
    const auto texCoord = float2(gid) + 0.5;
    half4 out = 0;
    for (ushort i = 0; i < inputs.size(); ++i)
    {
        const half4 newSample = inputs[i].sample(s, texCoord);
        out = (out + newSample) / attenuation;
    }
    output.write(out, gid);
}

struct FragmentIO {
    const half4 framebuffer  [[ color(0) ]];
    const half4 tile1        [[ color(1) ]];
    const half4 tile2        [[ color(2) ]];
    
    FragmentIO(const half4 framebuffer,
               const half4 tile1,
               const half4 tile2)
    : framebuffer(framebuffer)
    , tile1(tile1)
    , tile2(tile2)
    {}
    
    half4 ReadTile(int passIndex) const {
        return passIndex % 2 == 0 ? tile1 : tile2;
    }
    
    FragmentIO UpdatingTile(int passIndex, half4 newValue) const {
        if (passIndex % 2 == 0) {
            return FragmentIO{
                newValue,
                tile1,
                newValue
            };
        } else {
            return FragmentIO{
                newValue,
                newValue,
                tile2
            };
        }
    }
};

fragment FragmentIO tiledFragmentInit(const Vertex vert [[stage_in]],
                                      texture2d<half, access::sample> tex1 [[texture(0)]],
                                      texture2d<half, access::sample> tex2 [[texture(1)]])
{
    constexpr sampler s(address::clamp_to_zero, filter::linear);
    const auto p1 = tex1.sample(s, vert.texCoord);
    const auto p2 = tex2.sample(s, vert.texCoord);
    const auto res = (p1 + p2) / attenuation;
    
    return FragmentIO{
        res,
        res,
        res
    };
}

fragment FragmentIO tiledFragmentFunc(const Vertex vert [[stage_in]],
                                      texture2d<half, access::sample> tex1 [[texture(0)]],
                                      constant ushort& passIndex [[buffer(0)]],
                                      const FragmentIO io)
{
    constexpr sampler s(address::clamp_to_zero, filter::linear);
    const auto p1 = tex1.sample(s, vert.texCoord);
    const auto p2 = io.ReadTile(passIndex);
    const auto res = (p1 + p2) / attenuation;
    
    return io.UpdatingTile(passIndex, res);
}
