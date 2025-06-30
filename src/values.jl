mutable struct WasmValType{S}
    ptr::Ptr{LibWasmtime.wasm_valtype_t}

    function WasmValType(dt::DataType)
        valtype_ptr = LibWasmtime.wasm_valtype_new(to_wasm(dt))

        @assert valtype_ptr != C_NULL "Failed to create WasmValType"

        valtype = new{dt}(valtype_ptr)
        return valtype
    end
end

Base.unsafe_convert(::Type{Ptr{LibWasmtime.wasm_valtype_t}}, valtype::WasmValType) =
    valtype.ptr
Base.isvalid(valtype::WasmValType) = valtype.ptr != C_NULL
Base.show(io::IO, valtype::WasmValType) = print(io, "WasmValType()")

# Value type system using Julia's parametric types
abstract type WasmValue{T} <: WasmtimeValue end

struct WasmI32 <: WasmValue{Int32}
    value::Int32
end

struct WasmI64 <: WasmValue{Int64}
    value::Int64
end

struct WasmF32 <: WasmValue{Float32}
    value::Float32
end

struct WasmF64 <: WasmValue{Float64}
    value::Float64
end

# Reference types
struct WasmFuncRef <: WasmValue{Union{AbstractFunc,Nothing}}
    func::Union{AbstractFunc,Nothing}
end

struct WasmExternRef <: WasmValue{Any}
    value::Any
end

# V128 type for SIMD
struct WasmV128 <: WasmValue{NTuple{16,UInt8}}
    value::NTuple{16,UInt8}
end

# Conversion traits and functions
is_wasm_convertible(::Type{Int32}) = true
is_wasm_convertible(::Type{Int64}) = true
is_wasm_convertible(::Type{Float32}) = true
is_wasm_convertible(::Type{Float64}) = true
is_wasm_convertible(::Type{T}) where {T} = false

# Conversion functions using multiple dispatch
to_wasm(x::Int32) = WasmI32(x)
to_wasm(x::Int64) = WasmI64(x)
to_wasm(x::Float32) = WasmF32(x)
to_wasm(x::Float64) = WasmF64(x)

from_wasm(::Type{T}, val::WasmValue{T}) where {T} = val.value
