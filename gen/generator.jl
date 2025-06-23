"""
    WasmtimeRuntime.jl Generator

Main entry point for generating Julia bindings from Wasmtime C API headers.

# Usage

```bash
julia gen/generator.jl              # Generate bindings
```

```julia
include("generator.jl")             # Include without running
```

Generates `../src/LibWasmtime.jl` from C headers using Clang.jl.
"""

include("generator_functions.jl")

# Run generation when executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_generation()
end
