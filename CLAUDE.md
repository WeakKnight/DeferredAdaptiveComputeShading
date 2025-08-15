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
⬜⬛⬜⬛<br/>
⬛🟩⬛🟩<br/>
⬜⬛⬜⬛<br/>
⬛🟩⬛🟩<br/>
Dispatch Dimension: (Screen Width / 4) * (Screen Height / 4) * 4

Interpolate between neighbors if (i + 1, j + 1), (i - 1, j - 1), (i + 1, j - 1), (i - 1, j + 1) are similar.

#### Pass 4
⬜🟩⬜🟩<br/>
🟩⬜🟩⬜<br/>
⬜🟩⬜🟩<br/>
🟩⬜🟩⬜<br/>
Dispatch Dimension: (Screen Width / 4) * (Screen Height / 4) * 8

Interpolate between neighbors if (i + 1, j), (i - 1, j), (i, j - 1), (i, j + 1) are similar.

### Pixel Smilarity Definition

Given 4 pixels, they are similar if the variance is higher than threshold.