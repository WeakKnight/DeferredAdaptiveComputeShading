Texture2D<float4> gPositionTexture;
Texture2D<float4> gNormalTexture;
Texture2D<float4> gDiffuseTexture;
Texture2D<float4> gSpecularTexture;

float4 shade(int2 tid)
{
    float3 posW = gPositionTexture[tid].xyz;
    float3 normal = gNormalTexture[tid].xyz;
    float3 diffuse = gDiffuseTexture[tid].xyz;
    float3 specular = gSpecularTexture[tid].xyz;

    float3 V = float3(gNormalTexture[tid].w, gDiffuseTexture[tid].w, gSpecularTexture[tid].w);
    float3 L = normalize(float3(-0.8, 0.4, -0.3));

    float3 res = 0;

    if (length(normal) <= 0.0)
    {
        float sundot = saturate(dot(normal, L));
        // sky
        res = float3(0.3, 0.5, 0.85) - (V.y * V.y) * 0.5;
        res = lerp(res, 0.85 * float3(0.7, 0.75, 0.85), pow(1.0 - max(-V.y, 0.0), 4.0));
        // sun
        res += 0.25 * float3(1.0, 0.7, 0.4) * pow(sundot, 5.0);
        res += 0.25 * float3(1.0, 0.8, 0.6) * pow(sundot, 64.0);
        res += 0.2 * float3(1.0, 0.8, 0.6) * pow(sundot, 512.0);

        // horizon
        res = lerp(res, 0.68 * float3(0.4, 0.65, 1.0), pow(1.0 - max(-V.y, 0.0), 16.0));
    }
    else
    {
        float ambientLobe = clamp(0.5 + 0.5 * normal.y, 0.0, 1.0);
        float diffuseLobe = clamp(dot(L, normal), 0.0, 1.0);
        float backSideLobe = clamp(0.2 + 0.8 * dot(normalize(float3(-L.x, 0.0, L.z)), normal), 0.0, 1.0);
        float shadowTerm = 1.0; // if (dif >= 0.0001) sh = softShadow(pos + light1 * SC * 0.05, L, t);

        float3 lighting = float3(0.0);
        lighting += diffuseLobe * float3(8.00, 5.00, 3.00) * 1.3 * float3(shadowTerm, shadowTerm * shadowTerm * 0.5 + 0.5 * shadowTerm, shadowTerm * shadowTerm * 0.8 + 0.2 * shadowTerm);
        lighting += ambientLobe * float3(0.40, 0.60, 1.00) * 1.2;
        lighting += backSideLobe * float3(0.40, 0.50, 0.60);

        res = lighting * diffuse;
    }

    // gamma correction
    res = sqrt(res);

    // [Shading for this pixel/sample]
    return float4(res, 1);
}