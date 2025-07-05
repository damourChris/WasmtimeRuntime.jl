"""
    WasmExternObjectType

Union type for all WebAssembly extern objects that can be wrapped by `WasmExtern`.
Includes functions, globals, tables, and memories.
"""
WasmExternObjectType = Union{WasmFunc,WasmGlobal,WasmTable,WasmMemory}

"""
    WasmExtern{E<:WasmExternObjectType} <: AbstractWasmExtern

A wrapper for WebAssembly extern objects that provides a unified interface for
functions, globals, tables, and memories. This struct converts specific extern
objects into the generic `wasm_extern_t` representation used by the Wasmtime C API.
Important! The original object is finalized when creating the `WasmExtern` wrapper,
as ownership transfers to the wrapper. This means the original object should not be
used after creating the `WasmExtern`.

# Type Parameters
- `E`: The specific extern object type (WasmFunc, WasmGlobal, WasmTable, or WasmMemory)

# Fields
- `ptr::Ptr{LibWasmtime.wasm_extern_t}`: Pointer to the underlying C extern object

# Constructor
    WasmExtern(obj::WasmExternObjectType)

Creates a `WasmExtern` wrapper around a specific extern object. The original object
is finalized during construction as ownership transfers to the wrapper.

# Examples
```julia
# Create extern wrappers for different object types
engine = WasmEngine()
store = WasmStore(engine)

# Memory extern
memory = WasmMemory(store, (1 => 10))
memory_extern = WasmExtern(memory)

# Global extern (when implemented)
# global_type = WasmGlobalType(WasmValType(Int32), false)
# global = WasmGlobal(store, global_type, WasmValue(Int32(42)))
# global_extern = WasmExtern(global)
```

# Notes
- The original object is finalized when creating the extern wrapper
- Each extern type uses its corresponding `_as_extern` C API function
- The resulting extern can be used in import/export operations
"""
mutable struct WasmExtern{E<:WasmExternObjectType} <: AbstractWasmExtern
    ptr::Ptr{LibWasmtime.wasm_extern_t}
end

function WasmExtern(obj::WasmExternObjectType)
    # Validate the input object
    if !isvalid(obj)
        throw(ArgumentError("Invalid $(typeof(obj)) object"))
    end

    # Convert the specific extern object to generic wasm_extern_t
    # Each extern type has its own _as_extern conversion function
    if obj isa WasmFunc
        ptr = LibWasmtime.wasm_func_as_extern(obj.ptr)
    elseif obj isa WasmGlobal
        ptr = LibWasmtime.wasm_global_as_extern(obj.ptr)
    elseif obj isa WasmTable
        ptr = LibWasmtime.wasm_table_as_extern(obj.ptr)
    elseif obj isa WasmMemory
        ptr = LibWasmtime.wasm_memory_as_extern(obj.ptr)
    else
        throw(ArgumentError("Unsupported WasmExtern object type: $(typeof(obj))"))
    end

    # Validate the conversion succeeded
    if ptr == C_NULL
        throw(ArgumentError("Failed to convert $(typeof(obj)) to WasmExtern"))
    end

    wasm_extern = new{typeof(obj)}(ptr)
    return wasm_extern
end


function WasmExtern(ptr::Ptr{LibWasmtime.wasm_extern_t})::WasmExtern
    # Validate the pointer
    if ptr == C_NULL
        throw(ArgumentError("Invalid wasm_extern_t pointer"))
    end

    # Find out what kind of extern this is
    extern_kind = LibWasmtime.wasm_extern_kind(ptr)
    if extern_kind == C_NULL
        throw(ArgumentError("Invalid extern type kind"))
    end

    # Convert the extern pointer to the appropriate type
    if extern_kind == LibWasmtime.WASM_EXTERN_FUNC
        E = WasmFunc
        wasm_extern_obj = LibWasmtime.wasm_extern_as_func(ptr)
    elseif extern_kind == LibWasmtime.WASM_EXTERN_GLOBAL
        E = WasmGlobal
        wasm_extern_obj = LibWasmtime.wasm_extern_as_global(ptr)
    elseif extern_kind == LibWasmtime.WASM_EXTERN_TABLE
        E = WasmTable
        wasm_extern_obj = LibWasmtime.wasm_extern_as_table(ptr)
    elseif extern_kind == LibWasmtime.WASM_EXTERN_MEMORY
        E = WasmMemory
        wasm_extern_obj = LibWasmtime.wasm_extern_as_memory(ptr)
    else
        throw(ArgumentError("Unsupported extern type: $(extern_kind)"))
    end

    return WasmExtern{E}(wasm_extern_obj)
end

Base.unsafe_convert(::Type{Ptr{LibWasmtime.wasm_extern_t}}, extern::WasmExtern) = extern.ptr
Base.unsafe_convert(::Type{Ptr{LibWasmtime.wasm_func_t}}, extern::WasmExtern{WasmFunc}) =
    LibWasmtime.wasm_extern_as_func(extern)
Base.unsafe_convert(
    ::Type{Ptr{LibWasmtime.wasm_global_t}},
    extern::WasmExtern{WasmGlobal},
) = LibWasmtime.wasm_extern_as_global(extern)
Base.unsafe_convert(::Type{Ptr{LibWasmtime.wasm_table_t}}, extern::WasmExtern{WasmTable}) =
    LibWasmtime.wasm_extern_as_table(extern)
Base.unsafe_convert(
    ::Type{Ptr{LibWasmtime.wasm_memory_t}},
    extern::WasmExtern{WasmMemory},
) = LibWasmtime.wasm_extern_as_memory(extern)

Base.show(io::IO, extern::WasmExtern) = print(io, "WasmExtern()")
Base.isvalid(extern::WasmExtern) = extern.ptr != C_NULL

externtype(::WasmExtern{E}) where {E<:WasmExternObjectType} = E

function (extern::WasmExtern{WasmFunc})(args...)
    # Turn the WasmExtern back into a WasmFunc

    wasm_func = WasmFunc(LibWasmtime.wasm_extern_as_func(extern))
    if wasm_func == C_NULL
        throw(ArgumentError("Invalid WasmFunc pointer in WasmExtern"))
    end

    wasm_func.ptr

    # Call the WasmFunc with the provided arguments
    return wasm_func(args...)
end

unwrap_extern(ptr::Ptr{LibWasmtime.wasm_extern_t})::WasmExternObjectType =
    unwrap_extern(WasmExtern(ptr))

unwrap_extern(extern::WasmExtern{WasmFunc})::WasmFunc =
    WasmFunc(LibWasmtime.wasm_extern_as_func(extern))
unwrap_extern(extern::WasmExtern{WasmGlobal})::WasmGlobal =
    WasmGlobal(LibWasmtime.wasm_extern_as_global(extern))
unwrap_extern(extern::WasmExtern{WasmTable})::WasmTable =
    WasmTable(LibWasmtime.wasm_extern_as_table(extern))
unwrap_extern(extern::WasmExtern{WasmMemory})::WasmMemory =
    WasmMemory(LibWasmtime.wasm_extern_as_memory(extern))
