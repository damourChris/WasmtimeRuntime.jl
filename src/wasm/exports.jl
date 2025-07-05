# WebAssembly Export Types and Operations
# Provides type mappings and export creation for WebAssembly modules and instances

# Type mappings for export/extern conversions
const EXPORT_TYPE_TO_EXTERN_TYPE = Dict(
    WasmFuncType => WasmFunc,
    WasmGlobalType => WasmGlobal,
    WasmTableType => WasmTable,
    WasmMemoryType => WasmMemory,
)

const WASM_EXTERN_TYPE_TO_JULIA = Dict(
    Int(WASM_EXTERN_FUNC) => WasmFunc,
    Int(WASM_EXTERN_GLOBAL) => WasmGlobal,
    Int(WASM_EXTERN_TABLE) => WasmTable,
    Int(WASM_EXTERN_MEMORY) => WasmMemory,
)

Base.convert(::Type{LibWasmtime.wasm_name_t}, name::AbstractString) =
    WasmVec(codeunits(name) |> collect)

"""
    _get_export_name!(exporttype_ptr::Ptr{wasm_exporttype_t}) -> String

Extract export name from a wasm_exporttype_t pointer.

Handles memory management by deleting the returned name vector after extraction.
"""
function _get_export_name!(exporttype_ptr::Ptr{wasm_exporttype_t})
    if exporttype_ptr == C_NULL
        throw(ArgumentError("Invalid wasm_exporttype_t pointer"))
    end

    name_vec_ptr = LibWasmtime.wasm_exporttype_name(exporttype_ptr)
    name_vec = Base.unsafe_load(name_vec_ptr)
    name = unsafe_string(name_vec.data, name_vec.size)
    LibWasmtime.wasm_name_delete(name_vec_ptr)

    return name
end

"""
    WasmModuleExport{E<:WasmExternObjectType} <: AbstractWasmExport

Module-level export declaration with type information.

Represents an export specification from a WebAssembly module before instantiation.
Contains export name and type signature but no actual implementation.

# Fields
- `name::String`: Export identifier
- `ptr::Ptr{wasm_exporttype_t}`: Native export type handle
"""
mutable struct WasmModuleExport{E<:WasmExternObjectType} <: AbstractWasmExport
    name::String
    ptr::Ptr{wasm_exporttype_t}
end

"""
    WasmModuleExport(name, export_type::WasmFuncType) -> WasmModuleExport{WasmFunc}

Create function export declaration.
"""
function WasmModuleExport(
    name::AbstractString,
    export_type::WasmFuncType,
)::WasmModuleExport{WasmFunc}
    isvalid(name) || throw(ArgumentError("Invalid name for WasmExport: $name"))
    isvalid(export_type) || throw(ArgumentError("Invalid export type: $export_type"))
    owned_wasm_functype_ptr = LibWasmtime.wasm_functype_copy(export_type)

    wasm_extern_type = LibWasmtime.wasm_functype_as_externtype(owned_wasm_functype_ptr)
    wasm_extern_type != C_NULL ||
        throw(ArgumentError("Failed to convert WasmFuncType to wasm_extern_type"))

    name_vec = WasmVec(codeunits(name) |> collect)
    exporttype_ptr = LibWasmtime.wasm_exporttype_new(name_vec, wasm_extern_type)
    exporttype_ptr != C_NULL ||
        throw(ArgumentError("Failed to create WasmExport for name: $name"))

    wasm_mod_export = WasmModuleExport{WasmFunc}(name, exporttype_ptr)
    # finalizer(wasm_mod_export) do wasm_export
    #     if wasm_export.ptr != C_NULL
    #         LibWasmtime.wasm_exporttype_delete(wasm_export.ptr)
    #     end
    # end

    return wasm_mod_export
end

"""
    WasmModuleExport(name, export_type::WasmGlobalType) -> WasmModuleExport{WasmGlobal}

Create global export declaration.
"""
function WasmModuleExport(
    name::AbstractString,
    export_type::WasmGlobalType,
)::WasmModuleExport{WasmGlobal}
    isvalid(name) || throw(ArgumentError("Invalid name for WasmExport: $name"))
    isvalid(export_type) || throw(ArgumentError("Invalid export type: $export_type"))
    owned_wasm_globaltype_ptr = LibWasmtime.wasm_globaltype_copy(export_type)

    wasm_extern_type = LibWasmtime.wasm_globaltype_as_externtype(owned_wasm_globaltype_ptr)
    wasm_extern_type != C_NULL ||
        throw(ArgumentError("Failed to convert WasmGlobalType to wasm_extern_type"))

    name_vec = WasmVec(codeunits(name) |> collect)
    exporttype_ptr = LibWasmtime.wasm_exporttype_new(name_vec, wasm_extern_type)
    exporttype_ptr != C_NULL ||
        throw(ArgumentError("Failed to create WasmExport for name: $name"))

    wasm_mod_export = WasmModuleExport{WasmGlobal}(name, exporttype_ptr)
    # finalizer(wasm_mod_export) do wasm_export
    #     if wasm_export.ptr != C_NULL
    #         LibWasmtime.wasm_exporttype_delete(wasm_export.ptr)
    #     end
    # end

    return wasm_mod_export
end

"""
    WasmModuleExport(name, export_type::WasmTableType) -> WasmModuleExport{WasmTable}

Create table export declaration.
"""
function WasmModuleExport(
    name::AbstractString,
    export_type::WasmTableType,
)::WasmModuleExport{WasmTable}
    isvalid(name) || throw(ArgumentError("Invalid name for WasmExport: $name"))
    isvalid(export_type) || throw(ArgumentError("Invalid export type: $export_type"))
    owned_wasm_tabletype_ptr = LibWasmtime.wasm_tabletype_copy(export_type)

    wasm_extern_type = LibWasmtime.wasm_tabletype_as_externtype(owned_wasm_tabletype_ptr)
    wasm_extern_type != C_NULL ||
        throw(ArgumentError("Failed to convert WasmTableType to wasm_extern_type"))

    name_vec = WasmVec(codeunits(name) |> collect)
    exporttype_ptr = LibWasmtime.wasm_exporttype_new(name_vec, wasm_extern_type)
    exporttype_ptr != C_NULL ||
        throw(ArgumentError("Failed to create WasmExport for name: $name"))

    wasm_mod_export = WasmModuleExport{WasmTable}(name, exporttype_ptr)
    # finalizer(wasm_mod_export) do wasm_export
    #     if wasm_export.ptr != C_NULL
    #         LibWasmtime.wasm_exporttype_delete(wasm_export.ptr)
    #     end
    # end

    return wasm_mod_export
end

"""
    WasmModuleExport(name, export_type::WasmMemoryType) -> WasmModuleExport{WasmMemory}

Create memory export declaration.
"""
function WasmModuleExport(
    name::AbstractString,
    export_type::WasmMemoryType,
)::WasmModuleExport{WasmMemory}
    isvalid(name) || throw(ArgumentError("Invalid name for WasmExport: $name"))
    isvalid(export_type) || throw(ArgumentError("Invalid export type: $export_type"))
    owned_wasm_memorytype_ptr = LibWasmtime.wasm_memorytype_copy(export_type)

    wasm_extern_type = LibWasmtime.wasm_memorytype_as_externtype(owned_wasm_memorytype_ptr)
    wasm_extern_type != C_NULL ||
        throw(ArgumentError("Failed to convert WasmMemoryType to wasm_extern_type"))

    name_vec = WasmVec(codeunits(name) |> collect)
    exporttype_ptr = LibWasmtime.wasm_exporttype_new(name_vec, wasm_extern_type)
    exporttype_ptr != C_NULL ||
        throw(ArgumentError("Failed to create WasmExport for name: $name"))

    wasm_mod_export = WasmModuleExport{WasmMemory}(name, exporttype_ptr)
    # finalizer(wasm_mod_export) do wasm_export
    #     if wasm_export.ptr != C_NULL
    #         LibWasmtime.wasm_exporttype_delete(wasm_export.ptr)
    #     end
    # end

    return wasm_mod_export
end

"""
    WasmModuleExport(exporttype_ptr::Ptr{wasm_exporttype_t}) -> WasmModuleExport

Create export from existing wasm_exporttype_t pointer.

Automatically determines export type and extracts name from the pointer.
Used when processing module exports discovered through introspection.
"""
function WasmModuleExport(notowned_exporttype_ptr::Ptr{wasm_exporttype_t})::WasmModuleExport
    if notowned_exporttype_ptr == C_NULL
        throw(ArgumentError("Invalid wasm_exporttype_t pointer"))
    end

    exporttype_ptr = LibWasmtime.wasm_exporttype_copy(notowned_exporttype_ptr)

    if exporttype_ptr == C_NULL
        throw(ArgumentError("Invalid wasm_exporttype_t pointer"))
    end

    wasm_exporttype = LibWasmtime.wasm_exporttype_type(exporttype_ptr)
    if wasm_exporttype == C_NULL
        throw(ArgumentError("Failed to get export type for export"))
    end

    wasm_extern_type = LibWasmtime.wasm_externtype_kind(wasm_exporttype)
    if wasm_extern_type == C_NULL
        throw(ArgumentError("Failed to get extern type for export"))
    end

    # We only want to create WasmModuleExport for supported extern types
    if !haskey(WASM_EXTERN_TYPE_TO_JULIA, wasm_extern_type)
        throw(ArgumentError("Unsupported export type: $(wasm_extern_type)"))
    end

    extern_type = WASM_EXTERN_TYPE_TO_JULIA[wasm_extern_type]

    name = _get_export_name!(exporttype_ptr)

    wasm_module_export = WasmModuleExport{extern_type}(name, exporttype_ptr)
    # finalizer(wasm_module_export) do wasm_export
    #     if wasm_export.ptr != C_NULL
    #         LibWasmtime.wasm_exporttype_delete(wasm_export.ptr)
    #     end
    # end

    return wasm_module_export
end

Base.unsafe_convert(::Type{Ptr{wasm_exporttype_t}}, we::WasmModuleExport) = we.ptr
Base.isvalid(we::WasmModuleExport) = we.ptr != C_NULL
Base.show(io::IO, we::WasmModuleExport) =
    print(io, "WasmModuleExport(name=$(we.name), ptr=$(we.ptr))")

"""
    name(export::WasmModuleExport) -> String

Get export name.
"""
name(we::WasmModuleExport) = we.name

"""
    exporttype(::WasmModuleExport{E}) -> Type{E}

Get the Julia type corresponding to this export's extern type.
"""
exporttype(::WasmModuleExport{E}) where {E<:WasmExternObjectType} = E

"""
    WasmInstanceExport{E<:WasmExternObjectType} <: AbstractWasmExport

Instance-level export with concrete implementation.

Represents an actual exported object from an instantiated WebAssembly module.
Contains both the export metadata and the concrete extern object.

# Fields
- `name::AbstractString`: Export identifier
- `ptr::Ptr{wasm_exporttype_t}`: Native export type handle
- `extern::WasmExtern{E}`: Concrete extern object implementation
"""
mutable struct WasmInstanceExport{E<:WasmExternObjectType} <: AbstractWasmExport
    name::AbstractString
    ptr::Ptr{wasm_exporttype_t}
    extern::WasmExtern{E}
end

"""
    WasmInstanceExport(name, extern::WasmExtern{E}) -> WasmInstanceExport{E}

Create instance export from an extern object.

Associates an export name with a concrete extern implementation.
"""
function WasmInstanceExport(
    name::AbstractString,
    extern::WasmExtern{E},
) where {E<:WasmExternObjectType}
    if !isvalid(extern)
        throw(ArgumentError("Invalid WasmExtern object"))
    end

    # Now we need the extern type
    extern_type = externtype(extern)

    if extern_type == WasmFunc
        owned_wasm_extern_ptr = LibWasmtime.wasm_func_as_extern(extern)
    elseif extern_type == WasmGlobal
        owned_wasm_extern_ptr = LibWasmtime.wasm_global_as_extern(extern)
    elseif extern_type == WasmTable
        owned_wasm_extern_ptr = LibWasmtime.wasm_table_as_extern(extern)
    elseif extern_type == WasmMemory
        owned_wasm_extern_ptr = LibWasmtime.wasm_memory_as_extern(extern)
    else
        throw(ArgumentError("Unsupported WasmExtern type: $(typeof(extern))"))
    end

    if owned_wasm_extern_ptr == C_NULL
        throw(ArgumentError("Failed to convert WasmExtern to wasm_extern_t"))
    end

    wasm_extern_type = LibWasmtime.wasm_extern_type(owned_wasm_extern_ptr)

    name_vec = WasmVec(codeunits(name) |> collect)

    export_ptr = LibWasmtime.wasm_exporttype_new(name_vec, wasm_extern_type)

    if export_ptr == C_NULL
        throw(ArgumentError("Failed to create WasmExport for name: $name"))
    end

    export_ = WasmInstanceExport{extern_type}(name, export_ptr, extern)

    finalizer(export_) do wasm_export
        if wasm_export.ptr != C_NULL
            LibWasmtime.wasm_exporttype_delete(wasm_export.ptr)
        end
    end

    return export_
end

"""
    WasmInstanceExport(notowned_extern::Ptr{wasm_extern_t}) -> WasmInstanceExport

Create instance export from existing wasm_extern_t pointer.

Used when processing exports from instantiated modules.
"""
function WasmInstanceExport(notowned_extern::Ptr{wasm_extern_t})
    if notowned_extern == C_NULL
        throw(ArgumentError("Invalid wasm_extern_t pointer"))
    end

    extern = LibWasmtime.wasm_extern_copy(notowned_extern)

    extern_type_ptr = LibWasmtime.wasm_extern_type(extern)

    if extern_type_ptr == C_NULL
        throw(ArgumentError("Failed to get extern type for wasm_extern_t"))
    end

    # Convert the extern type pointer to a wasm_exporttype_t pointer
    extern_name = WasmVec(UInt8[])  # Empty name, will be extracted later
    exporttype_ptr = LibWasmtime.wasm_exporttype_new(extern_name, extern_type_ptr)

    if exporttype_ptr == C_NULL
        throw(ArgumentError("Failed to convert wasm_extern_t to wasm_exporttype_t"))
    end

    name = _get_export_name!(exporttype_ptr)

    # Get the extern type from the export type
    if haskey(EXPORT_TYPE_TO_EXTERN_TYPE, typeof(extern))
        extern_type = EXPORT_TYPE_TO_EXTERN_TYPE[typeof(extern)]
    else
        throw(ArgumentError("Unsupported export type: $(typeof(extern))"))
    end

    wasm_instance_export = WasmInstanceExport{extern_type}(name, exporttype_ptr, extern)
    # finalizer(wasm_instance_export) do wasm_export
    #     if wasm_export.ptr != C_NULL
    #         LibWasmtime.wasm_exporttype_delete(wasm_export.ptr)
    #     end
    # end

    return wasm_instance_export
end

"""
    name(export::WasmInstanceExport) -> String

Get export name.
"""
name(we::WasmInstanceExport) = we.name

Base.unsafe_convert(::Type{Ptr{wasm_exporttype_t}}, we::WasmInstanceExport) = we.ptr
Base.isvalid(we::WasmInstanceExport) = we.ptr != C_NULL
Base.show(io::IO, we::WasmInstanceExport) =
    print(io, "WasmInstanceExport(name=$(we.name), ptr=$(we.ptr), extern=$(we.extern))")
