import Shading;

uniform uint2 gScreenSize;
RWTexture2D<float4> gOutputTexture;

[shader("compute")]
[numthreads(8, 8, 1)]
void LightingPass(uint2 tid: SV_DispatchThreadID)
{
    if (any(tid >= gScreenSize))
    {
        return;
    }

    gOutputTexture[tid] = shade(tid);
}