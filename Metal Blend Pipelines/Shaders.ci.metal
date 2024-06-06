//
//  Shaders.ci.metal
//  Metal Blend Pipelines
//
//  Created by Ceylo on 26/05/2024.
//

#include <CoreImage/CoreImage.h>
using namespace coreimage;

extern "C" {
    float4 coreImageBlend(sample_t foreground, sample_t background) {
        const float3 fg = unpremultiply(foreground).rgb;
        const float3 bg = unpremultiply(background).rgb;
        return premultiply(float4((fg + bg) / 1.1, 1.0));
    }
}
