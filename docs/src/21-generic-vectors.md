# Generic Vector Wrapper (`WasmVec`)

The `WasmVec{T,S}` type provides a unified, Julia-idiomatic interface for all Wasmtime vector types (`wasm_XXX_vec_t`). It implements the `AbstractVector` interface, allowing seamless integration with Julia's ecosystem while maintaining automatic memory management.

## Overview

Wasmtime defines numerous vector types such as:

- `wasm_extern_vec_t` - for collections of externals
- `wasm_importtype_vec_t` - for import type collections
- `wasm_exporttype_vec_t` - for export type collections
- `wasm_valtype_vec_t` - for value type collections
- `wasm_val_vec_t` - for value collections
- `wasm_byte_vec_t` - for byte/string data
- And many more...

Instead of handling each type manually, `WasmVec` provides a generic wrapper that works with all of them.

## Type Parameters

- `T`: The underlying C vector type (e.g., `wasm_extern_vec_t`)
- `S`: The element type (e.g., `Ptr{wasm_extern_t}` or `UInt8`)

## Basic Usage

### Creating Vectors

```julia
# From Julia vectors (automatic type detection)
bytes = UInt8[0x48, 0x65, 0x6c, 0x6c, 0x6f]  # "Hello"
vec = WasmVec(bytes)

# Explicit type specification
using Wasmtime.LibWasmtime: wasm_byte_vec_t
vec = WasmVec{wasm_byte_vec_t, UInt8}(bytes)

# Using type aliases
vec = WasmByteVec(bytes)

# Empty vectors
empty_vec = WasmVec(UInt8)
```

### AbstractVector Interface

```julia
vec = WasmVec(UInt8[1, 2, 3, 4, 5])

# Length and size
length(vec)  # 5
size(vec)    # (5,)
isempty(vec) # false

# Indexing
vec[1]       # 0x01
vec[end]     # 0x05
vec[2:4]     # [0x02, 0x03, 0x04]

# Assignment
vec[1] = 10  # vec is now [10, 2, 3, 4, 5]

# Iteration
for x in vec
    println(x)
end

# Bounds checking is automatic
vec[10]  # BoundsError
```

### Conversion

```julia
# Convert back to Julia vector
julia_vec = to_julia_vector(wasm_vec)
# or
julia_vec = collect(wasm_vec)

# Copy a WasmVec
copied = copy(wasm_vec)
```

## Type Aliases

For convenience, several type aliases are provided:

```julia
# Byte vectors (for strings and binary data)
const WasmByteVec = WasmVec{wasm_byte_vec_t, UInt8}
const WasmName = WasmByteVec

# Common vector types
const WasmExternVec = WasmVec{wasm_extern_vec_t, Ptr{wasm_extern_t}}
const WasmImportTypeVec = WasmVec{wasm_importtype_vec_t, Ptr{wasm_importtype_t}}
const WasmExportTypeVec = WasmVec{wasm_exporttype_vec_t, Ptr{wasm_exporttype_t}}
const WasmValtypeVec = WasmVec{wasm_valtype_vec_t, Ptr{wasm_valtype_t}}
const WasmValVec = WasmVec{wasm_val_vec_t, wasm_val_t}
const WasmTableTypeVec = WasmVec{wasm_tabletype_vec_t, Ptr{wasm_tabletype_t}}
const WasmExternTypeVec = WasmVec{wasm_externtype_vec_t, Ptr{wasm_externtype_t}}
const WasmFrameVec = WasmVec{wasm_frame_vec_t, Ptr{wasm_frame_t}}
```

## Memory Management

`WasmVec` handles memory management automatically:

- Memory is allocated when creating the vector
- A finalizer is set up to call the appropriate `wasm_XXX_vec_delete` function
- Memory is automatically freed when the vector goes out of scope
- No manual cleanup required.

```julia
function create_vector()
    vec = WasmVec(UInt8[1, 2, 3, 4, 5])
    return length(vec)
end  # vec automatically cleaned up here

len = create_vector()  # Memory is properly managed
```

## C Interoperability

For interfacing with C functions, `WasmVec` provides unsafe conversion methods:

```julia
vec = WasmVec(UInt8[1, 2, 3])

# Convert to pointer to the C struct
struct_ptr = Base.unsafe_convert(Ptr{wasm_byte_vec_t}, vec)

# Convert to pointer to the data
data_ptr = Base.unsafe_convert(Ptr{UInt8}, vec)

# Use with C functions
some_c_function(struct_ptr)
```

## Working with Pointers

For vectors that contain pointers (most Wasmtime types), use `WasmPtrVec`:

```julia
# Create vector of pointers
ptrs = [ptr1, ptr2, ptr3]  # Ptr{wasm_extern_t}
extern_vec = WasmPtrVec(ptrs)

# Or use type-specific aliases
extern_vec = WasmExternVec(ptrs)
```

## Type Safety

The wrapper provides compile-time type safety:

```julia
vec = WasmVec(UInt8[1, 2, 3])

# This will cause a compile error
vec[1] = "wrong type"  # MethodError

# Element types must match
vec[1] = UInt8(42)  # ✓ Correct
```

Assignment and indexing operations ensure that the types are consistent with the underlying C vector type, preventing runtime errors.
Meaning,

```julia
# Element types must match
vec[1] = UInt8(42)  # ✓ Correct

vec[1] = Int32(42)  # ✓ Correct but will convert to UInt8

# This will cause a compile error
vec[1] = "wrong type"  # MethodError
```

## Examples

### String Handling

```julia
# Create a string as bytes
hello = "Hello, World!"
bytes = Vector{UInt8}(hello)
name_vec = WasmName(bytes)

# Use in Wasmtime functions
# module_name = wasmtime_module_name(module, name_vec)

# Convert back to string
result_string = String(collect(name_vec))
```
