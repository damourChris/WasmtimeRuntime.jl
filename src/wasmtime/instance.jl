# Instance implementation for WasmtimeRuntime

# Instance implementation
mutable struct Instance <: AbstractInstance
    instance::LibWasmtime.wasmtime_instance_t
    store::Store
    module_obj::Module

    function Instance(store::Store, module_obj::Module, imports::Vector = [])
        isvalid(store) || throw(WasmtimeError("Invalid store"))
        isvalid(module_obj) || throw(WasmtimeError("Invalid module"))

        # Convert imports to wasmtime format (placeholder for now)
        # TODO: Implement proper import handling

        ptr_ref = Ref{Ptr{LibWasmtime.wasmtime_instance_t}}()
        trap_ptr = Ref{Ptr{LibWasmtime.wasm_trap_t}}()

        error_ptr = LibWasmtime.wasmtime_instance_new(
            store.context,
            module_obj.ptr,
            C_NULL,  # imports (empty for now)
            0,       # imports length
            ptr_ref,
            trap_ptr,
        )

        # Check for trap first
        if trap_ptr[] != C_NULL
            # TODO: Extract trap message
            LibWasmtime.wasm_trap_delete(trap_ptr[])
            throw(WasmtimeError("Trap occurred during instantiation"))
        end

        check_error(error_ptr)

        instance = new(ptr_ref[], store, module_obj)
        finalizer(instance) do i
            # Note: Instances are tied to the store lifecycle
            # No explicit delete needed
            i.ptr = C_NULL
        end

        return instance
    end
end

Base.isvalid(instance::Instance) = instance.ptr != C_NULL

# Convenience function for basic instantiation
instantiate(store::Store, module_obj::Module) = Instance(store, module_obj)
