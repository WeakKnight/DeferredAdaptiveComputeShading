# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Algorithm Overview
⬜: shading pixel
🟩: shaded pixel
⬛: unshaded pixel

### Workflow

#### Pass 0
⬜⬛⬛⬛<br/>
⬛⬛⬛⬛<br/>
⬛⬛⬛⬛<br/>
⬛⬛⬛⬛<br/>
Dispatch Dimension: (Screen Width / 4) * (Screen Height / 4) * 1

Access Pattern: 
1. Compute Block Idx <br/>
2. Apply Pixel Offset <br/>
3. Shade Target Pixel

#### Pass 1
🟩⬛⬛⬛<br/>
⬛⬛⬛⬛<br/>
⬛⬛⬜⬛<br/>
⬛⬛⬛⬛<br/>
Dispatch Dimension: (Screen Width / 4) * (Screen Height / 4) * 1

Access Pattern: 
1. Compute Block Idx <br/>
2. Apply Pixel Offset <br/>
3. Derive Statistics Property <br/>
3. Interpolate Or Shade Target Pixel

Interpolate between neighbors if (i + 2, j + 2), (i - 2, j + 2), (i + 2, j - 2), (i - 2, j - 2) are similar.

#### Pass 2
🟩⬛⬜⬛<br/>
⬛⬛⬛⬛<br/>
⬜⬛🟩⬛<br/>
⬛⬛⬛⬛<br/>
Dispatch Dimension: (Screen Width / 4) * (Screen Height / 4) * 2

Interpolate between neighbors if (i + 2, j), (i - 2, j), (i, j - 2), (i, j + 2) are similar.

#### Pass 3
🟩⬛🟩⬛<br/>
⬛⬜⬛⬜<br/>
🟩⬛🟩⬛<br/>
⬛⬜⬛⬜<br/>
Dispatch Dimension: (Screen Width / 4) * (Screen Height / 4) * 4

Interpolate between neighbors if (i + 1, j + 1), (i - 1, j - 1), (i + 1, j - 1), (i - 1, j + 1) are similar.

#### Pass 4
🟩⬜🟩⬜<br/>
⬜🟩⬜🟩<br/>
🟩⬜🟩⬜<br/>
⬜🟩⬜🟩<br/>
Dispatch Dimension: (Screen Width / 4) * (Screen Height / 4) * 8

Interpolate between neighbors if (i + 1, j), (i - 1, j), (i, j - 1), (i, j + 1) are similar.

### Pixel Smilarity Definition

Given 4 pixels, they are similar if the variance is higher than threshold.

### Wave Sorting
⬜: shading
🟩: interpolation

Assume Warp Size = 16

⬜⬜⬜⬜<br/>
⬜🟩⬜🟩<br/>
🟩⬜|⬜|⬜<br/>
⬜⬜⬜⬜<br/>

Total Shading Count WaveActiveCountBits(shading) = 13,

Given thread 10, srcLaneIdx = 10, WavePrefixCountBits(shading) = 7 (not including self),

interpolation before thread 10 is srcLaneIdx - WavePrefixCountBits(shading) = 3

dstLaneIdx = srcLaneIdx is shading? WavePrefixCountBits(shading) = 7: (WaveActiveCountBits(shading) + (srcLaneIdx - WavePrefixCountBits(shading)) = 16) = 7

Finally,
srcLaneIdx = 10, dstLaneIdx = 7

> srcLaneIdx = 0, WavePrefixCountBits(shading) = 0, dstLaneIdx = 0 <br/>
> srcLaneIdx = 1, WavePrefixCountBits(shading) = 1, dstLaneIdx = 1 <br/>
> srcLaneIdx = 2, WavePrefixCountBits(shading) = 2, dstLaneIdx = 2 <br/>
> srcLaneIdx = 3, WavePrefixCountBits(shading) = 3, dstLaneIdx = 3 <br/>

> srcLaneIdx = 4, WavePrefixCountBits(shading) = 4, dstLaneIdx = 4 <br/>
> srcLaneIdx = 5, WavePrefixCountBits(shading) = 5, dstLaneIdx = 13 <br/>
> srcLaneIdx = 6, WavePrefixCountBits(shading) = 5, dstLaneIdx = 5 <br/>
> srcLaneIdx = 7, WavePrefixCountBits(shading) = 6, dstLaneIdx = 14 <br/>

> srcLaneIdx = 8, WavePrefixCountBits(shading) = 6, dstLaneIdx = 15 <br/>
> srcLaneIdx = 9, WavePrefixCountBits(shading) = 6, dstLaneIdx = 6 <br/>
> srcLaneIdx = 10, WavePrefixCountBits(shading) = 7, dstLaneIdx = 7 <br/>
> srcLaneIdx = 11, WavePrefixCountBits(shading) = 8, dstLaneIdx = 8 <br/>

> srcLaneIdx = 12, WavePrefixCountBits(shading) = 9, dstLaneIdx = 9 <br/>
> srcLaneIdx = 13, WavePrefixCountBits(shading) = 10, dstLaneIdx = 10 <br/>
> srcLaneIdx = 14, WavePrefixCountBits(shading) = 11, dstLaneIdx = 11 <br/>
> srcLaneIdx = 15, WavePrefixCountBits(shading) = 12, dstLaneIdx = 12 <br/>

### Multi Wave Sorting

⬜: shading
🟩: interpolation

Assume Warp Size = 16

#### Wave 0
⬜⬜⬜⬜<br/>
⬜🟩⬜🟩<br/>
🟩⬜⬜⬜<br/>
⬜⬜⬜⬜<br/>

#### Wave 1
⬜🟩🟩🟩<br/>
⬜🟩⬜🟩<br/>
🟩⬜🟩⬜<br/>
🟩⬜🟩🟩<br/>