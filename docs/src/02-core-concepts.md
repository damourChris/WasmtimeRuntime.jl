# Core Concepts

This guide introduces the fundamental concepts and architecture of WasmtimeRuntime.jl.

## WebAssembly Runtime Architecture

WasmtimeRuntime.jl follows the WebAssembly specification's runtime architecture:

```tree
Engine → Store → Module → Instance → Functions/Memory/Globals/Tables
   ↓        ↓        ↓         ↓              ↓
Config   Context   WASM    Runtime      WebAssembly
                  Bytes    Objects       Execution
```

## Core Components

### Engine

The `WasmEngine` is the compilation environment responsible for compiling WebAssembly modules. It's configured once and can be shared across multiple stores.

```julia
# Default engine
engine = WasmEngine()

# Configured engine
config = WasmConfig(optimization_level = Speed, debug_info = true)
engine = WasmEngine(config)
```

### Store

The `WasmStore` represents an isolated runtime context. Each store has its own:

- Memory instances
- Global variables
- Function instances
- Tables

```julia
store = WasmStore(engine)
```

### Module

A `WasmModule` represents compiled WebAssembly code. Modules are immutable and can be instantiated multiple times.

```julia
# From WAT (✅ Working)
wat_content = """
(module
  (func $test (result i32)
    i32.const 42))
"""
wasm_bytes = wat2wasm(wat_content)
module_obj = WasmModule(engine, wasm_bytes)

# From file bytes
wasm_bytes = read("module.wasm")
module_obj = WasmModule(engine, wasm_bytes)
```

### Instance

A `WasmInstance` is a runtime instantiation of a module within a store. Each instance has its own:

- Memory state
- Global values
- Function closures

```julia
instance = WasmInstance(store, module_obj)
```

## Type System

WasmtimeRuntime.jl provides a type-safe interface to WebAssembly's value types:

### Type Conversion

```julia
# Value creation (implemented)
val_i32 = WasmValue(42)
val_f64 = WasmValue(3.14159)
```

## Resource Management

WasmtimeRuntime.jl uses Julia's garbage collection and finalizers for automatic resource cleanup:

- **Engines**: Cleaned up when GC'd
- **Stores**: Cleaned up when GC'd
- **Modules**: Cleaned up when GC'd
- **Instances**: Tied to store lifetime

```julia
# Resources are automatically cleaned up
let
    engine = WasmEngine()
    store = WasmStore(engine)
    # ... use resources
end  # Resources cleaned up here
```

## Abstract Type Hierarchy

```tree
WasmtimeObject
├── WasmtimeResource
│   ├── AbstractEngine
│   ├── AbstractStore
│   ├── AbstractModule
│   ├── AbstractInstance
│   ├── AbstractFunc
│   ├── AbstractMemory
│   ├── AbstractGlobal
│   └── AbstractTable
├── WasmtimeValue
│   └── WasmValue{T}
├── WasmtimeType
└── AbstractConfig
```

This hierarchy ensures type safety and enables multiple dispatch for WebAssembly operations.

## Thread Safety

**Current Implementation Status:**

- **Engines**: Thread-safe, can be shared across threads ✅
- **Stores**: Not thread-safe, use one per thread ✅
- **Modules**: Thread-safe after compilation ✅
- **Instances**: Tied to store, not thread-safe ✅

**Note:** Thread safety characteristics are based on the underlying Wasmtime library implementation.

## Error Handling

All operations that can fail throw `WasmtimeError` with descriptive messages:

```julia
try
    module_obj = WasmModule(engine, invalid_bytes)
catch e::WasmtimeError
    println("Failed to create module: $(e.message)")
end
```

See [Error Handling](70-error-handling.md) for comprehensive error handling patterns.
