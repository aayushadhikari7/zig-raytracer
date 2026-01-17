# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it by opening a GitHub issue or contacting the maintainer directly.

Since this is a local GPU raytracer application that does not involve network communication or sensitive data processing, the attack surface is minimal. However, we take all security concerns seriously.

## Security Considerations

### GPU Resource Usage
This application performs intensive GPU computations. Maliciously crafted scene files or OBJ models could potentially:
- Cause GPU memory exhaustion
- Trigger driver crashes
- Lead to system instability

### File Loading
The OBJ loader parses external files. Only load models from trusted sources.

## Best Practices
- Monitor GPU temperatures when running at high resolutions
- Use the quality presets (1-4) to manage GPU load
- Close other GPU-intensive applications when running the raytracer
