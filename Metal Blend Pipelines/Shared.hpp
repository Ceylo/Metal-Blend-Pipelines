//
//  Shared.h
//  Metal Blend Pipelines
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
#include <sys/types.h>
#endif

struct Vertex {
    float4 position MTL([[position]]);
    float2 texCoord;
};

struct TiledComputeBlendParams {
    const ushort src1TileIndex;
    const ushort src2TileIndex;
    const ushort dstTileIndex;
    const ushort tileWidth;
    const ushort tileHeight;
    
#ifdef __METAL_VERSION__
    const ushort2 Src1StartPosition() const constant {
        return ushort2(src1TileIndex % 2 * tileWidth, src1TileIndex / 2 * tileHeight);
    }
    
    const ushort2 Src2StartPosition() const constant {
        return ushort2(src2TileIndex % 2 * tileWidth, src2TileIndex / 2 * tileHeight);
    }
    
    const ushort2 DstStartPosition() const constant {
        return ushort2(dstTileIndex % 2 * tileWidth, dstTileIndex / 2 * tileHeight);
    }
#endif
};
