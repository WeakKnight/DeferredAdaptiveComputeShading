// - gl_LocalInvocationIndex → SV_GroupIndex
// - local_size_x → [numthreads(WARP_WIDTH,1,1)]
// - shared → groupshared
// - imageStore → RWTexture2D<float4>[coord] 赋值
// - SSBO/atomicAdd → RWStructuredBuffer 或 RWByteAddressBuffer 上的 InterlockedAdd
// - 内存屏障
//   - GLSL memoryBarrierShared → GroupMemoryBarrierWithGroupSync()
//   - GLSL memoryBarrierBuffer → DeviceMemoryBarrierWithGroupSync()（或 AllMemoryBarrierWithGroupSync()）
//   - GLSL barrier() → GroupMemoryBarrierWithGroupSync()

// 配置
#define OP_SHADE   1
#define OP_SEARCH  2
#define WARP_WIDTH 32 // (NVIDIA)
//#define WARP_WIDTH 64 // (AMD)
#define QUEUE_LENGTH (WARP_WIDTH + WARP_WIDTH - 1)

// 资源绑定（按需修改寄存器与空间）
cbuffer Params : register(b0)
{
    uint total_pixels;
    uint2 targetSize;   // 如果需要从 id -> coord 的映射，可传入宽高
    uint  padding_;
};

// SSBO: 下一个要处理的线性 id，初始为 0（每帧重置）
RWStructuredBuffer<uint> LayoutScratch : register(u0); // LayoutScratch[0] = id_next

// 输出图像（等价 GLSL layout(rgba8) image2D）
RWTexture2D<float4> img_output : register(u1);

// 组共享内存
groupshared uint   sq_offset;
groupshared uint   sq_count;
groupshared int2   sq_coords[QUEUE_LENGTH];

groupshared uint   op_current;
groupshared uint   op_active;
groupshared uint   op_id;

// 你需要实现的函数（示意签名保持一致）
float4 shade(int2 coord)
{
    // [Shading for this pixel/sample]
    return float4(0, 0, 0, 1);
}

// 从线性 id 计算像素坐标；按需修改
int2 LinearIdToCoord(uint id, uint2 size)
{
    // 左上为 (0,0) 的常见约定
    uint x = id % size.x;
    uint y = id / size.x;
    return int2(x, y);
}

// 判定是否需要真实着色；若不需要，输出插值颜色
bool get_should_shade(uint id, out int2 coord, out float4 interp_color)
{
    coord = LinearIdToCoord(id, targetSize);

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

[numthreads(WARP_WIDTH, 1, 1)]
void CSMain(uint3 DTid  : SV_DispatchThreadID,
            uint3 GTid  : SV_GroupThreadID,
            uint3 GId   : SV_GroupID,
            uint  GIdx  : SV_GroupIndex) // 等价 gl_LocalInvocationIndex
{
    const uint local_index = GIdx;

    if (local_index == 0)
    {
        sq_offset = 0;
        sq_count  = 0;
    }
    GroupMemoryBarrierWithGroupSync(); // 等价 memoryBarrierShared + barrier

    // 循环直到所有像素被处理且队列清空
    // 注意：LayoutScratch[0] 持有全局 id_next
    for (;;)
    {
        // 读取当前全局进度与队列状态（无锁读）
        uint id_next_snapshot = LayoutScratch[0];

        // 退出条件：所有像素已领取且队列为空
        if (id_next_snapshot >= total_pixels && sq_count == 0)
        {
            break;
        }

        // 由线程 0 决策本轮执行 SEARCH 还是 SHADE，并设定参与线程数
        if (local_index == 0)
        {
            if (sq_count >= WARP_WIDTH)
            {
                op_current = OP_SHADE;
                op_active  = WARP_WIDTH;
            }
            else
            {
                if (sq_count > 0 && id_next_snapshot >= total_pixels)
                {
                    op_current = OP_SHADE;
                    op_active  = sq_count;
                }
                else
                {
                    op_current = OP_SEARCH;

                    // 防止 total_pixels - id_next_snapshot 为 0 的情况
                    uint remain = (id_next_snapshot < total_pixels)
                                ? (total_pixels - id_next_snapshot) : 0u;
                    op_active = (remain > 0u) ? min((uint)WARP_WIDTH, remain) : 0u;
                }
            }
        }
        GroupMemoryBarrierWithGroupSync(); // 等价 memoryBarrierShared + barrier

        // 若本轮没有活跃线程（比如 remain=0 且队列又没到一个 warp），直接进入下一轮
        if (local_index < op_active)
        {
            if (op_current == OP_SHADE)
            {
                // 从共享队列批量取出并真实着色
                const uint idx   = (sq_offset + local_index) % QUEUE_LENGTH;
                const int2 coord = sq_coords[idx];

                float4 color = shade(coord);
                // 写入输出
                img_output[coord] = color;

                // 本轮结束后由 0 号线程推进队列头
                if (local_index == 0)
                {
                    sq_offset = (sq_offset + op_active) % QUEUE_LENGTH;
                    sq_count  = sq_count - op_active;
                }
            }
            else // OP_SEARCH
            {
                // 由 0 号线程一次性领取一段 id（原子）
                if (local_index == 0)
                {
                    InterlockedAdd(LayoutScratch[0], op_active, op_id);
                }
                // 同步，确保 op_id 对所有线程可见
                DeviceMemoryBarrierWithGroupSync();

                uint id = op_id + local_index;

                if (id < total_pixels)
                {
                    int2   coord;
                    float4 interp_color;
                    bool should_shade = get_should_shade(id, coord, interp_color);

                    if (should_shade)
                    {
                        // 入组内环形队列（原子增加计数并获得位置）
                        uint oldCount;
                        InterlockedAdd(sq_count, 1, oldCount);
                        uint qidx = (sq_offset + oldCount) % QUEUE_LENGTH;
                        sq_coords[qidx] = coord;
                        // 不在此处着色，等待凑批
                    }
                    else
                    {
                        // 直接写插值结果
                        img_output[coord] = interp_color;
                        // 如需确保组内后续读到该像素的结果，添加：
                        // GroupMemoryBarrierWithGroupSync();
                    }
                }
            }
        }

        // 组内同步，确保共享队列与输出可见性
        GroupMemoryBarrierWithGroupSync(); // 等价 barrier()
    }
}

// 注意与建议
// - 资源绑定
//   - LayoutScratch 这里用 RWStructuredBuffer<uint> 简化，LayoutScratch[0] 为 id_next。若你已有结构化 SSBO，按需对齐。
//   - img_output 使用 RWTexture2D<float4>，等价 GLSL image2D(rgba8)。写入前可手动 saturate/clamp 到 [0,1]。
// - 内存屏障
//   - 组内使用 GroupMemoryBarrierWithGroupSync 保证 groupshared 一致性。
//   - 读取/写入 UAV（RWTexture/RWBuffer）在同组内通常也要加 GroupMemoryBarrierWithGroupSync 来确保顺序；跨组不可依赖顺序一致性，建议 tile 化把邻域依赖限制在组内。
//   - 原 GLSL 的 memoryBarrierBuffer 对应 DeviceMemoryBarrierWithGroupSync 或 AllMemoryBarrierWithGroupSync；这里在领取 id 后用了 DeviceMemoryBarrierWithGroupSync 保障 op_id 可见。
// - id → coord 映射
//   - 我提供了 LinearIdToCoord(id, targetSize)。如果你的线性 id 包含 MSAA/subsample，请自行扩展为 (x,y,sample) 的映射。
// - 队列容量
//   - 保持 QUEUE_LENGTH 至少 2×WARP_WIDTH。若 get_should_shade 经常为 true，建议增大到 4×WARP_WIDTH，并在入队前判断空间以避免溢出。
// - 阶段切换抖动
//   - 可加入滞回：sq_count >= 2×WARP_WIDTH 才进 SHADE；回到 SEARCH 的阈值设为 WARP_WIDTH/2，减少 oscillation。
// - 调试
//   - 在 LayoutScratch 增加统计计数器（搜索次数、着色次数、入队峰值）便于分析瓶颈。
//   - 提供强制路径开关：全部 shade 或全部 interpolate，验证同步与正确性。

// 如果你贴出你的绑定布局（root signature/descriptor set）和具体“是否需要着色”的判据，我可以把 get_should_shade 与 shade 填到更贴近你项目的模板。