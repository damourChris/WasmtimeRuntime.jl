# WebAssembly Externs

WebAssembly externs provide a unified interface for handling functions, globals, tables, and memories as generic external objects. This is essential for import/export operations and module instantiation.

## Overview

The `WasmExtern` wrapper converts specific WebAssembly objects into the generic `wasm_extern_t` representation used by the Wasmtime C API. This allows different object types to be handled uniformly in contexts like module imports and exports.

## Core Types

### WasmExternObjectType

```julia
WasmExternObjectType = Union{WasmFunc,WasmGlobal,WasmTable,WasmMemory}
```

Union type defining all WebAssembly extern objects that can be wrapped by `WasmExtern`.

### WasmExtern

```julia
WasmExtern{E<:WasmExternObjectType} <: AbstractWasmExtern
```

Generic wrapper for WebAssembly extern objects with parameterized type information.

<!-- **Important**: The original object is finalized when creating the `WasmExtern` wrapper, as ownership transfers to the wrapper. The original object should not be used after creating the `WasmExtern`. -->

## Constructor

```julia
WasmExtern(obj::WasmExternObjectType)
```

Creates a `WasmExtern` wrapper around a specific extern object. The constructor:

- Validates the input object using `isvalid(obj)`
- Converts the object using the appropriate `_as_extern` C API function
- Validates the conversion succeeded
- Returns the wrapped extern object

## Usage Examples

### Memory Extern

```julia
engine = WasmEngine()
store = WasmStore(engine)

# Create and wrap a memory object
memory = WasmMemory(store, (1 => 10))  # 1 page minimum, 10 pages maximum
memory_extern = WasmExtern(memory)

# Use in import/export operations
@assert isvalid(memory_extern)
```

### Function Extern

```julia
# Create a function and wrap it as extern
function my_func(a::Int32, b::Int32)::Int32
    return a + b
end
wasm_func = WasmFunc(store, my_func)

func_extern = WasmExtern(wasm_func)
```

### Table Extern

```julia
# Create a table and wrap it as extern
table_type = WasmTableType((1 => 10))
table = WasmTable(store, table_type)
table_extern = WasmExtern(table)
```

### Global Extern

```julia
# Create a global and wrap it as extern (when implemented)
global_type = WasmGlobalType(WasmValType(Int32), false)  # immutable
global_ = WasmGlobal(store, global_type, WasmValue(Int32(42)))
global_extern = WasmExtern(global_)
```

## Type Safety

The `WasmExtern` struct is parameterized by the original object type:

```julia
memory_extern::WasmExtern{WasmMemory}
func_extern::WasmExtern{WasmFunc}
table_extern::WasmExtern{WasmTable}
global_extern::WasmExtern{WasmGlobal}
```

This maintains type information for compile-time safety while providing runtime flexibility.

## Common Operations

### Validity Checking

```julia
extern = WasmExtern(memory)
@assert isvalid(extern)  # Check if extern is valid
```

### Conversion to C API

```julia
# Automatic conversion for C API calls
c_ptr = Base.unsafe_convert(Ptr{LibWasmtime.wasm_extern_t}, extern)
```

### Display

```julia
extern = WasmExtern(memory)
println(extern)  # Prints: WasmExtern()
```

## Error Handling

The `WasmExtern` constructor performs validation and throws `ArgumentError` for:

- Invalid input objects (`!isvalid(obj)`)
- Unsupported object types
- Failed C API conversions (resulting in `C_NULL`)

```julia
try
    extern = WasmExtern(invalid_object)
catch e
    @error "Failed to create extern: $(e.msg)"
end
```

## Memory Management

**Critical**: The original object is finalized when creating the `WasmExtern` wrapper. This means:

```julia
memory = WasmMemory(store, (1 => 10))
extern = WasmExtern(memory)

# ❌ Don't use 'memory' after this point
# ✅ Use 'extern' instead
```

The `WasmExtern` wrapper takes ownership and manages the lifetime of the underlying C object.

## Best Practices

1. **Create externs immediately before use**: Don't hold onto the original objects
2. **Validate objects**: Always check `isvalid()` before creating externs
3. **Handle errors gracefully**: Wrap extern creation in try-catch blocks
4. **Use type parameters**: Leverage the parameterized type for better type safety

## Integration with Other Components

Externs integrate with:

- **Modules**: For import/export specifications
- **Instances**: For providing import values
- **Stores**: All extern objects are associated with a store
- **Types**: Each extern has an associated type (function, global, table, memory)

## Implementation Notes

- Each extern type uses its specific `_as_extern` C API function
- The wrapper maintains the original type information through parameterization
- Conversion to C API pointers is automatic via `Base.unsafe_convert`
- The struct is mutable to allow for potential future extensions
