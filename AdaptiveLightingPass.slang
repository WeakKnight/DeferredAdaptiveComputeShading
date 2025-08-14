import Shading;

#define OP_SHADE 1
#define OP_SEARCH 2
#define WARP_WIDTH 32 //(NVIDIA)
#define QUEUE_LENGTH (WARP_WIDTH + WARP_WIDTH - 1)

uniform uint2 gScreenSize;
uniform uint gTotalPixelNum;

groupshared uint sq_offset;
groupshared uint sq_count;
groupshared int2 sq_coords[QUEUE_LENGTH];

groupshared uint op_current;
groupshared uint op_active;
groupshared uint op_id;

RWTexture2D<float4> gOutputTexture;
RWStructuredBuffer<uint> gLayoutScratch;

int2 linearIdToCoord(uint id, uint2 size)
{
    uint x = id % size.x;
    uint y = id / size.x;
    return int2(x, y);
}

bool shouldShade(uint id, out int2 coord, out float4 interp_color)
{
    coord = linearIdToCoord(id, gScreenSize);

    // [User condition for deciding to shade this pixel/sample,
    //  based on reading already-assigned neighbors' colors and/or G-buffer]
    // 注意：如果要读取 img_output 邻域，请在调用此函数前确保有相应的内存栅栏，
    // 同组内读取可用 GroupMemoryBarrierWithGroupSync 保障；跨组不可靠，建议 tile 化。

    bool needShade = true; // TODO: 按你的逻辑替换
    if (!needShade)
    {
        // [Interpolate pixel/sample from neighbors]
        interp_color = float4(0.5, 0.5, 0.5, 1.0); // TODO: 替换为你的插值
        return false;
    }
    else
    {
        return true;
    }
}

[shader("compute")]
[numthreads(WARP_WIDTH, 1, 1)]
void main(uint tid: SV_DispatchThreadID, uint local_index: SV_GroupIndex)
{
    if (tid >= gTotalPixelNum)
    {
        return;
    }

#if 0
    int2 coord = linearIdToCoord(tid, gScreenSize);
    gOutputTexture[coord] = shade(coord);
#elif 0

#else

    // warp内的第一个thread则初始化队列
    if (local_index == 0)
    {
        sq_offset = 0;
        sq_count = 0;
    }
    GroupMemoryBarrierWithGroupSync();

    uint id_next = gLayoutScratch[0];
    while (id_next < gTotalPixelNum || sq_count > 0)
    {
        // 每轮任务执行的开始, 首位置的线程需要:
        // 1. 如果队列任务数量已经大于等于一个warp的尺寸, 可以整体切换到shading模式, 先渲染warp size个任务
        // 2. 如果队列剩余任务不够一个warp尺寸, 但是确实没东西要搜索了(sq_count > 0 && id_next >= gTotalPixelNum), 依然要进渲染模式, 把剩下的任务都渲染完
        // 3. 如果队列剩余任务不够一个warp尺寸, 还有东西可以搜索, 那就进搜索模式, 目标是搜索warp个任务
        if (local_index == 0) 
        {
            if (sq_count >= WARP_WIDTH) 
            {
                op_current = OP_SHADE;
                op_active = WARP_WIDTH;
            } 
            else 
            {
                if (sq_count > 0 && id_next >= gTotalPixelNum) 
                {
                    op_current = OP_SHADE;
                    op_active = sq_count;
                } 
                else 
                {
                    op_current = OP_SEARCH;
                    op_active = min(WARP_WIDTH, gTotalPixelNum - id_next);
                }
            }
        }
        GroupMemoryBarrierWithGroupSync();

        // 判断是否是active thread
        if (local_index < op_active)
        {
            if (op_current == OP_SHADE)
            {
                const uint idx = (sq_offset + local_index) % QUEUE_LENGTH;
                const int2 coord = sq_coords[idx];

                float4 color = shade(coord);
                gOutputTexture[coord] = color;

                GroupMemoryBarrierWithGroupSync();

                if (local_index == 0)
                {
                    sq_offset = (sq_offset + op_active);
                    sq_count = sq_count - op_active;
                }
            }
            else // OP_SEARCH
            {
                // 修改任务指针的指向
                if (local_index == 0)
                {
                    InterlockedAdd(gLayoutScratch[0], op_active, op_id);
                }
                DeviceMemoryBarrierWithGroupSync();
                uint id = op_id + local_index;
                if (id < gTotalPixelNum)
                {
                    int2 coord = linearIdToCoord(id, gScreenSize);
                    bool should_shade = true;
                    if (should_shade)
                    {
                        uint oldCount;
                        InterlockedAdd(sq_count, 1, oldCount);
                        uint qidx = (sq_offset + oldCount) % QUEUE_LENGTH;
                        sq_coords[qidx] = coord;
                    }
                }
            } 
        }

        GroupMemoryBarrierWithGroupSync();
    }
#endif
}