# Values and Type System

WasmtimeRuntime.jl provides a comprehensive type system for WebAssembly values with current implementations and planned future features.

## WebAssembly Value Types

### Basic Value Types (✅ Implemented)

WebAssembly defines WasmValue to wrap fundamental value types:

```julia
# 32-bit integer
val_i32 = WasmValue(42)

# 64-bit integer
val_i64 = WasmValue(42)

# 32-bit floating point
val_f32 = WasmValue(3.14f0)

# 64-bit floating point
val_f64 = WasmValue(3.14159)
```

### Reference Types (✅ Implemented)

```julia
# Function reference (can be null)
func_ref = WasmFuncRef(nothing)        # Null function reference
func_ref = WasmFuncRef(some_function)  # Valid function reference

# External reference (any Julia object)
extern_ref = WasmExternRef("hello")    # String reference
extern_ref = WasmExternRef([1, 2, 3])  # Array reference
extern_ref = WasmExternRef(nothing)    # Null reference
```

### SIMD Types (🚧 Under Development)

```julia
# 128-bit vector (16 bytes)
simd_val = WasmValue((0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                     0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10))
```

## Type Conversion System

### Current Implementation (🚧 Under Development)

Type checking functionality is currently available:

```julia
# Type validation (implemented)
is_wasm_convertible(Int32)     # true
is_wasm_convertible(Int64)     # true
is_wasm_convertible(Float32)   # true
is_wasm_convertible(Float64)   # true
is_wasm_convertible(String)    # false (use ExternRef)
is_wasm_convertible(Vector)    # false (use ExternRef)
```

### Future API (🚧 Under Development)

The following conversion functions are planned:

```julia

# WebAssembly → Julia
# julia_val = from_wasm(WasmValue(42))   # Returns 42::Int32
# julia_val = from_wasm(WasmValue(3.14)) # Returns 3.14::Float64
```

## Working with Values

### Creating Values

```julia
# Direct construction from Julia values
val = WasmValue(100)
```
