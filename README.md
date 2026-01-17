# Zig GPU Raytracer

A real-time GPU path tracer built in Zig using OpenGL 4.3 compute shaders.

## Features

### Rendering
- Real-time path tracing with progressive accumulation
- BVH acceleration for spheres, triangles, and mesh instances
- Constructive Solid Geometry (CSG) with ray marching
- OBJ model loading with per-mesh BVH

### Materials
- Diffuse (Lambertian)
- Metal with configurable roughness
- Glass/Dielectric with refraction
- Emissive lights
- Subsurface scattering (SSS)

### Lighting
- HDR sky with physically-based atmospheric scattering
- Direct sun lighting with shadows
- Area lights
- Next Event Estimation (NEE) for faster convergence

### Post-Processing
- ACES filmic tone mapping
- Chromatic aberration
- Motion blur
- Bloom
- Vignette
- Depth of field
- Lens flares
- Denoising (spatial + variance-guided)
- CRT scanlines
- Fisheye distortion
- Heat haze
- Film grain

## Controls

### Camera
- `WASD` - Move camera
- `Space/Ctrl` - Up/Down
- `Right-click` - Toggle mouse look
- `P` - Toggle flight mode
- `Q/E` - Roll (flight mode only)

### Effects
- `Shift+Key` - Decrease effect
- `C` - Chromatic aberration
- `M` - Motion blur
- `B` - Bloom
- `E` - Exposure
- `V` - Vignette

### Debug
- `5` - Normal view
- `6` - BVH heatmap
- `7` - Normals visualization
- `8` - Depth visualization

### Other
- `TAB` - Toggle HUD
- `R` - Reset all settings
- `F12` - Screenshot
- `1-4` - Quality presets

## Building

Requires Zig 0.15+ and OpenGL 4.3 capable GPU.

```bash
zig build -Doptimize=ReleaseFast
```

## Running

```bash
zig-out/bin/zig-raytracer.exe
```

Or place OBJ models in `models/` folder and run from the project directory.

## Project Structure

```
zig-raytracer/
├── src/
│   ├── main.zig       # Window, input, render loop
│   ├── shader.zig     # GLSL compute shader (embedded)
│   ├── types.zig      # GPU structs, mesh instances
│   ├── bvh.zig        # BVH construction
│   ├── hud.zig        # On-screen controls overlay
│   └── effects.zig    # Effect parameters
├── models/            # OBJ files
├── build.zig          # Build configuration
└── README.md
```

## Performance

Optimized for real-time rendering on modern GPUs:
- Per-mesh BVH for instanced geometry
- Simplified trace path for interactive framerates
- Russian roulette path termination
- Adaptive denoising

Tested on RTX 3090 at 1920x1080.
