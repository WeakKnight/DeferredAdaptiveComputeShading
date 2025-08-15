import Shading;

uniform uint2 gScreenSize;

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
    
    const float varianceThreshold = 1e-2f;
    return (Yvar <= varianceThreshold);
}

[shader("compute")]
[numthreads(8, 8, 1)]
void pass1(uint2 tid: SV_DispatchThreadID)
{
    uint2 blockBase = tid * 4;
    uint2 texelPosition = blockBase + uint2(2, 2);
    if (any(texelPosition >= gScreenSize))
    {
        return;
    }

    float4 neighbor0 = gOutputTexture[texelPosition + uint2(2, 2)];
    float4 neighbor1 = gOutputTexture[texelPosition + uint2(-2, 2)];
    float4 neighbor2 = gOutputTexture[texelPosition + uint2(2, -2)];
    float4 neighbor3 = gOutputTexture[texelPosition + uint2(-2, -2)];

    if (shouldShade(neighbor0.rgb, neighbor1.rgb, neighbor2.rgb, neighbor3.rgb))
    {
        gOutputTexture[texelPosition] = shade(texelPosition);
    }
    else
    {
        gOutputTexture[texelPosition] = 0.25 * (neighbor0 + neighbor1 + neighbor2 + neighbor3);
    }
}

void processPixel(uint2 texelPosition, uint2 offsetA, uint2 offsetB, uint2 offsetC, uint2 offsetD)
{
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
        gOutputTexture[texelPosition] = 0.25 * (neighbor0 + neighbor1 + neighbor2 + neighbor3);
    }
}

[shader("compute")]
[numthreads(8, 8, 1)]
void pass2(uint2 tid: SV_DispatchThreadID)
{
    uint2 blockBase = tid * 4;

    {
        uint2 texelPosition = blockBase + uint2(0, 2);
        processPixel(texelPosition, uint2(0, 2), uint2(2, 0), uint2(0, -2), uint2(-2, 0));
    }

    {
        uint2 texelPosition = blockBase + uint2(2, 0);
        processPixel(texelPosition, uint2(0, 2), uint2(2, 0), uint2(0, -2), uint2(-2, 0));
    }
}

[shader("compute")]
[numthreads(8, 8, 1)]
void pass3(uint2 tid: SV_DispatchThreadID)
{
    uint2 blockBase = tid * 4;

    {
        uint2 texelPosition = blockBase + uint2(1, 1);
        processPixel(texelPosition, uint2(1, 1), uint2(-1, -1), uint2(1, -1), uint2(-1, 1));
    }

    {
        uint2 texelPosition = blockBase + uint2(1, 3);
        processPixel(texelPosition, uint2(1, 1), uint2(-1, -1), uint2(1, -1), uint2(-1, 1));
    }

    {
        uint2 texelPosition = blockBase + uint2(3, 1);
        processPixel(texelPosition, uint2(1, 1), uint2(-1, -1), uint2(1, -1), uint2(-1, 1));
    }

    {
        uint2 texelPosition = blockBase + uint2(3, 3);
        processPixel(texelPosition, uint2(1, 1), uint2(-1, -1), uint2(1, -1), uint2(-1, 1));
    }
}

[shader("compute")]
[numthreads(8, 8, 1)]
void pass4(uint2 tid: SV_DispatchThreadID)
{
    uint2 blockBase = tid * 4;

    {
        uint2 texelPosition = blockBase + uint2(0, 1);
        processPixel(texelPosition, uint2(1, 0), uint2(-1, 0), uint2(0, 1), uint2(0, -1));
    }

    {
        uint2 texelPosition = blockBase + uint2(1, 0);
        processPixel(texelPosition, uint2(1, 0), uint2(-1, 0), uint2(0, 1), uint2(0, -1));
    }

    {
        uint2 texelPosition = blockBase + uint2(1, 2);
        processPixel(texelPosition, uint2(1, 0), uint2(-1, 0), uint2(0, 1), uint2(0, -1));
    }

    {
        uint2 texelPosition = blockBase + uint2(2, 1);
        processPixel(texelPosition, uint2(1, 0), uint2(-1, 0), uint2(0, 1), uint2(0, -1));
    }

    {
        uint2 texelPosition = blockBase + uint2(2, 3);
        processPixel(texelPosition, uint2(1, 0), uint2(-1, 0), uint2(0, 1), uint2(0, -1));
    }

    {
        uint2 texelPosition = blockBase + uint2(3, 2);
        processPixel(texelPosition, uint2(1, 0), uint2(-1, 0), uint2(0, 1), uint2(0, -1));
    }

    {
        uint2 texelPosition = blockBase + uint2(0, 3);
        processPixel(texelPosition, uint2(1, 0), uint2(-1, 0), uint2(0, 1), uint2(0, -1));
    }

    {
        uint2 texelPosition = blockBase + uint2(3, 0);
        processPixel(texelPosition, uint2(1, 0), uint2(-1, 0), uint2(0, 1), uint2(0, -1));
    }
}