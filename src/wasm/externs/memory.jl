mutable struct WasmMemoryType
    ptr::Ptr{LibWasmtime.wasm_memorytype_t}
    limits::WasmLimits
end

function WasmMemoryType(limits::Pair{Int,Int} = (0 => 0))
    # Convert limits to wasm_limits_t
    wasm_limits = WasmLimits(limits.first, limits.second)

    memory_type_ptr = GC.@preserve limits LibWasmtime.wasm_memorytype_new(
        pointer_from_objref(wasm_limits),
    )

    if memory_type_ptr == C_NULL
        throw(ArgumentError("Failed to create WasmMemoryType"))
    end

    memory_type = WasmMemoryType(memory_type_ptr, wasm_limits)
    finalizer(memory_type) do mt
        if mt.ptr != C_NULL
            LibWasmtime.wasm_memorytype_delete(mt.ptr)
        end
    end

    return memory_type
end

Base.unsafe_convert(
    ::Type{Ptr{LibWasmtime.wasm_memorytype_t}},
    memory_type::WasmMemoryType,
) = memory_type.ptr
Base.show(io::IO, memory_type::WasmMemoryType) = print(io, "WasmMemoryType()")
Base.isvalid(memory_type::WasmMemoryType) = memory_type.ptr != C_NULL

function WasmMemoryType(limits::WasmLimits)
    if !isvalid(limits)
        throw(ArgumentError("Invalid WasmLimits"))
    end

    memory_type_ptr =
        GC.@preserve limits LibWasmtime.wasm_memorytype_new(pointer_from_objref(limits))

    if memory_type_ptr == C_NULL
        throw(ArgumentError("Failed to create WasmMemoryType"))
    end

    memory_type = WasmMemoryType(memory_type_ptr, limits)

    finalizer(memory_type) do mt
        if mt.ptr != C_NULL
            LibWasmtime.wasm_memorytype_delete(mt.ptr)
        end
    end

    return memory_type
end

mutable struct WasmMemory
    ptr::Ptr{LibWasmtime.wasm_memory_t}
    # store::WasmStore

end

function WasmMemory(store::WasmStore, limits::Pair{Int,Int} = (0 => 0))
    isvalid(store) || throw(WasmtimeError("Invalid store"))

    # Convert limits to wasm_limits_t
    wasm_limits = WasmLimits(limits.first, limits.second)
    memory_type = WasmMemoryType(wasm_limits)

    # Create the memory using the wasm C API
    memory_ptr = LibWasmtime.wasm_memory_new(store, memory_type)

    if memory_ptr == C_NULL
        throw(WasmtimeError("Failed to create WasmMemory"))
    end

    memory = WasmMemory(memory_ptr)

    finalizer(memory) do m
        if m.ptr != C_NULL
            LibWasmtime.wasm_memory_delete(m.ptr)
            m.ptr = C_NULL
        end
    end

    return memory
end

map_to_extern(memory::WasmMemory) = LibWasmtime.wasm_memory_as_extern(memory.ptr)
Base.show(io::IO, memory::WasmMemory) = print(io, "WasmMemory()")
Base.isvalid(memory::WasmMemory) = memory.ptr != C_NULL
Base.unsafe_convert(::Type{Ptr{LibWasmtime.wasm_memory_t}}, memory::WasmMemory) = memory.ptr
