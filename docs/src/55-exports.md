# WebAssembly Exports

WebAssembly exports define the interface through which WebAssembly modules expose their functionality to the outside world. WasmtimeRuntime.jl provides two main export types: module-level export declarations and instance-level exports with concrete implementations.

## Overview

The export system distinguishes between:

- **Module Exports**: Type declarations from uninstantiated modules
- **Instance Exports**: Concrete implementations from instantiated modules

This separation allows for type checking before instantiation and efficient access to exported functionality after instantiation.

## Module Exports

### WasmModuleExport

```julia
WasmModuleExport{E<:WasmExternObjectType} <: AbstractWasmExport
```

Represents an export specification from a WebAssembly module before instantiation. Contains export name and type signature but no actual implementation.

**Fields:**

- `name::String`: Export identifier
- `ptr::Ptr{wasm_exporttype_t}`: Native export type handle

### Constructors

#### Function Export

```julia
WasmModuleExport(name, export_type::WasmFuncType) -> WasmModuleExport{WasmFunc}
```

#### Global Export

```julia
WasmModuleExport(name, export_type::WasmGlobalType) -> WasmModuleExport{WasmGlobal}
```

#### Table Export

```julia
WasmModuleExport(name, export_type::WasmTableType) -> WasmModuleExport{WasmTable}
```

#### Memory Export

```julia
WasmModuleExport(name, export_type::WasmMemoryType) -> WasmModuleExport{WasmMemory}
```

#### From Native Pointer

```julia
WasmModuleExport(exporttype_ptr::Ptr{wasm_exporttype_t}) -> WasmModuleExport
```

Creates export from existing wasm_exporttype_t pointer. Automatically determines export type and extracts name.

### Examples

```julia
using WasmtimeRuntime

# Create function export declaration
func_type = WasmFuncType([Int32, Int32], [Int32])
func_export = WasmModuleExport("add", func_type)

# Create global export declaration
global_type = WasmGlobalType(WasmValType(Int32), false)  # immutable i32
global_export = WasmModuleExport("counter", global_type)

# Create memory export declaration
memory_type = WasmMemoryType(WasmLimits(1, 10))  # min=1, max=10 pages
memory_export = WasmModuleExport("memory", memory_type)

# Get export properties
println("Export name: ", name(func_export))
println("Export type: ", exporttype(func_export))
```

## Instance Exports

### WasmInstanceExport

```julia
WasmInstanceExport{E<:WasmExternObjectType} <: AbstractWasmExport
```

Represents an actual exported object from an instantiated WebAssembly module. Contains both the export metadata and the concrete extern object.

**Fields:**

- `name::AbstractString`: Export identifier
- `ptr::Ptr{wasm_exporttype_t}`: Native export type handle
- `extern::WasmExtern{E}`: Concrete extern object implementation

## Common Operations

### Inspecting Exports

```julia
# Check export validity
@assert isvalid(export_obj)

# Get export name
export_name = name(export_obj)

# Get export type (for module exports)
export_type = exporttype(module_export)

# Access underlying extern (for instance exports)
extern_obj = instance_export.extern
```

### Type Mapping

The export system uses type mapping dictionaries to convert between different representations:

```julia
# Export type to extern type mapping
EXPORT_TYPE_TO_EXTERN_TYPE = Dict(
    WasmFuncType => WasmFunc,
    WasmGlobalType => WasmGlobal,
    WasmTableType => WasmTable,
    WasmMemoryType => WasmMemory,
)

# Native extern type to Julia type mapping
WASM_EXTERN_TYPE_TO_JULIA = Dict(
    Int(WASM_EXTERN_FUNC) => WasmFunc,
    Int(WASM_EXTERN_GLOBAL) => WasmGlobal,
    Int(WASM_EXTERN_TABLE) => WasmTable,
    Int(WASM_EXTERN_MEMORY) => WasmMemory,
)
```

## Memory Management

| Aspect            | Module Exports                                                                 | Instance Exports                                 |
|-------------------|--------------------------------------------------------------------------------|--------------------------------------------------|
| Cleanup           | Automatic via finalizers                                                        | Export wrapper handles metadata cleanup           |
| Lifetime          | Safe to use after module destruction (type information persists)                | Tied to instance lifetime                        |
| Native Resources  | Finalizer handles native pointer cleanup                                        | Extern objects maintain their own lifecycle       |

### Best Practices

```julia
# ✅ Good: Check validity before use
if isvalid(export_obj)
    result = use_export(export_obj)
end

# ✅ Good: Extract needed information early
export_name = name(export_obj)
export_type = exporttype(export_obj)

# ❌ Avoid: Using exports after instance destruction
instance = nothing  # Instance goes out of scope
# exports may become invalid
```

## Error Handling

Common error scenarios and their handling:

```julia
# Invalid export name
try
    export = WasmModuleExport("", func_type)
catch ArgumentError as e
    println("Invalid name: ", e.msg)
end

# Invalid export type
try
    export_ = WasmModuleExport("func", invalid_type)
catch ArgumentError as e
    println("Invalid type: ", e.msg)
end

# Unsupported export type
try
    export_ = WasmModuleExport(unsupported_ptr)
catch ArgumentError as e
    println("Unsupported type: ", e.msg)
end
```

## Integration with Other Components

### With Modules

```julia
# Get module exports before instantiation
module_exports = exports(module_)
for export in module_exports
    println("Module exports: ", name(export))
end
```

### With Instances

```julia
# Get instance exports after instantiation
instance_exports = exports(instance)
exported_func = instance_exports["my_function"]
result = call_wasm_function(exported_func.extern.object, args)
```

### With External Objects

```julia
# Wrap existing extern in export
extern = WasmExtern(my_wasm_func)
export_ = WasmInstanceExport("my_func", extern)
```

## Implementation Notes

- Export names are converted to `WasmVec` for C API compatibility
- Type parameterization enables compile-time type safety
- Finalizers ensure proper cleanup of native resources
- Both export types support the same base interface through `AbstractWasmExport`

## Usage Examples

The following example demonstrates how to create and use instance exports after instantiating a WebAssembly module:

```julia
using WasmtimeRuntime

# Assuming you have an instantiated module with exports
engine = WasmEngine()
store = WasmStore(engine)

# Load and compile WebAssembly module
wasm_bytes = wat2wasm("""
(module
  (func (export "add") (param i32 i32) (result i32)
    local.get 0
    local.get 1
    i32.add)
  (global (export "counter") (mut i32) (i32.const 0))
  (memory (export "memory") 1 10)
)
""")

module_ = WasmModule(store, wasm_bytes)
instance = WasmInstance(store, module_)

# Access instance exports
exports_ = exports(instance)
add_export = exports_[:add]
counter_export = exports_[:counter]
memory_export = exports_[:memory]

# Get export details
println("Export name: ", name(add_export))
println("Export extern: ", add_export.extern)

# Use the exported function
add_func = add_export.extern
result = add_func(Int32(5), Int32(3))
```

!!! note
    The `exports` function returns a dictionary mapping export names to their corresponding `WasmInstanceExport` objects, allowing easy access to exported functionality.
