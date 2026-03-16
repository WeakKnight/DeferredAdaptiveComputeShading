import Shading;


#define WAVE_SIZE 32

uniform uint2 gScreenSize;
uniform uint2 gScreenGridDim;
uniform uint2 gSuperGridDim;
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
    float3 mean   = 0.25 * (A + B + C + D);
    float3 sqMean = 0.25 * (A * A + B * B + C * C + D * D);
    float3 var    = sqMean - mean * mean;

    const float varianceThreshold = 5e-4f;
    return any(var >= varianceThreshold);
}

// ---------------------------------------------------------------------------
// DistributeWork infrastructure
// ---------------------------------------------------------------------------

groupshared uint WorkBatch[WAVE_SIZE];
groupshared uint gProducerBase[WAVE_SIZE];
groupshared uint gProducerMask[WAVE_SIZE];

uint NthSetBit(uint mask, uint n)
{
    for (uint i = 0; i < 32; i++)
    {
        if (mask & (1u << i))
        {
            if (n == 0) return i;
            n--;
        }
    }
    return 0;
}

interface IShadeTask
{
    void RunChild(bool bActive, uint SourceLane, uint LocalItemIndex);
};

// Local wave-level work distribution from Brian Karis.
// Ref: https://graphicrants.blogspot.com/2026/03/variable-sized-work.html
//
// Each lane produces a variable number of work items (NumWorkItems).
// Items are prefix-summed into a contiguous queue and consumed in
// wave-sized batches so every lane stays productive. Producer state
// is read from groupshared memory (gProducerBase / gProducerMask)
// rather than via WaveReadLaneAt on struct members.
void DistributeWork<T : IShadeTask>(T task, uint GroupIndex, uint NumWorkItems)
{
    const uint LaneCount   = WAVE_SIZE;
    const uint LaneIndex   = GroupIndex & (LaneCount - 1);
    const uint QueueOffset = GroupIndex & ~(LaneCount - 1);

    uint FirstWorkItem  = WavePrefixSum(NumWorkItems);
    uint TotalWorkItems = WaveReadLaneAt(FirstWorkItem + NumWorkItems, LaneCount - 1);

    uint SourceData = (FirstWorkItem << 8) | LaneIndex;

    for (uint BatchFirstItem = 0; BatchFirstItem < TotalWorkItems; BatchFirstItem += LaneCount)
    {
        uint ItemIndex = BatchFirstItem + LaneIndex;

        WorkBatch[GroupIndex] = 0xFFFFFFFFu;
        GroupMemoryBarrier();

        if (NumWorkItems > 0u)
        {
            int FirstItemLane = int(FirstWorkItem - BatchFirstItem);
            if (FirstItemLane < (int)LaneCount && FirstItemLane + (int)NumWorkItems - 1 >= 0)
                WorkBatch[QueueOffset + max(FirstItemLane, 0)] = SourceData;
        }

        GroupMemoryBarrier();

        uint BatchValue = WorkBatch[GroupIndex];
        uint BatchMask  = WaveActiveBallot(BatchValue != 0xFFFFFFFFu).x;
        uint bitsForLane = BatchMask & ~(0xFFFFFFFEu << LaneIndex);
        uint BatchLane  = bitsForLane != 0 ? firstbithigh(bitsForLane) : 0;
        uint SourceValue    = WaveReadLaneAt(BatchValue, BatchLane);
        uint SourceLane     = SourceValue & 0xFFu;
        uint LocalItemIndex = ItemIndex - (SourceValue >> 8);
        bool bActive        = ItemIndex < TotalWorkItems;

        task.RunChild(bActive, SourceLane, LocalItemIndex);
    }
}

// ---------------------------------------------------------------------------
// Pass 1 — 2x2 super-block, 4 pixels/lane
// ---------------------------------------------------------------------------

static const uint2 kBlockOffsets[4] = { uint2(0,0), uint2(4,0), uint2(0,4), uint2(4,4) };
static const int2 kPass1NeighborOffsets[4] = { int2(2,2), int2(-2,2), int2(2,-2), int2(-2,-2) };

struct Pass1Task : IShadeTask
{
    void RunChild(bool bActive, uint SourceLane, uint LocalItemIndex)
    {
        if (!bActive) return;
        uint2 base = uint2(gProducerBase[SourceLane] & 0xFFFF, gProducerBase[SourceLane] >> 16);
        uint bitIdx = NthSetBit(gProducerMask[SourceLane], LocalItemIndex);
        uint2 texelPos = base + kBlockOffsets[bitIdx] + uint2(2, 2);
        gOutputTexture[texelPos] = shade(texelPos);
    }
};

[shader("compute")]
[numthreads(WAVE_SIZE, 1, 1)]
void pass1(uint tid: SV_DispatchThreadID, uint gtid: SV_GroupThreadID)
{
    uint2 tid2d = uint2(tid % gSuperGridDim.x, tid / gSuperGridDim.x);
    uint2 superBase = tid2d * 8;

    uint shadeMask = 0;
    uint numShadeItems = 0;

    [unroll]
    for (uint i = 0; i < 4; i++)
    {
        uint2 pos = superBase + kBlockOffsets[i] + uint2(2, 2);
        if (any(pos >= gScreenSize)) continue;

        float4 n0 = gOutputTexture[pos + kPass1NeighborOffsets[0]];
        float4 n1 = gOutputTexture[pos + kPass1NeighborOffsets[1]];
        float4 n2 = gOutputTexture[pos + kPass1NeighborOffsets[2]];
        float4 n3 = gOutputTexture[pos + kPass1NeighborOffsets[3]];

        bool needsShade = shouldShade(n0.rgb, n1.rgb, n2.rgb, n3.rgb);

        if (needsShade)
        {
            shadeMask |= (1u << i);
            numShadeItems++;
        }
        else
        {
            gOutputTexture[pos] = 0.25 * (n0 + n1 + n2 + n3);
        }
    }

    gProducerBase[gtid] = superBase.x | (superBase.y << 16);
    gProducerMask[gtid] = shadeMask;

    Pass1Task task;
    DistributeWork(task, gtid, numShadeItems);
}

// ---------------------------------------------------------------------------
// Pass 2 — 2x2 super-block, 8 pixels/lane
// ---------------------------------------------------------------------------

static const uint2 kPass2Pixels[8] = {
    uint2(0,2), uint2(2,0),
    uint2(4,2), uint2(6,0),
    uint2(0,6), uint2(2,4),
    uint2(4,6), uint2(6,4)
};
static const int2 kPass2NeighborOffsets[4] = { int2(0,2), int2(2,0), int2(0,-2), int2(-2,0) };

struct Pass2Task : IShadeTask
{
    void RunChild(bool bActive, uint SourceLane, uint LocalItemIndex)
    {
        if (!bActive) return;
        uint2 base = uint2(gProducerBase[SourceLane] & 0xFFFF, gProducerBase[SourceLane] >> 16);
        uint bitIdx = NthSetBit(gProducerMask[SourceLane], LocalItemIndex);
        uint2 texelPos = base + kPass2Pixels[bitIdx];
        gOutputTexture[texelPos] = shade(texelPos);
    }
};

[shader("compute")]
[numthreads(WAVE_SIZE, 1, 1)]
void pass2(uint tid: SV_DispatchThreadID, uint gtid: SV_GroupThreadID)
{
    uint2 tid2d = uint2(tid % gSuperGridDim.x, tid / gSuperGridDim.x);
    uint2 superBase = tid2d * 8;

    uint shadeMask = 0;
    uint numShadeItems = 0;

    [unroll]
    for (uint i = 0; i < 8; i++)
    {
        uint2 pos = superBase + kPass2Pixels[i];
        if (any(pos >= gScreenSize)) continue;

        float4 n0 = gOutputTexture[pos + kPass2NeighborOffsets[0]];
        float4 n1 = gOutputTexture[pos + kPass2NeighborOffsets[1]];
        float4 n2 = gOutputTexture[pos + kPass2NeighborOffsets[2]];
        float4 n3 = gOutputTexture[pos + kPass2NeighborOffsets[3]];

        bool needsShade = shouldShade(n0.rgb, n1.rgb, n2.rgb, n3.rgb);

        if (needsShade)
        {
            shadeMask |= (1u << i);
            numShadeItems++;
        }
        else
        {
            gOutputTexture[pos] = 0.25 * (n0 + n1 + n2 + n3);
        }
    }

    gProducerBase[gtid] = superBase.x | (superBase.y << 16);
    gProducerMask[gtid] = shadeMask;

    Pass2Task task;
    DistributeWork(task, gtid, numShadeItems);
}

// ---------------------------------------------------------------------------
// Pass 3 — 1 block/lane, 4 pixels/lane
// ---------------------------------------------------------------------------

static const uint2 kPass3Pixels[4] = { uint2(1,1), uint2(1,3), uint2(3,1), uint2(3,3) };
static const int2 kPass3NeighborOffsets[4] = { int2(1,1), int2(-1,-1), int2(1,-1), int2(-1,1) };

struct Pass3Task : IShadeTask
{
    void RunChild(bool bActive, uint SourceLane, uint LocalItemIndex)
    {
        if (!bActive) return;
        uint2 base = uint2(gProducerBase[SourceLane] & 0xFFFF, gProducerBase[SourceLane] >> 16);
        uint bitIdx = NthSetBit(gProducerMask[SourceLane], LocalItemIndex);
        uint2 texelPos = base + kPass3Pixels[bitIdx];
        gOutputTexture[texelPos] = shade(texelPos);
    }
};

[shader("compute")]
[numthreads(WAVE_SIZE, 1, 1)]
void pass3(uint tid: SV_DispatchThreadID, uint gtid: SV_GroupThreadID)
{
    uint2 tid2d = uint2(tid % gScreenGridDim.x, tid / gScreenGridDim.x);
    uint2 blockBase = tid2d * 4;

    uint shadeMask = 0;
    uint numShadeItems = 0;

    [unroll]
    for (uint i = 0; i < 4; i++)
    {
        uint2 pos = blockBase + kPass3Pixels[i];
        if (any(pos >= gScreenSize)) continue;

        float4 n0 = gOutputTexture[pos + kPass3NeighborOffsets[0]];
        float4 n1 = gOutputTexture[pos + kPass3NeighborOffsets[1]];
        float4 n2 = gOutputTexture[pos + kPass3NeighborOffsets[2]];
        float4 n3 = gOutputTexture[pos + kPass3NeighborOffsets[3]];

        bool needsShade = shouldShade(n0.rgb, n1.rgb, n2.rgb, n3.rgb);

        if (needsShade)
        {
            shadeMask |= (1u << i);
            numShadeItems++;
        }
        else
        {
            gOutputTexture[pos] = 0.25 * (n0 + n1 + n2 + n3);
        }
    }

    gProducerBase[gtid] = blockBase.x | (blockBase.y << 16);
    gProducerMask[gtid] = shadeMask;

    Pass3Task task;
    DistributeWork(task, gtid, numShadeItems);
}

// ---------------------------------------------------------------------------
// Pass 4 — 1 block/lane, 8 pixels/lane
// ---------------------------------------------------------------------------

static const uint2 kPass4Pixels[8] = {
    uint2(0,1), uint2(1,0), uint2(1,2), uint2(2,1),
    uint2(2,3), uint2(3,2), uint2(0,3), uint2(3,0)
};
static const int2 kPass4NeighborOffsets[4] = { int2(1,0), int2(-1,0), int2(0,1), int2(0,-1) };

struct Pass4Task : IShadeTask
{
    void RunChild(bool bActive, uint SourceLane, uint LocalItemIndex)
    {
        if (!bActive) return;
        uint2 base = uint2(gProducerBase[SourceLane] & 0xFFFF, gProducerBase[SourceLane] >> 16);
        uint bitIdx = NthSetBit(gProducerMask[SourceLane], LocalItemIndex);
        uint2 texelPos = base + kPass4Pixels[bitIdx];
        gOutputTexture[texelPos] = shade(texelPos);
    }
};

[shader("compute")]
[numthreads(WAVE_SIZE, 1, 1)]
void pass4(uint tid: SV_DispatchThreadID, uint gtid: SV_GroupThreadID)
{
    uint2 tid2d = uint2(tid % gScreenGridDim.x, tid / gScreenGridDim.x);
    uint2 blockBase = tid2d * 4;

    uint shadeMask = 0;
    uint numShadeItems = 0;

    [unroll]
    for (uint i = 0; i < 8; i++)
    {
        uint2 pos = blockBase + kPass4Pixels[i];
        if (any(pos >= gScreenSize)) continue;

        float4 n0 = gOutputTexture[pos + kPass4NeighborOffsets[0]];
        float4 n1 = gOutputTexture[pos + kPass4NeighborOffsets[1]];
        float4 n2 = gOutputTexture[pos + kPass4NeighborOffsets[2]];
        float4 n3 = gOutputTexture[pos + kPass4NeighborOffsets[3]];

        bool needsShade = shouldShade(n0.rgb, n1.rgb, n2.rgb, n3.rgb);

        if (needsShade)
        {
            shadeMask |= (1u << i);
            numShadeItems++;
        }
        else
        {
            gOutputTexture[pos] = 0.25 * (n0 + n1 + n2 + n3);
        }
    }

    gProducerBase[gtid] = blockBase.x | (blockBase.y << 16);
    gProducerMask[gtid] = shadeMask;

    Pass4Task task;
    DistributeWork(task, gtid, numShadeItems);
}
