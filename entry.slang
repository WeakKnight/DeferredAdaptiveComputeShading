// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

struct Processor {
    StructuredBuffer<uint> a;
    StructuredBuffer<uint> b;
    RWStructuredBuffer<uint> c;
    void process(uint index) { c[index] = a[index] + b[index]; }
};

ParameterBlock<Processor> processor;

[shader("compute")]
[numthreads(32, 1, 1)]
void main(uint3 tid: SV_DispatchThreadID)
{
    uint index = tid.x;
    uint waveSum = WaveActiveSum(index);

    if (index < 1024)
        processor.c[index] = waveSum;
        // processor.process(index);
}