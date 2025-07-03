# WebAssembly Objects: Memory, Globals, and Tables

**⚠️ Implementation Status:** Object access functionality is currently under development. This page documents the planned API.

## Current Limitations

The following WebAssembly object types are not yet fully implemented:

- Memory object access and manipulation
- Global variable access and modification
- Table operations and function references
- Complete export resolution

## Basic Export Access (🚧 Partial)

```julia
# Currently available (limited functionality)
engine = WasmEngine()
store = WasmStore(engine)

# Create instance
wat_content = """
(module
  (memory $mem 1)
  (global $counter (mut i32) (i32.const 0))
  (table $table 10 funcref)
  (export "memory" (memory $mem))
  (export "counter" (global $counter))
  (export "table" (table $table)))
"""

wasm_bytes = wat2wasm(wat_content)
module_obj = WasmModule(engine, wasm_bytes)
instance = WasmInstance(store, module_obj)

# Export enumeration currently returns placeholder data
exports_info = exports(module_obj)  # Dict{String,Any}()
```

## Planned Features (📋 Future Release)

### Memory Objects (Future API)

WebAssembly linear memory will be accessible through:

```julia
# Planned API for memory operations
struct Memory <: AbstractMemory
    ptr::Ptr{LibWasmtime.wasmtime_memory_t}
    store::Store
end

# Memory size operations
function memory_size(memory::Memory)::Int32
    # Get current size in pages (64KB each)
    return LibWasmtime.wasmtime_memory_size(memory.store.context, memory.ptr)
end

function memory_grow!(memory::Memory, delta_pages::Int32)::Int32
    # Grow memory by delta pages, return previous size
    prev_size_ref = Ref{Int32}()
    error_ptr = LibWasmtime.wasmtime_memory_grow(
        memory.store.context,
        memory.ptr,
        delta_pages,
        prev_size_ref
    )
    check_error(error_ptr)
    return prev_size_ref[]
end
```

### Memory Data Access (Future API)

```julia
# Read/write memory data
function read_memory(memory::Memory, offset::Int32, length::Int32)::Vector{UInt8}
    # Get raw memory pointer
    data_ptr = LibWasmtime.wasmtime_memory_data(memory.store.context, memory.ptr)
    data_size = LibWasmtime.wasmtime_memory_data_size(memory.store.context, memory.ptr)

    # Bounds checking
    if offset + length > data_size
        throw(BoundsError("Memory access out of bounds"))
    end

    # Copy data safely
    result = Vector{UInt8}(undef, length)
    unsafe_copyto!(pointer(result), data_ptr + offset, length)
    return result
end

function write_memory!(memory::Memory, offset::Int32, data::Vector{UInt8})
    data_ptr = LibWasmtime.wasmtime_memory_data(memory.store.context, memory.ptr)
    data_size = LibWasmtime.wasmtime_memory_data_size(memory.store.context, memory.ptr)

    if offset + length(data) > data_size
        throw(BoundsError("Memory write out of bounds"))
    end

    unsafe_copyto!(data_ptr + offset, pointer(data), length(data))
end
```

### Global Basics

WebAssembly globals are typed values that can be either mutable or immutable:

```julia
# Globals are retrieved from exports
global_export = get_export(instance, "global_var")

# TODO: Convert to Global type
# global_var = Global(export_ptr, store)
```

### Global Operations (Future API)

```julia
struct Global <: AbstractGlobal
    ptr::Ptr{LibWasmtime.wasmtime_global_t}
    store::Store
end

# Read global value
function get_global(global_var::Global)::WasmValue
    val_ref = Ref{LibWasmtime.wasmtime_val_t}()
    LibWasmtime.wasmtime_global_get(
        global_var.store.context,
        global_var.ptr,
        val_ref
    )
    return convert_wasmtime_val_to_julia(val_ref[])
end

# Write global value (if mutable)
function set_global!(global_var::Global, value::WasmValue)
    val = convert_julia_to_wasmtime_val(value)
    error_ptr = LibWasmtime.wasmtime_global_set(
        global_var.store.context,
        global_var.ptr,
        Ref(val)
    )
    check_error(error_ptr)
end
```

### Global Type Information (Future API)

```julia
# Get global type information
function global_type(global_var::Global)
    type_ptr = LibWasmtime.wasmtime_global_type(
        global_var.store.context,
        global_var.ptr
    )

    # Extract type information
    return (
        value_type = get_global_value_type(type_ptr),
        is_mutable = get_global_mutability(type_ptr)
    )
end
```

## Tables

### Table Basics

WebAssembly tables are arrays of opaque values (typically function references):

```julia
# Tables are retrieved from exports
table_export = get_export(instance, "table")

# TODO: Convert to Table type
# table = Table(export_ptr, store)
```

### Table Operations (Future API)

```julia
struct Table <: AbstractTable
    ptr::Ptr{LibWasmtime.wasmtime_table_t}
    store::Store
end

# Get table size
function table_size(table::Table)::Int32
    return LibWasmtime.wasmtime_table_size(table.store.context, table.ptr)
end

# Get table element
function get_table_element(table::Table, index::Int32)::Union{WasmValue, Nothing}
    val_ref = Ref{LibWasmtime.wasmtime_val_t}()
    found = LibWasmtime.wasmtime_table_get(
        table.store.context,
        table.ptr,
        index,
        val_ref
    )

    if found != 0
        return convert_wasmtime_val_to_julia(val_ref[])
    else
        return nothing
    end
end

# Set table element
function set_table_element!(table::Table, index::Int32, value::WasmValue)
    val = convert_julia_to_wasmtime_val(value)
    error_ptr = LibWasmtime.wasmtime_table_set(
        table.store.context,
        table.ptr,
        index,
        Ref(val)
    )
    check_error(error_ptr)
end

# Grow table
function table_grow!(table::Table, delta::Int32, init_value::WasmValue)::Int32
    init_val = convert_julia_to_wasmtime_val(init_value)
    prev_size_ref = Ref{Int32}()

    error_ptr = LibWasmtime.wasmtime_table_grow(
        table.store.context,
        table.ptr,
        delta,
        Ref(init_val),
        prev_size_ref
    )

    check_error(error_ptr)
    return prev_size_ref[]
end
```

## Export Management

### Current Export Retrieval

```julia
# Current implementation returns raw wasmtime_extern_t
function get_memory_export(instance::Instance, name::String)
    export_item = get_export(instance, name)
    # TODO: Type checking and conversion
    return export_item
end

function get_global_export(instance::Instance, name::String)
    export_item = get_export(instance, name)
    # TODO: Type checking and conversion
    return export_item
end

function get_table_export(instance::Instance, name::String)
    export_item = get_export(instance, name)
    # TODO: Type checking and conversion
    return export_item
end
```

### Future Export Management

```julia
# Future type-safe export retrieval
function get_export_typed(instance::Instance, name::String, ::Type{T}) where T
    export_item = get_export(instance, name)

    if T == Memory
        return convert_to_memory(export_item, instance.store)
    elseif T == Global
        return convert_to_global(export_item, instance.store)
    elseif T == Table
        return convert_to_table(export_item, instance.store)
    elseif T == Func
        return convert_to_func(export_item, instance.store)
    else
        throw(ArgumentError("Unsupported export type: $T"))
    end
end

# Convenience methods
get_memory(instance, name) = get_export_typed(instance, name, Memory)
get_global(instance, name) = get_export_typed(instance, name, Global)
get_table(instance, name) = get_export_typed(instance, name, Table)
```

## Working with Object Types

### Type Identification (Future API)

```julia
# Identify export types
function identify_export_type(export_item)
    extern_type = LibWasmtime.wasmtime_extern_type(context, export_item)
    kind = LibWasmtime.wasm_externtype_kind(extern_type)

    if kind == LibWasmtime.WASMTIME_EXTERN_FUNC
        return Func
    elseif kind == LibWasmtime.WASMTIME_EXTERN_MEMORY
        return Memory
    elseif kind == LibWasmtime.WASMTIME_EXTERN_GLOBAL
        return Global
    elseif kind == LibWasmtime.WASMTIME_EXTERN_TABLE
        return Table
    else
        throw(ArgumentError("Unknown export type"))
    end
end
```

### Generic Export Processing

```julia
# Process all exports generically
function process_all_exports(instance::Instance)
    # This would work when export enumeration is implemented
    for (name, export_item) in exports(instance)
        export_type = identify_export_type(export_item)

        if export_type == Memory
            memory = convert_to_memory(export_item, instance.store)
            println("Memory '$name': $(memory_size(memory)) pages")

        elseif export_type == Global
            global_var = convert_to_global(export_item, instance.store)
            value = get_global(global_var)
            println("Global '$name': $value")

        elseif export_type == Table
            table = convert_to_table(export_item, instance.store)
            size = table_size(table)
            println("Table '$name': $size elements")

        elseif export_type == Func
            func = convert_to_func(export_item, instance.store)
            println("Function '$name': callable")
        end
    end
end
```

## Advanced Object Operations

### Memory Mapping Patterns (Future API)

```julia
# Safe memory mapping
function with_memory_view(f, memory::Memory, offset::Int32, length::Int32)
    # Bounds checking
    current_size = memory_size(memory) * 65536  # Convert pages to bytes
    if offset + length > current_size
        throw(BoundsError("Memory view out of bounds"))
    end

    # Get raw memory pointer
    data_ptr = LibWasmtime.wasmtime_memory_data(memory.store.context, memory.ptr)

    # Create a view (be careful with GC)
    try
        # Create unsafe array view
        view = unsafe_wrap(Array{UInt8}, data_ptr + offset, length, own=false)
        return f(view)
    catch e
        rethrow(e)
    end
end

# Usage
result = with_memory_view(memory, 0, 1024) do view
    # Work with memory as Julia array
    sum(view)
end
```

### Global Variable Patterns

```julia
# Type-safe global access
function typed_global_get(global_var::Global, ::Type{T}) where T
    value = get_global(global_var)
    if value isa WasmValue{T}
        return value.value
    else
        throw(TypeError("Global value is not of type $T"))
    end
end

function typed_global_set!(global_var::Global, value::T) where T
    wasm_value = to_wasm(value)
    set_global!(global_var, wasm_value)
end

# Usage
counter = get_global(instance, "counter")
current_value = typed_global_get(counter, Int32)
typed_global_set!(counter, current_value + 1)
```

### Table Management Patterns

```julia
# Function table management
function add_function_to_table(table::Table, func::Func)::Int32
    current_size = table_size(table)

    # Grow table by one element
    prev_size = table_grow!(table, 1, WasmFuncRef(nothing))

    # Set the new function
    func_ref = WasmFuncRef(func)
    set_table_element!(table, prev_size, func_ref)

    return prev_size  # Return index of added function
end

# Call function from table
function call_table_function(table::Table, index::Int32, params...)
    func_ref = get_table_element(table, index)

    if func_ref isa WasmFuncRef && func_ref.func !== nothing
        return call(func_ref.func, collect(params))
    else
        throw(ArgumentError("No function at table index $index"))
    end
end
```

## Error Handling

### Object Access Errors

```julia
function safe_object_access(instance::Instance, name::String, expected_type::Type)
    try
        export_item = get_export(instance, name)
        actual_type = identify_export_type(export_item)

        if actual_type != expected_type
            throw(TypeError("Export '$name' is $actual_type, expected $expected_type"))
        end

        return export_item
    catch e::WasmtimeError
        if occursin("not found", e.message)
            throw(KeyError("Export '$name' not found"))
        else
            rethrow(e)
        end
    end
end
```

### Memory Safety

```julia
function safe_memory_operation(f, memory::Memory, offset::Int32, length::Int32)
    current_size_bytes = memory_size(memory) * 65536

    if offset < 0
        throw(BoundsError("Negative offset"))
    end

    if length < 0
        throw(BoundsError("Negative length"))
    end

    if offset + length > current_size_bytes
        throw(BoundsError("Access beyond memory bounds"))
    end

    try
        return f()
    catch e
        @error "Memory operation failed" offset=offset length=length exception=e
        rethrow(e)
    end
end
```

## Best Practices

### Object Lifecycle Management

```julia
# Objects are tied to their store's lifetime
function manage_object_lifecycle()
    engine = Engine()
    store = Store(engine)
    instance = Instance(store, module_obj)

    # Get objects
    memory = get_memory(instance, "memory")
    global_var = get_global(instance, "counter")
    table = get_table(instance, "func_table")

    # Objects remain valid as long as store is valid
    # No manual cleanup needed

    return (memory, global_var, table)
end
```

### Type Safety

```julia
# Always check types before operations
function ensure_mutable_global(global_var::Global)
    type_info = global_type(global_var)

    if !type_info.is_mutable
        throw(ArgumentError("Global is immutable"))
    end

    return global_var
end
```

### Performance Optimization

```julia
# Cache frequently accessed objects
struct CachedObjects
    memory::Union{Memory, Nothing}
    globals::Dict{String, Global}
    tables::Dict{String, Table}
end

function cache_objects(instance::Instance, names...)
    cache = CachedObjects(nothing, Dict(), Dict())

    for name in names
        try
            export_item = get_export(instance, name)
            export_type = identify_export_type(export_item)

            if export_type == Memory
                cache.memory = convert_to_memory(export_item, instance.store)
            elseif export_type == Global
                cache.globals[name] = convert_to_global(export_item, instance.store)
            elseif export_type == Table
                cache.tables[name] = convert_to_table(export_item, instance.store)
            end
        catch e
            @warn "Failed to cache object: $name" exception=e
        end
    end

    return cache
end
```

WebAssembly objects provide powerful capabilities for data sharing and state management between Julia and WebAssembly code. The type-safe wrappers ensure memory safety while maintaining performance.
