# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Algorithm Overview
⬜: shading pixel
🟩: shaded pixel
⬛: unshaded pixel

### Workflow

#### Pass 1
⬜⬛⬛⬛<br/>
⬛⬛⬛⬛<br/>
⬛⬛⬛⬛<br/>
⬛⬛⬛⬛<br/>

#### Pass 2
🟩⬛⬛⬛<br/>
⬛⬛⬛⬛<br/>
⬛⬛⬜⬛<br/>
⬛⬛⬛⬛<br/>
interpolate between neighbors if (i + 2, j + 2), (i - 2, j + 2), (i + 2, j - 2), (i - 2, j - 2) are similar.

#### Pass 3
🟩⬛⬜⬛<br/>
⬛⬛⬛⬛<br/>
⬜⬛🟩⬛<br/>
⬛⬛⬛⬛<br/>
interpolate between neighbors if (i + 2, j), (i - 2, j), (i, j - 2), (i, j + 2) are similar.

#### Pass 4
⬜⬛⬜⬛<br/>
⬛🟩⬛🟩<br/>
⬜⬛⬜⬛<br/>
⬛🟩⬛🟩<br/>
interpolate between neighbors if (i + 1, j + 1), (i - 1, j - 1), (i + 1, j - 1), (i - 1, j + 1) are similar.

#### Pass 5
⬜🟩⬜🟩<br/>
🟩⬜🟩⬜<br/>
⬜🟩⬜🟩<br/>
🟩⬜🟩⬜<br/>
interpolate between neighbors if (i + 1, j), (i - 1, j), (i, j - 1), (i, j + 1) are similar.

### Pixel Smilarity Definition

Given 4 pixels, they are similar if the variance is higher than threshold. 