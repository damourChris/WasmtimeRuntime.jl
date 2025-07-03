mutable struct WasmTrap <: Exception
    ptr::Ptr{LibWasmtime.wasm_trap_t}
    msg::AbstractString
end

function WasmTrap(ptr::Ptr{LibWasmtime.wasm_trap_t})
    msg = WasmByteVec()
    LibWasmtime.wasm_trap_message(ptr, msg)
    return WasmTrap(ptr, msg)
end

function Base.:(==)(a::WasmTrap, b::WasmTrap)
    return a.ptr == b.ptr
end

function Base.:(==)(a::WasmTrap, b::Ptr{LibWasmtime.wasm_trap_t})
    return a.ptr == b
end

function Base.:(==)(a::Ptr{LibWasmtime.wasm_trap_t}, b::WasmTrap)
    return a == b.ptr
end

function Base.:(!=)(a::WasmTrap, b::WasmTrap)
    return !(a == b)
end

function Base.:(!=)(a::WasmTrap, b::Ptr{LibWasmtime.wasm_trap_t})
    return !(a == b)
end

function Base.:(!=)(a::Ptr{LibWasmtime.wasm_trap_t}, b::WasmTrap)
    return !(a == b.ptr)
end

Base.unsafe_convert(::Type{WasmTrap}, ptr::Ptr{LibWasmtime.wasm_trap_t}) = WasmTrap(ptr)
Base.unsafe_convert(::Type{Ptr{LibWasmtime.wasm_trap_t}}, trap::WasmTrap) = trap.ptr
Base.isvalid(trap::WasmTrap) = trap.ptr != C_NULL

Base.show(io::IO, trap::WasmTrap) = print(io, "WasmTrap($(trap.msg))")
Base.showerror(io::IO, trap::WasmTrap) = print(io, "A WasmTrap occurred: $(trap.msg)")
