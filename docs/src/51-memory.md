# WebAssembly Memory

WebAssembly linear memory is a contiguous, mutable array of raw bytes that serves as the heap for WebAssembly modules. This chapter covers working with memory in WasmtimeRuntime.jl.

## Overview

WebAssembly memory is organized into 64KB pages and can be dynamically resized during execution. The WasmtimeRuntime.jl library provides two main types for working with memory:

- **`WasmMemoryType`**: Defines memory characteristics and constraints
- **`WasmMemory`**: An actual memory instance within a store

## Memory Types

### WasmMemoryType

A `WasmMemoryType` specifies the properties of a WebAssembly memory:

```julia
# Create memory type with 1 initial page, up to 10 pages maximum
memory_type = WasmMemoryType(1 => 10)

# Create memory type with 5 initial pages, unlimited growth
memory_type = WasmMemoryType(5 => 0)

# Default: no initial pages, unlimited growth
memory_type = WasmMemoryType()
```

### Memory Limits

Memory limits are specified as page counts where each page is exactly 64KB (65,536 bytes):

- **Minimum pages**: Initial memory size
- **Maximum pages**: Growth limit (0 means unlimited)

```julia
# 64KB initial, up to 1MB maximum
memory_type = WasmMemoryType(1 => 16)

# 320KB initial, unlimited growth
memory_type = WasmMemoryType(5 => 0)
```

## Memory Instances

### Creating Memory

Memory instances are created within a store:

```julia
engine = WasmEngine()
store = WasmStore(engine)

# Create memory with specific limits
memory = WasmMemory(store, 2 => 100)

# Create default memory
memory = WasmMemory(store)
```

### Memory Properties

```julia
# Check if memory is valid
isvalid(memory)  # returns Bool

# Get string representation
string(memory)  # "WasmMemory()"
```
