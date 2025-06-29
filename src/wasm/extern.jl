@enum WasmExternKind begin
    WasmExternFunc = LibWasmtime.WASM_EXTERN_FUNC
    WasmExternGlobal = LibWasmtime.WASM_EXTERN_GLOBAL
    WasmExternTable = LibWasmtime.WASM_EXTERN_TABLE
    WasmExternMemory = LibWasmtime.WASM_EXTERN_MEMORY
    WasmExternSharedMemory = LibWasmtime.WASM_EXTERN_SHARED_MEMORY
end

# Create a dictionary mapping to create the appropriate WasmExtern type
const WasmExternTypeMap = Dict(
    WasmExternKind.WasmExternFunc => WasmFunc,
    WasmExternKind.WasmExternGlobal => WasmGlobal,
    WasmExternKind.WasmExternTable => WasmTable,
    WasmExternKind.WasmExternMemory => WasmMemory,
    WasmExternKind.WasmExternSharedMemory => WasmSharedMemory,
)

mutable struct WasmExtern{E<:AbstractWasmExternObject} <: AbstractWasmExtern
    ptr::Ptr{LibWasmtime.wasm_extern_t}

    function WasmExtern(kind::WasmExternKind)
        @assert kind in keys(WasmExternTypeMap) "Invalid WasmExternKind: $kind"
        extern_type = WasmExternTypeMap[kind]
        ptr = LibWasmtime.wasm_extern_new(extern_type.ptr)

        new(ptr)

        finalizer(WasmExtern) do extern
            if extern.ptr != C_NULL
                LibWasmtime.wasm_extern_delete(extern.ptr)
                extern.ptr = C_NULL
            end
        end
    end
end

Base.unsafe_convert(::Type{Ptr{LibWasmtime.wasm_extern_t}}, extern::WasmExtern) = extern.ptr
Base.show(io::IO, extern::WasmExtern) = print(io, "WasmExtern()")
Base.isvalid(extern::WasmExtern) = extern.ptr != C_NULL

# Convertions between WasmExtern and AbstractWasmExternObject
function Base.convert(::Type{WasmExtern}, obj::AbstractWasmExternObject)
    # Ensure the object is a valid WasmExternObject
    if !isvalid(obj)
        throw(ArgumentError("Invalid WasmExternObject: $obj"))
    end

    if obj.ptr == C_NULL
        throw(ArgumentError("WasmExternObject pointer is null"))
    end

    extern = WasmExtern(obj.kind)

    # Copy the contents of the WasmExternObject to the WasmExtern
    LibWasmtime.wasm_extern_copy(extern.ptr, obj.ptr)

    return extern
end

function Base.convert(::Type{AbstractWasmExternObject}, extern::WasmExtern)
    # Ensure the extern is a valid WasmExtern
    if !isvalid(extern)
        throw(ArgumentError("Invalid WasmExtern: $extern"))
    end

    if extern.ptr == C_NULL
        throw(ArgumentError("WasmExtern pointer is null"))
    end

    # Create a new AbstractWasmExternObject of the appropriate type
    extern_type = WasmExternTypeMap[LibWasmtime.wasm_extern_kind(extern.ptr)]
    obj = extern_type()

    # Copy the contents of the WasmExtern to the AbstractWasmExternObject
    LibWasmtime.wasm_extern_copy(obj.ptr, extern.ptr)

    return obj
end
