import Shadertoy;
import Elevated;
import GBuffer;

RWTexture2D<float4> gPositionTexture;
RWTexture2D<float4> gNormalTexture;
RWTexture2D<float4> gDiffuseTexture;
RWTexture2D<float4> gSpecularTexture;

[shader("compute")]
[numthreads(8, 8, 1)]
void GBufferPass(uint2 tid: SV_DispatchThreadID)
{
    if (any(tid >= iResolution))
    {
        return;
    }

    float2 fragCoord = tid + 0.5;
    float4 fragColor = 1;
    GBuffer gbuffer = mainImage(fragColor, fragCoord);

    // flip y
    int2 outputPos = int2(tid.x, (int)iResolution.y - tid.y + 1);

    gPositionTexture[outputPos] = float4(gbuffer.posW, 1);
    gNormalTexture[outputPos] = float4(gbuffer.normal, gbuffer.V.x);
    gDiffuseTexture[outputPos] = float4(gbuffer.diffuse, gbuffer.V.y);
    gSpecularTexture[outputPos] = float4(gbuffer.specular, gbuffer.V.z);
}