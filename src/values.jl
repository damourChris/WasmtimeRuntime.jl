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

const JULIA_TO_WASM_TYPE_MAP = Dict(
    Int32 => (kind = LibWasmtime.WASM_I32, of_field = :i32),
    Int64 => (kind = LibWasmtime.WASM_I64, of_field = :i64),
    Float32 => (kind = LibWasmtime.WASM_F32, of_field = :f32),
    Float64 => (kind = LibWasmtime.WASM_F64, of_field = :f64),
    Any => (kind = LibWasmtime.WASM_ANYREF, of_field = :anyref),
    AbstractFunc => (kind = LibWasmtime.WASM_FUNCREF, of_field = :funcref),
)


function julia_type_to_valkind(julia_type::Type)::wasm_valkind_enum
    if haskey(JULIA_TO_WASM_TYPE_MAP, julia_type)
        return JULIA_TO_WASM_TYPE_MAP[julia_type].kind
    else
        throw(ArgumentError("Unsupported Julia type: $julia_type"))
    end
end

julia_type_to_valtype(julia_type)::Ptr{wasm_valtype_t} =
    julia_type_to_valkind(julia_type) |> wasm_valtype_new

abstract type WasmValue{T} end
function WasmValue(value::T) where {T}
    val = Ref(wasm_val_t(tuple((zero(UInt8) for _ = 1:16)...)))
    ptr = Base.unsafe_convert(Ptr{wasm_val_t}, Base.pointer_from_objref(val))
    (; kind, of_field) = JULIA_TO_WASM_TYPE_MAP[T]

    ptr.kind = kind
    if T == Int32
        ptr.of.i32 = value
    elseif T == Int64
        ptr.of.i64 = value
    elseif T == Float32
        ptr.of.f32 = value
    elseif T == Float64
        ptr.of.f64 = value
    end

    val[]
end

function Base.:(==)(wasm_val_1::wasm_val_t, wasm_val_2::wasm_val_t)
    wasm_val_1.of == wasm_val_2.of
end

Base.convert(::Type{wasm_val_t}, i::Int32) = WasmValue(i)
Base.convert(::Type{wasm_val_t}, i::Int64) = WasmValue(i)
Base.convert(::Type{wasm_val_t}, f::Float32) = WasmValue(f)
Base.convert(::Type{wasm_val_t}, f::Float64) = WasmValue(f)

function Base.convert(julia_type, wasm_val::wasm_val_t)
    valkind = julia_type_to_valkind(julia_type)
    @assert valkind == wasm_val.kind "Cannot convert a value of kind $(wasm_val.kind) to corresponding kind $valkind"
    ctag = Ref(wasm_val.of)
    ptr = Base.unsafe_convert(Ptr{LibWasmtime.__JL_Ctag_18}, ctag)
    jl_val = GC.@preserve ctag unsafe_load(Ptr{julia_type}(ptr))
    jl_val
end

from_wasm(::Type{T}, val::WasmValue{T}) where {T} = val.value
to_wasm(T::DataType) = JULIA_TO_WASM_TYPE_MAP[T].kind
