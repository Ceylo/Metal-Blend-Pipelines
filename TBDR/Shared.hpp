//
//  Shared.h
//  TBDR
//
//  Created by Ceylo on 15/05/2024.
//

#pragma once
#include <simd/simd.h>

using float2 = simd_float2;
using float4 = simd_float4;

#ifdef __METAL_VERSION__
#define MTL(expression) expression
#else
#define MTL(expression)
#endif

struct Vertex {
    float4 position MTL([[position]]);
    float2 texCoord;
};
