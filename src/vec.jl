# Generic wrapper for wasm_XXX_vec_t types with AbstractVector interface
# This is mostly inspired from the work done in Wasmtime.jl (see https://github.com/Pangoraw/Wasmtime.jl/blob/a357101f3dbbf29b4ea526ebe8983ecfc12be0da/src/vec_t.jl)

"""
    WasmVec{T,S} <: AbstractVector{S}

Generic wrapper around `wasm_XXX_vec_t` types that implements AbstractVector interface.

# Examples
```julia
extern_vec = WasmVec{wasm_extern_vec_t, Ptr{wasm_extern_t}}()
wasm_vec = WasmVec([ptr1, ptr2, ptr3])
```
"""
mutable struct WasmVec{T,S} <: AbstractVector{S}
    size::Csize_t
    data::Ptr{S}
end

# Delete underlying C vector - called automatically by finalizer
wasm_vec_delete(wasm_vec::WasmVec{T,S}) where {T,S} = _get_delete_function(T)(wasm_vec)

function WasmVec{T,S}(vector::Vector{S} = S[]) where {T,S}
    vec_size = length(vector)

    # Create uninitialized C vector
    wasm_vec = WasmVec{T,S}(0, C_NULL)
    vec_uninitialized = _get_uninitialized_function(T)
    vec_uninitialized(wasm_vec, vec_size)

    # Copy data if vector is not empty
    if vec_size > 0
        src_ptr = pointer(vector)
        GC.@preserve vector unsafe_copyto!(wasm_vec.data, src_ptr, vec_size)
    end

    finalizer(wasm_vec_delete, wasm_vec)
    return wasm_vec
end

# Helper functions for C function name resolution

function _get_delete_function(T)
    type_name = string(nameof(T))
    delete_name = replace(type_name, r"_vec_t$" => "_vec_delete")
    return getproperty(LibWasmtime, Symbol(delete_name))
end

function _get_uninitialized_function(T)
    type_name = string(nameof(T))
    uninit_name = replace(type_name, r"_vec_t$" => "_vec_new_uninitialized")
    return getproperty(LibWasmtime, Symbol(uninit_name))
end

function _get_wasm_vec_name(::Type{S}) where {S}
    if S == Cchar || S == UInt8
        return wasm_byte_vec_t
    end

    @assert parentmodule(S) == LibWasmtime || S <: Ptr "$S should be a LibWasmtime type or pointer"

    if S <: Ptr
        # Handle pointer types (e.g., Ptr{wasm_extern_t} -> wasm_extern_vec_t)
        inner_type = eltype(S)
        type_name = string(nameof(inner_type))
    else
        type_name = string(nameof(S))
    end

    # Convert wasm_XXX_t to wasm_XXX_vec_t
    vec_type_name = replace(type_name, r"_t$" => "_vec_t")
    vec_type_sym = Symbol(vec_type_name)

    return getproperty(LibWasmtime, vec_type_sym)
end

# Convenience constructors

WasmVec(base_type::Type) = WasmVec(base_type[])

function WasmVec(vec::Vector{S}) where {S}
    vec_type = _get_wasm_vec_name(S)
    return WasmVec{vec_type,S}(vec)
end

WasmPtrVec(base_type::Type) = WasmPtrVec(Ptr{base_type}[])

function WasmPtrVec(vec::Vector{Ptr{S}}) where {S}
    vec_type = _get_wasm_vec_name(S)
    return WasmVec{vec_type,Ptr{S}}(vec)
end

# AbstractVector interface implementation


Base.length(vec::WasmVec) = Int(vec.size)

Base.size(vec::WasmVec) = (length(vec),)

Base.eltype(::Type{<:WasmVec{T,S}}) where {T,S} = S
Base.IndexStyle(::Type{<:WasmVec}) = IndexLinear()


function Base.getindex(vec::WasmVec, i::Int)
    @boundscheck checkbounds(vec, i)
    return unsafe_load(vec.data, i)
end

function Base.setindex!(vec::WasmVec{T,S}, v::S, i::Int) where {T,S}
    @boundscheck checkbounds(vec, i)

    elsize = sizeof(S)
    ref = Ref(v)
    src_ptr = Base.unsafe_convert(Ptr{S}, ref)
    dest_ptr = Base.unsafe_convert(Ptr{S}, vec.data + elsize * (i - 1))

    GC.@preserve ref unsafe_copyto!(dest_ptr, src_ptr, 1)
    return v
end

# C interop conversions

Base.unsafe_convert(::Type{Ptr{T}}, vec::WasmVec{T,S}) where {T,S} =
    Base.unsafe_convert(Ptr{T}, pointer_from_objref(vec))

Base.unsafe_convert(::Type{Ptr{S}}, vec::WasmVec{T,S}) where {T,S} = vec.data

# Type aliases for common vector types

const WasmByteVec = WasmVec{wasm_byte_vec_t,UInt8}
const WasmName = WasmByteVec  # For module and function names
const WasmExternVec = WasmVec{wasm_extern_vec_t,Ptr{wasm_extern_t}}
const WasmImportTypeVec = WasmVec{wasm_importtype_vec_t,Ptr{wasm_importtype_t}}
const WasmExportTypeVec = WasmVec{wasm_exporttype_vec_t,Ptr{wasm_exporttype_t}}
const WasmValtypeVec = WasmVec{wasm_valtype_vec_t,Ptr{wasm_valtype_t}}
const WasmValVec = WasmVec{wasm_val_vec_t,wasm_val_t}
const WasmTableTypeVec = WasmVec{wasm_tabletype_vec_t,Ptr{wasm_tabletype_t}}
const WasmExternTypeVec = WasmVec{wasm_externtype_vec_t,Ptr{wasm_externtype_t}}
const WasmFrameVec = WasmVec{wasm_frame_vec_t,Ptr{wasm_frame_t}}  # For stack traces

# Utility functions

function to_julia_vector(vec::WasmVec{T,S}) where {T,S}
    if length(vec) == 0
        return S[]
    end

    result = Vector{S}(undef, length(vec))
    GC.@preserve result unsafe_copyto!(pointer(result), vec.data, length(vec))
    return result
end

Base.collect(vec::WasmVec) = to_julia_vector(vec)

function Base.copy(vec::WasmVec{T,S}) where {T,S}
    julia_vec = to_julia_vector(vec)
    return WasmVec{T,S}(julia_vec)
end
