# Wasmtime Julia Binding Generator

Generates Julia bindings from Wasmtime C API headers using Clang.jl.

## Quick Start

```bash
julia gen/build_artifacts.jl  # Download Wasmtime binaries (first time)
julia gen/generator.jl        # Generate bindings
```

Creates `src/LibWasmtime.jl` with complete C API bindings.

## Files

- `generator.jl` - Main entry point
- `generator_functions.jl` - Core generation logic
- `build_artifacts.jl` - Downloads Wasmtime binaries
- `generator.toml` - Configuration settings
- `prologue.jl` / `epilogue.jl` - Custom code patches

## Configuration

Edit `generator.toml` to control symbol exports, type generation, and macro processing.

Add custom code to `prologue.jl` or `epilogue.jl` for manual patches.

## Environment Variables

- `GITHUB_AUTH` - GitHub token (avoids rate limits)
- `WASMTIME_RELEASE_VERSION` - Specific version (optional)

## Troubleshooting

**"Artifacts.toml not found"** → Run `julia gen/build_artifacts.jl`

**"Include directory not found"** → Check artifact integrity and platform support

**"Clang compilation failed"** → Verify Clang installation and architecture detection

Enable debug logging: Check `generator_debug.log` for detailed trace information.

## References

- [Wasmtime Documentation](https://docs.wasmtime.dev/)
- [Clang.jl Documentation](https://github.com/JuliaInterop/Clang.jl)
