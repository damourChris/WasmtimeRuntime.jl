# WasmStore implementation for WasmtimeRuntime

# Store implementation for WasmtimeRuntime
mutable struct WasmStore <: AbstractStore
    ptr::Ptr{wasm_store_t}
    externs_func::Vector{Base.CFunction}

    function WasmStore(wasm_engine::WasmEngine)
        isvalid(wasm_engine) || throw(WasmtimeError("Invalid engine"))

        wasm_store_ptr = LibWasmtime.wasm_store_new(wasm_engine)

        finalizer(store) do store
            if store.wasm_store_ptr != C_NULL
                LibWasmtime.wasm_store_delete(store.wasm_store_ptr)
                store.wasm_store_ptr = C_NULL
            end
        end
    end
end

add_extern_func!(wasm_store::WasmStore, cfunc::Base.CFunction) =
    push!(wasm_store.externs_func, cfunc)

Base.unsafe_convert(::Type{Ptr{wasm_store_t}}, wasm_store::WasmStore) = wasm_store.ptr
Base.show(io::IO, ::WasmStore) = print(io, "WasmStore()")
