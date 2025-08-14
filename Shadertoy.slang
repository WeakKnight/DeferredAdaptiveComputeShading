uniform float iFrame;
uniform float iTime;
uniform float2 iResolution;
Texture2D<float> gBlueNoiseTex; /* 256 x 256 1d blue noise*/
SamplerState gLinearClampSampler;
SamplerState gLinearRepeatSampler;