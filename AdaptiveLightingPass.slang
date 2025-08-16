import Shading;

#define VIS_INTERP_AREA 0

enum WarpMode
{
    Shade = 0,
    Interpolate = 1
};

uniform uint2 gScreenSize;
uniform uint2 gScreenGridDim;
RWTexture2D<float4> gOutputTexture;

[shader("compute")]
[numthreads(8, 8, 1)]
void pass0(uint2 tid: SV_DispatchThreadID)
{
    uint2 blockBase = tid * 4;
    uint2 texelPosition = blockBase + uint2(0, 0);
    if (any(texelPosition >= gScreenSize))
    {
        return;
    }

    gOutputTexture[texelPosition] = shade(texelPosition);
}

bool shouldShade(float3 A, float3 B, float3 C, float3 D)
{
    float Y0 = dot(A, float3(0.25, 0.5, 0.25));
    float Y1 = dot(B, float3(0.25, 0.5, 0.25));
    float Y2 = dot(C, float3(0.25, 0.5, 0.25));
    float Y3 = dot(D, float3(0.25, 0.5, 0.25));

    float sumY = Y0 + Y1 + Y2 + Y3;
    float sumY2 = Y0 * Y0 + Y1 * Y1 + Y2 * Y2 + Y3 * Y3;
    float Ymean = 0.25 * sumY;
    float Yvar = 0.25 * sumY2 - Ymean * Ymean;
    
    const float varianceThreshold = 1e-3f;
    return (Yvar >= varianceThreshold);
}

void WavePartition2(bool isTrue, out uint newLaneIndex, out uint trueCount)
{
    // 统计本 wave 内 true 的总数
    trueCount = WaveActiveCountBits(isTrue);

    // 计算当前线程之前（不含自己）的 true 数
    uint trueBefore = WavePrefixCountBits(isTrue);

    // 当前 lane 在 wave 中的索引
    uint lane = WaveGetLaneIndex();

    // 之前的 false 数 = lane - trueBefore
    uint falseBefore = lane - trueBefore;

    // 重新编号：把 true 放前面，false 放后面
    newLaneIndex = isTrue ? trueBefore : (trueCount + falseBefore);
}

/*
struct Payload {};
groupshared uint gShadeCount[2];
groupshared uint gShadePrefix[2]; // [0] = 0, [1] = gShadeCount[0]
groupshared Payload gBuf[64];

[numthreads(64, 1, 1)]
void CS(uint3 gtid: SV_GroupThreadID)
{
    const uint waveId = gtid.x >> 5; // 0 or 1
    const uint lane = gtid.x & 31;   // 0..31

    bool isShade = ...;
    Payload payload = ...;

    // wave 内重排索引 + 计数
    uint idxInWave, shadeCountWave;
    WavePartition2(isShade, idxInWave, shadeCountWave);

    // 记录每个 wave 的 shade 数
    if (lane == 0) gShadeCount[waveId] = shadeCountWave;
    GroupMemoryBarrierWithGroupSync();

    // 计算 64 线程组内的 shade 前缀与总数
    if (gtid.x == 0) {
        gShadePrefix[0] = 0;
        gShadePrefix[1] = gShadeCount[0];
    }
    GroupMemoryBarrierWithGroupSync();

    const uint shadePrefixWave = gShadePrefix[waveId];
    const uint totalShade = gShadeCount[0] + gShadeCount[1];

    // 组内的新“紧凑索引”：将两个 wave 的 true 段首尾相接
    uint compactIdx = isShade
                          ? (shadePrefixWave + idxInWave)
                          : (totalShade + (waveId * 32 + lane) // 全局 lane
                             - (shadePrefixWave + idxInWave)); // 之前 false 数的等价表达

    // 可选：把数据写入共享缓冲便于按区间执行
    gBuf[compactIdx] = payload;
    GroupMemoryBarrierWithGroupSync();

    // 第一段：处理所有 shade（0..totalShade-1）
    if (compactIdx < totalShade) {
        Payload pl = gBuf[compactIdx];
        // 执行 shade
        // ...
    }
    GroupMemoryBarrierWithGroupSync();

    // 第二段：处理所有 interp（totalShade..63）
    if (compactIdx >= totalShade) {
        Payload pl = gBuf[compactIdx];
        // 执行 interpolate
        // ...
    }
}
*/

struct Payload
{
    float3 interpolatedResult;
    uint linearPixelIndex;
};

groupshared uint gShadeCount[2];
groupshared uint gShadePrefix[2]; // [0] = 0, [1] = gShadeCount[0]
groupshared Payload gBuf[64];

#if 0
void processPixel(uint gtid, uint2 texelPosition, uint2 offsetA, uint2 offsetB, uint2 offsetC, uint2 offsetD)
{
    if (any(texelPosition >= gScreenSize))
    {
        return;
    }

    const uint waveId = gtid.x >> 5; // 0 or 1
    const uint lane = gtid.x & 31;   // 0..31

    float4 neighbor0 = gOutputTexture[texelPosition + offsetA];
    float4 neighbor1 = gOutputTexture[texelPosition + offsetB];
    float4 neighbor2 = gOutputTexture[texelPosition + offsetC];
    float4 neighbor3 = gOutputTexture[texelPosition + offsetD];
    float4 interpolatedResult = 0.25 * (neighbor0 + neighbor1 + neighbor2 + neighbor3);

    bool isShade = shouldShade(neighbor0.rgb, neighbor1.rgb, neighbor2.rgb, neighbor3.rgb) ? WarpMode::Shade : WarpMode::Interpolate;
    uint idxInWave, shadeCountWave;
    WavePartition2(isShade, idxInWave, shadeCountWave);

    // 记录每个 wave 的 shade 数
    if (lane == 0) gShadeCount[waveId] = shadeCountWave;
    GroupMemoryBarrierWithGroupSync();
}
#else
void processPixel(uint gtid, uint2 texelPosition, uint2 offsetA, uint2 offsetB, uint2 offsetC, uint2 offsetD)
{
    if (any(texelPosition >= gScreenSize))
    {
        return;
    }

    float4 neighbor0 = gOutputTexture[texelPosition + offsetA];
    float4 neighbor1 = gOutputTexture[texelPosition + offsetB];
    float4 neighbor2 = gOutputTexture[texelPosition + offsetC];
    float4 neighbor3 = gOutputTexture[texelPosition + offsetD];

    if (shouldShade(neighbor0.rgb, neighbor1.rgb, neighbor2.rgb, neighbor3.rgb))
    {
        gOutputTexture[texelPosition] = shade(texelPosition);
    }
    else
    {
#if VIS_INTERP_AREA
        gOutputTexture[texelPosition] = float4(1, 0, 0, 1);
#else
        gOutputTexture[texelPosition] = 0.25 * (neighbor0 + neighbor1 + neighbor2 + neighbor3);
#endif
    }
}
#endif

[shader("compute")]
[numthreads(64, 1, 1)]
void pass1(uint tid: SV_DispatchThreadID, uint gtid: SV_GroupThreadID)
{
    uint2 tid2d = uint2(tid % gScreenGridDim.x, tid / gScreenGridDim.x);
    uint2 blockBase = tid2d * 4;
    uint2 texelPosition = blockBase + uint2(2, 2);
    processPixel(gtid, texelPosition, uint2(2, 2), uint2(-2, 2), uint2(2, -2), uint2(-2, -2));
}

[shader("compute")]
[numthreads(64, 1, 1)]
void pass2(uint tid: SV_DispatchThreadID, uint gtid: SV_GroupThreadID)
{
    uint2 tid2d = uint2(tid % gScreenGridDim.x, tid / gScreenGridDim.x);
    uint2 blockBase = tid2d * 4;

    {
        uint2 texelPosition = blockBase + uint2(0, 2);
        processPixel(gtid, texelPosition, uint2(0, 2), uint2(2, 0), uint2(0, -2), uint2(-2, 0));
    }

    {
        uint2 texelPosition = blockBase + uint2(2, 0);
        processPixel(gtid, texelPosition, uint2(0, 2), uint2(2, 0), uint2(0, -2), uint2(-2, 0));
    }
}

[shader("compute")]
[numthreads(64, 1, 1)]
void pass3(uint tid: SV_DispatchThreadID, uint gtid: SV_GroupThreadID)
{
    uint2 tid2d = uint2(tid % gScreenGridDim.x, tid / gScreenGridDim.x);
    uint2 blockBase = tid2d * 4;

    {
        uint2 texelPosition = blockBase + uint2(1, 1);
        processPixel(gtid, texelPosition, uint2(1, 1), uint2(-1, -1), uint2(1, -1), uint2(-1, 1));
    }

    {
        uint2 texelPosition = blockBase + uint2(1, 3);
        processPixel(gtid, texelPosition, uint2(1, 1), uint2(-1, -1), uint2(1, -1), uint2(-1, 1));
    }

    {
        uint2 texelPosition = blockBase + uint2(3, 1);
        processPixel(gtid, texelPosition, uint2(1, 1), uint2(-1, -1), uint2(1, -1), uint2(-1, 1));
    }

    {
        uint2 texelPosition = blockBase + uint2(3, 3);
        processPixel(gtid, texelPosition, uint2(1, 1), uint2(-1, -1), uint2(1, -1), uint2(-1, 1));
    }
}

[shader("compute")]
[numthreads(64, 1, 1)]
void pass4(uint tid: SV_DispatchThreadID, uint gtid: SV_GroupThreadID)
{
    uint2 tid2d = uint2(tid % gScreenGridDim.x, tid / gScreenGridDim.x);
    uint2 blockBase = tid2d * 4;

    {
        uint2 texelPosition = blockBase + uint2(0, 1);
        processPixel(gtid, texelPosition, uint2(1, 0), uint2(-1, 0), uint2(0, 1), uint2(0, -1));
    }

    {
        uint2 texelPosition = blockBase + uint2(1, 0);
        processPixel(gtid, texelPosition, uint2(1, 0), uint2(-1, 0), uint2(0, 1), uint2(0, -1));
    }

    {
        uint2 texelPosition = blockBase + uint2(1, 2);
        processPixel(gtid, texelPosition, uint2(1, 0), uint2(-1, 0), uint2(0, 1), uint2(0, -1));
    }

    {
        uint2 texelPosition = blockBase + uint2(2, 1);
        processPixel(gtid, texelPosition, uint2(1, 0), uint2(-1, 0), uint2(0, 1), uint2(0, -1));
    }

    {
        uint2 texelPosition = blockBase + uint2(2, 3);
        processPixel(gtid, texelPosition, uint2(1, 0), uint2(-1, 0), uint2(0, 1), uint2(0, -1));
    }

    {
        uint2 texelPosition = blockBase + uint2(3, 2);
        processPixel(gtid, texelPosition, uint2(1, 0), uint2(-1, 0), uint2(0, 1), uint2(0, -1));
    }

    {
        uint2 texelPosition = blockBase + uint2(0, 3);
        processPixel(gtid, texelPosition, uint2(1, 0), uint2(-1, 0), uint2(0, 1), uint2(0, -1));
    }

    {
        uint2 texelPosition = blockBase + uint2(3, 0);
        processPixel(gtid, texelPosition, uint2(1, 0), uint2(-1, 0), uint2(0, 1), uint2(0, -1));
    }
}