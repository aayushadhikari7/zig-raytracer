# Zig GPU Raytracer

A real-time GPU path tracer built in Zig using OpenGL 4.3 compute shaders.

![Raytracer Output](output.png)

> **Warning**
> This application performs intensive GPU computations. Running at high resolutions or with many effects enabled can cause significant GPU load, high temperatures, and potential system instability. Monitor your GPU temperatures and use quality presets (keys 1-4) to manage performance. **Use at your own risk.**

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
- Direct sun lighting
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
| Key | Action |
|-----|--------|
| `WASD` | Move camera |
| `Space/Ctrl` | Up/Down |
| `Right-click` | Toggle mouse look |
| `P` | Toggle flight mode |
| `Q/E` | Roll (flight mode) |

### Effects
| Key | Effect |
|-----|--------|
| `Shift+Key` | Decrease effect |
| `C` | Chromatic aberration |
| `M` | Motion blur |
| `B` | Bloom |
| `E` | Exposure |
| `V` | Vignette |

### Debug & Quality
| Key | Action |
|-----|--------|
| `1-4` | Quality presets |
| `5` | Normal view |
| `6` | BVH heatmap |
| `7` | Normals visualization |
| `8` | Depth visualization |
| `TAB` | Toggle HUD |
| `R` | Reset all settings |
| `F12` | Screenshot |

## Requirements

- **Zig**: 0.15 or later
- **GPU**: OpenGL 4.3 compatible (NVIDIA GTX 600+, AMD GCN+, Intel HD 5000+)
- **OS**: Windows (native Win32)

## Building

```bash
zig build -Doptimize=ReleaseFast
```

## Running

```bash
zig-out/bin/zig-raytracer.exe
```

Place OBJ models in the `models/` folder and run from the project directory.

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
├── LICENSE            # MIT License
├── SECURITY.md        # Security policy
└── README.md
```

## Performance Tips

- Use quality presets `1-4` to balance quality vs FPS
- Lower resolution for better framerates
- Disable expensive effects (chromatic aberration, motion blur)
- Monitor GPU temperature during extended use

Tested on RTX 3090 at 1920x1080.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
