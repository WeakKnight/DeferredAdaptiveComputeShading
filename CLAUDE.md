# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a deferred adaptive compute shading research project that implements an adaptive multi-pass lighting algorithm using Slang compute shaders. The project demonstrates an optimization technique that selectively shades pixels based on similarity analysis, potentially reducing shading workload by using interpolation for similar neighboring pixels.

## Development Commands

### Running the Application
```bash
python EntryPoint.py
```
This will execute the complete rendering pipeline and output `Result.png`.

### Dependencies
- slangpy (Slang Python bindings)
- numpy
- imageio
- pathlib

## Architecture Overview

### Core Components

**EntryPoint.py**: Main application entry point that orchestrates the entire rendering pipeline using slangpy to interface with Slang compute shaders.

**Rendering Pipeline**:
1. **GBuffer Pass** (`GBufferPass.slang`): Generates geometry buffer containing position, normal, diffuse, and specular data
2. **Lighting Pass Options**:
   - **Coherent Lighting** (`LightingPass.slang`): Traditional per-pixel shading
   - **Adaptive Lighting** (`AdaptiveLightingPass.slang`): Multi-pass adaptive algorithm with 5 passes (pass0-pass4)

### Shader Architecture

**AdaptiveLightingPass.slang**: Core adaptive algorithm implementation with multiple entry points:
- `pass0`: Initial sparse shading (4x4 blocks, shades 1 pixel per block)
- `pass1-pass4`: Progressive refinement passes that either shade or interpolate pixels based on similarity analysis
- Uses wave intrinsics for GPU warp optimization and pixel sorting

**Key Modules**:
- `Shading.slang`: Contains the main shading function that computes lighting
- `GBuffer.slang`: Defines the GBuffer structure for deferred rendering data
- `Shadertoy.slang`, `Elevated.slang`: Scene generation and geometry functions

### Adaptive Algorithm Details

The algorithm works by:
1. Dividing screen into 4x4 pixel blocks
2. Initially shading only one pixel per block (pass0)
3. In subsequent passes, analyzing pixel similarity using variance-based metrics
4. Either shading new pixels or interpolating from already-shaded neighbors
5. Using GPU wave intrinsics to optimize thread divergence during shade/interpolate decisions

**Similarity Analysis**: Uses luminance variance calculation with threshold of `1e-3f` to determine if pixels should be shaded or interpolated.

**Wave Optimization**: Implements wave partitioning to group threads performing similar operations (shading vs interpolation) for better GPU utilization.

## File Structure

```
├── EntryPoint.py          # Main application and pipeline orchestration
├── AdaptiveLightingPass.slang  # Multi-pass adaptive lighting algorithm
├── GBufferPass.slang      # Geometry buffer generation
├── LightingPass.slang     # Traditional coherent lighting
├── Shading.slang          # Core shading calculations
├── GBuffer.slang          # GBuffer data structure
├── Shadertoy.slang        # Scene rendering functions
├── Elevated.slang         # Terrain/elevation functions
├── BlueNoise.png          # Blue noise texture for sampling
└── README.md              # Algorithm documentation and theory
```

## Key Configuration

- Screen resolution: 1920x1080 (configurable in EntryPoint.py:38-39)
- Adaptive mode toggle: EntryPoint.py:118 (set to `False` for coherent, `True` for adaptive)
- Variance threshold: AdaptiveLightingPass.slang:41 (controls interpolation sensitivity)

## Development Notes

When modifying the adaptive algorithm, key areas to consider:
- Pass dispatch dimensions and thread group sizes (8x8x1 compute shader configuration)
- Pixel similarity thresholds and variance calculations
- Wave intrinsic usage for GPU optimization
- Buffer and texture binding between Python and Slang code