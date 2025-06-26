# Engine implementation for WasmtimeRuntime

# Engine implementation
mutable struct WasmEngine <: AbstractEngine
    ptr::Ptr{LibWasmtime.wasm_engine_t}

    function WasmEngine(config::Union{Config,Nothing} = nothing)
        ptr = if config === nothing
            LibWasmtime.wasm_engine_new()
        else
            isvalid(config) || throw(WasmtimeError("Invalid config"))
            # Mark config as consumed before creating engine
            _consume!(config)
            # This consumes the config - Wasmtime takes ownership
            LibWasmtime.wasm_engine_new_with_config(config.ptr)
        end

        if ptr == C_NULL
            throw(WasmtimeError("Failed to create Engine"))
        end

        engine = new(ptr)
        finalizer(engine) do e
            if e.ptr != C_NULL
                LibWasmtime.wasm_engine_delete(e.ptr)
                e.ptr = C_NULL
            end
        end
        return engine
    end
end

Base.isvalid(engine::WasmEngine) = engine.ptr != C_NULL
Base.unsafe_convert(::Type{Ptr{LibWasmtime.wasm_engine_t}}, engine::WasmEngine) = engine.ptr
