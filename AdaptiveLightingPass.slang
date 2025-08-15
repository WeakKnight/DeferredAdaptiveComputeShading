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