# Store implementation for WasmtimeRuntime

# Store implementation
mutable struct Store <: AbstractStore
    ptr::Ptr{LibWasmtime.wasmtime_store_t}
    engine::Engine
    context::Ptr{LibWasmtime.wasmtime_context_t}

    function Store(engine::Engine, data = nothing)
        isvalid(engine) || throw(WasmtimeError("Invalid engine"))

        ptr = if data === nothing
            LibWasmtime.wasmtime_store_new(engine.ptr, C_NULL, C_NULL)
        else
            # TODO: Handle user data properly
            LibWasmtime.wasmtime_store_new(engine.ptr, C_NULL, C_NULL)
        end

        if ptr == C_NULL
            throw(WasmtimeError("Failed to create Store"))
        end

        # Get the context for this store
        context = LibWasmtime.wasmtime_store_context(ptr)

        store = new(ptr, engine, context)
        finalizer(store) do s
            if s.ptr != C_NULL
                LibWasmtime.wasmtime_store_delete(s.ptr)
                s.ptr = C_NULL
            end
        end
        return store
    end
end

Base.isvalid(store::Store) = store.ptr != C_NULL && store.context != C_NULL

# Fuel management for Store
function add_fuel!(store::Store, fuel::Integer)
    isvalid(store) || throw(WasmtimeError("Invalid store"))
    error_ptr = LibWasmtime.wasmtime_context_add_fuel(store.context, Cint(fuel))
    check_error(error_ptr)
    return UInt64(fuel)  # Return as UInt64 for consistency
end

function fuel_consumed(store::Store)
    isvalid(store) || throw(WasmtimeError("Invalid store"))
    fuel_ref = Ref{Cint}()
    success = LibWasmtime.wasmtime_context_fuel_consumed(store.context, fuel_ref)
    if success == 0
        throw(WasmtimeError("Fuel consumption tracking not enabled"))
    end
    return UInt64(fuel_ref[])  # Return as UInt64 for consistency
end

# Epoch management
function set_epoch_deadline!(store::Store, ticks_beyond_current::UInt64)
    isvalid(store) || throw(WasmtimeError("Invalid store"))
    LibWasmtime.wasmtime_context_set_epoch_deadline(store.context, ticks_beyond_current)
    return store
end

# Convenience method for Int64 input
function set_epoch_deadline!(store::Store, ticks_beyond_current::Integer)
    set_epoch_deadline!(store, UInt64(ticks_beyond_current))
end
