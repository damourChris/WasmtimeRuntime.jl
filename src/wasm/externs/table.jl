# WasmTable implementation for WasmtimeRuntime

"""
    WasmTableType

Represents a WebAssembly table type with size limits and element type.
Tables hold function references or other reference types.
"""
mutable struct WasmTableType
    ptr::Ptr{LibWasmtime.wasm_tabletype_t}

    function WasmTableType(limits::Pair{Int,Int} = (0 => 0))
        # Convert limits to wasm_limits_t
        wasm_limits = WasmLimits(limits.first, limits.second)
        table_valtype = WasmValType(Function)

        tabletype_ptr = GC.@preserve wasm_limits LibWasmtime.wasm_tabletype_new(
            table_valtype,
            pointer_from_objref(wasm_limits),
        )

        if tabletype_ptr == C_NULL
            throw(ArgumentError("Failed to create WasmTableType"))
        end

        tabletype = new(tabletype_ptr)
        finalizer(tabletype) do tt
            if tt.ptr != C_NULL
                LibWasmtime.wasm_tabletype_delete(tt.ptr)
                tt.ptr = C_NULL
            end
        end

        return tabletype
    end
end

function WasmTableType(limits::WasmLimits)
    if !isvalid(limits)
        throw(ArgumentError("Invalid WasmLimits"))
    end

    return WasmTableType(limits.min => limits.max)
end

Base.unsafe_convert(::Type{Ptr{LibWasmtime.wasm_tabletype_t}}, tabletype::WasmTableType) =
    tabletype.ptr
Base.show(io::IO, tabletype::WasmTableType) = print(io, "WasmTableType()")
Base.isvalid(tabletype::WasmTableType) = tabletype.ptr != C_NULL

"""
    WasmTable

WebAssembly table that holds function references or other reference types.
Implements AbstractVector interface for element access.
"""
mutable struct WasmTable <: AbstractVector{Union{Nothing,Ptr{LibWasmtime.wasm_ref_t}}}
    ptr::Ptr{LibWasmtime.wasm_table_t}

    function WasmTable(store::WasmStore, table_type::WasmTableType)
        if !isvalid(store) || !isvalid(table_type)
            throw(ArgumentError("Invalid store or table type"))
        end

        table_ptr = LibWasmtime.wasm_table_new(store, table_type, C_NULL)

        if table_ptr == C_NULL
            throw(ArgumentError("Failed to create WasmTable"))
        end

        table = new(table_ptr)

        finalizer(table) do t
            if t.ptr != C_NULL
                LibWasmtime.wasm_table_delete(t.ptr)
                t.ptr = C_NULL
            end
        end

        return table
    end
end

Base.unsafe_convert(::Type{Ptr{LibWasmtime.wasm_table_t}}, table::WasmTable) = table.ptr
Base.show(io::IO, table::WasmTable) = print(io, "WasmTable()")
Base.isvalid(table::WasmTable) = table.ptr != C_NULL
Base.size(table::WasmTable) = (LibWasmtime.wasm_table_size(table.ptr) |> Int,)

"""
    getindex(table::WasmTable, index::Int)

Get a reference from the table at the given index (1-based indexing).
Returns `nothing` if the slot is empty, or a reference pointer if occupied.
"""
function Base.getindex(table::WasmTable, index::Int)
    # Convert from 1-based to 0-based indexing for C API
    c_index = index - 1
    table_size = LibWasmtime.wasm_table_size(table.ptr)

    if c_index < 0 || c_index >= table_size
        throw(BoundsError(table, index))
    end

    ref_ptr = LibWasmtime.wasm_table_get(table.ptr, c_index)

    # Return nothing for null references, otherwise return the pointer
    return ref_ptr == C_NULL ? nothing : ref_ptr
end

"""
    WasmTableType(table::WasmTable)

Extract the table type from an existing table.
"""
function WasmTableType(table::WasmTable)

    if !isvalid(table)
        throw(ArgumentError("Invalid WasmTable"))
    end

    tabletype_ptr = LibWasmtime.wasm_table_type(table.ptr)

    if tabletype_ptr == C_NULL
        throw(ArgumentError("Failed to get WasmTableType from WasmTable"))
    end

    # Create a new WasmTableType object with the returned pointer
    # Note: We don't add a finalizer here since the pointer lifetime is managed by the table
    tabletype = WasmTableType((0 => 0))  # Create with dummy limits first
    tabletype.ptr = tabletype_ptr

    return tabletype
end
