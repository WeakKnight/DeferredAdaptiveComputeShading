import Utils;

RWStructuredBuffer<uint> gOutputBuffer;

[shader("compute")]
[numthreads(64, 1, 1)]
void testWaveGetLaneIndex(uint tid: SV_DispatchThreadID, uint gtid: SV_GroupThreadID)
{
    uint laneIndex = WaveGetLaneIndex();
    gOutputBuffer[tid] = laneIndex;
}

[shader("compute")]
[numthreads(64, 1, 1)]
void testWaveActiveCountBits(uint tid: SV_DispatchThreadID, uint gtid: SV_GroupThreadID)
{
    bool active = (tid % 4) == 0;
    uint activeCount = _WaveActiveCountBits(active);
    gOutputBuffer[tid] = activeCount;
}

[shader("compute")]
[numthreads(64, 1, 1)]
void testWavePrefixCountBits(uint tid: SV_DispatchThreadID, uint gtid: SV_GroupThreadID)
{
    bool active = (tid % 4) == 0;
    uint activeCount = _WavePrefixCountBits(active);
    gOutputBuffer[tid] = activeCount;
}