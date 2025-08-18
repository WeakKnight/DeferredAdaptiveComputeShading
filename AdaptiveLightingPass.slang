import Shading;
import Utils;

#define VIS_INTERP_AREA 0
#define WAVE_SIZE 32

enum WaveMode
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


struct Payload
{
    float3 interpolatedResult;
    uint linearPixelIndex;
};

groupshared Payload gPayload[WAVE_SIZE];

#if 0
void processPixel(uint gtid, uint2 texelPosition, uint2 offsetA, uint2 offsetB, uint2 offsetC, uint2 offsetD)
{
    if (any(texelPosition >= gScreenSize))
    {
        return;
    }

    const uint waveId = gtid.x >> 5; // 0 or 1
    const uint lane = WaveGetLaneIndex();   // 0..31

    float4 neighbor0 = gOutputTexture[texelPosition + offsetA];
    float4 neighbor1 = gOutputTexture[texelPosition + offsetB];
    float4 neighbor2 = gOutputTexture[texelPosition + offsetC];
    float4 neighbor3 = gOutputTexture[texelPosition + offsetD];
    float4 interpolatedResult = 0.25 * (neighbor0 + neighbor1 + neighbor2 + neighbor3);

    bool isShade = shouldShade(neighbor0.rgb, neighbor1.rgb, neighbor2.rgb, neighbor3.rgb);
    uint idxInWave, shadeCountWave;
    WavePartition2(isShade, idxInWave, shadeCountWave);
    if (lane == 0)
    { 
        gShadeCount[waveId] = shadeCountWave;
    }
    GroupMemoryBarrierWithGroupSync();
    uint totalShadeCount = gShadeCount[0] + gShadeCount[1];

    Payload payload;
    payload.linearPixelIndex = texelPosition.x + texelPosition.y * gScreenSize.x;
    payload.interpolatedResult = interpolatedResult.rgb;
    gPayload[waveId * 32 + idxInWave] = payload;
    
    // 100% occupancy wave
    if (waveId == 0)
    {
        WaveMode mode = totalShadeCount >= 32 ? WaveMode.Shade : WaveMode.Interpolate;
    }
    
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
[numthreads(WAVE_SIZE, 1, 1)]
void pass1(uint tid: SV_DispatchThreadID, uint gtid: SV_GroupThreadID)
{
    uint2 tid2d = uint2(tid % gScreenGridDim.x, tid / gScreenGridDim.x);
    uint2 blockBase = tid2d * 4;
    uint2 texelPosition = blockBase + uint2(2, 2);
    processPixel(gtid, texelPosition, uint2(2, 2), uint2(-2, 2), uint2(2, -2), uint2(-2, -2));
}

[shader("compute")]
[numthreads(WAVE_SIZE, 1, 1)]
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
[numthreads(WAVE_SIZE, 1, 1)]
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
[numthreads(WAVE_SIZE, 1, 1)]
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