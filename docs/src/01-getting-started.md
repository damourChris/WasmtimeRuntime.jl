# Getting Started with WasmtimeRuntime.jl

This guide will help you get started with WasmtimeRuntime.jl, a Julia wrapper for the Wasmtime WebAssembly runtime engine.

## Installation

Add WasmtimeRuntime.jl to your Julia environment:

```julia
using Pkg
Pkg.add("WasmtimeRuntime")
```

## Basic Usage

### 1. Setting Up the Runtime

First, create the core runtime components:

```julia
using WasmtimeRuntime

# Create engine with default configuration
engine = WasmEngine()

# Create store for runtime state
store = WasmStore(engine)
```

### 2. WAT to WASM Compilation (✅ Working Feature)

Convert WebAssembly Text format to binary format:

```julia
wat_content = """
(module
  (func $add (param $x i32) (param $y i32) (result i32)
    local.get $x
    local.get $y
    i32.add)
  (export "add" (func $add)))
"""

# Convert WAT to WASM bytes
wasm_bytes = wat2wasm(wat_content)

# Create module from bytes
module_obj = WasmModule(engine, wasm_bytes)

# Instantiate the module
instance = WasmInstance(store, module_obj)
```

### 3. Working with Values and Types (✅ Working Feature)

Create and validate WebAssembly values:

```julia
# Value creation (implemented)
val_i32 = WasmValue(42)
val_f64 = WasmValue(3.14159)

# Type validation (working)
is_wasm_convertible(Int32)  # true
is_wasm_convertible(String) # false
```

### 4. Function Calling (🚧 Under Development)

**⚠️ Note:** Function calling functionality is currently under active development and not yet available.

## Configuration Options

Customize the Wasmtime engine with configuration options:

```julia
# Create custom configuration
config = WasmConfig(
    debug_info = true,
    optimization_level = Speed,
    profiling_strategy = NoProfilingStrategy
)

# Enable specific features
consume_fuel!(config, true)
max_wasm_stack!(config, 1024 * 1024)  # 1MB stack

# Create engine with custom config
engine = WasmEngine(config)
```

## Error Handling

WasmtimeRuntime.jl uses Julia's exception system:

```julia
try
    # Example with actual working functionality
    wasm_bytes = wat2wasm("invalid wat syntax")
catch e
    if isa(e, WasmtimeError)
        println("WebAssembly error: $(e.message)")
    else
        rethrow(e)
    end
end
```

## Memory Management

Resources are automatically managed through Julia's garbage collector:

```julia
# Resources are automatically cleaned up when objects go out of scope
function process_wasm()
    engine = WasmEngine()
    store = WasmStore(engine)
    # ... work with WebAssembly
    # Automatic cleanup when function exits
end
```

## Next Steps

<!-- - Read the [API Reference](@ref) for detailed function documentation
- Explore [Generic Vectors](@ref) for working with WebAssembly collections
- Check out [Testing Best Practices](@ref) if you're developing with WebAssembly
- See the [Developer Documentation](@ref dev_docs) for contributing to the project -->

## Example: Complete Workflow

Here's a complete example using currently implemented features:

```julia
using WasmtimeRuntime

# Setup
engine = WasmEngine()
store = WasmStore(engine)

# WAT to WASM conversion (working feature)
wat_content = """
(module
  (func $multiply (param $x i32) (param $y i32) (result i32)
    local.get $x
    local.get $y
    i32.mul)
  (export "multiply" (func $multiply)))
"""

# Convert and load module
wasm_bytes = wat2wasm(wat_content)
module_obj = WasmModule(engine, wasm_bytes)
instance = WasmInstance(store, module_obj)

# Work with values
val1 = WasmValue(6)
val2 = WasmValue(7)
println("Created values: $val1, $val2")

# Module introspection (currently returns placeholder data)
exports_info = exports(module_obj)
println("Module exports: $exports_info")
```

**⚠️ Note:** This example demonstrates currently working features. Function calling will be added in a future release.
