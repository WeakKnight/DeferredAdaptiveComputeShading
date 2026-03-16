# AGENTS.md

## Adaptive Shading Algorithm Overview

This project implements a **deferred adaptive compute shading** pipeline. The core idea is to avoid redundant per-pixel shading work: instead of shading every pixel independently, we shade a sparse subset first, then decide for each remaining pixel whether it actually needs full shading or can be cheaply interpolated from its already-computed neighbors.

### Pipeline Structure

The rendering pipeline has two stages:

1. **GBuffer Pass** — Rasterizes the scene (a procedural terrain from Shadertoy/Elevated) into a G-Buffer storing world position, normal, diffuse albedo, specular, and view direction.
2. **Adaptive Lighting Pass** — A 5-pass compute shader sequence that progressively fills in all pixels of a 4×4 block, making shade-or-interpolate decisions at each level.

### Hierarchical 4×4 Block Decomposition

The screen is divided into 4×4 pixel blocks. The 16 pixels per block are filled across 5 passes in a hierarchical pattern, where each pass doubles the pixel count and every new pixel has 4 already-computed neighbors:

```
Pass 0 (1 pixel/block):   shade (0,0)                                  — unconditional
Pass 1 (1 pixel/block):   process (2,2)                                — neighbors are 4 corner (0,0)s from adjacent blocks
Pass 2 (2 pixels/block):  process (0,2), (2,0)                         — axis-aligned midpoints
Pass 3 (4 pixels/block):  process (1,1), (1,3), (3,1), (3,3)          — diagonal midpoints
Pass 4 (8 pixels/block):  process (0,1),(1,0),(1,2),(2,1),(2,3),(3,2),(0,3),(3,0) — remaining pixels
```

Pixel fill pattern within a 4×4 block (number = pass index):

```
0  4  2  4
4  3  4  3
2  4  1  4
4  3  4  3
```

### Shade-or-Interpolate Decision

For each non-pass0 pixel, the algorithm reads 4 already-shaded neighbor colors and computes luminance variance:

1. Convert each neighbor's RGB to a luminance-like scalar: `Y = 0.25·R + 0.5·G + 0.25·B`
2. Compute the variance of the 4 Y values: `Var = mean(Y²) − mean(Y)²`
3. If `Var >= 1e-3` → **shade** (execute full lighting evaluation)
4. If `Var < 1e-3` → **interpolate** (average the 4 neighbor colors)

### Theoretical Shading Reduction

- Pass 0 always shades 1/16 of all pixels.
- Passes 1–4 shade only where variance exceeds the threshold; remaining pixels are interpolated.
- In the best case (perfectly smooth image), only 1/16 (6.25%) of pixels are fully shaded.
- In the worst case (all high-frequency), every pixel is shaded — equivalent to brute-force.
- Typical scenes achieve significant savings in smooth sky/ground regions.

### Wave Optimization — DistributeWork

Passes 1–4 use a **DistributeWork** producer-consumer pattern (from Brian Karis — [Variable sized work](https://graphicrants.blogspot.com/2026/03/variable-sized-work.html)) with groupshared memory and wave intrinsics to improve SIMD occupancy:

1. **Producer phase** — Each lane evaluates its pixels, determines which need shading (storing a bitmask), and interpolates the rest immediately.
2. **DistributeWork** — Uses `WavePrefixSum` to build a compact queue of all shade-work items across the wave, then distributes them evenly across all lanes via groupshared `WorkBatch`. Producer data (block base + shade mask) is communicated via groupshared arrays `gProducerBase`/`gProducerMask`.
3. **Consumer phase** (`RunChild`) — Each lane shades its assigned pixel by reading the source lane's data from groupshared memory and selecting the correct sub-pixel via `NthSetBit`.

Pass 1 and Pass 2 use a **2×2 super-block mapping** (8×8 pixel region per lane) to increase pixels-per-lane to 4 and 8 respectively, making DistributeWork effective for these low-density passes.
