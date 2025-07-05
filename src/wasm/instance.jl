mutable struct WasmInstance
    ptr::Ptr{wasm_instance_t}
    module_::WasmModule

    function WasmInstance(store::WasmStore, module_::WasmModule)
        # Validate store and module
        isvalid(store) || throw(WasmtimeError("Invalid store"))
        isvalid(module_) || throw(WasmtimeError("Invalid module"))

        empty_imports = WasmExternVec()

        trap_ptr = Ref{Ptr{LibWasmtime.wasm_trap_t}}(C_NULL)

        wasm_instance_ptr =
            LibWasmtime.wasm_instance_new(store, module_, empty_imports, trap_ptr)

        # Check for trap first
        if trap_ptr[] != C_NULL
            # Extract trap message and clean up
            # TODO: Extract actual trap message using wasmtime trap APIs
            LibWasmtime.wasm_trap_delete(trap_ptr[])
            throw(WasmtimeError("WebAssembly trap occurred during function call"))
        end


        @assert wasm_instance_ptr != C_NULL "Failed to create WASM instance"

        instance = new(wasm_instance_ptr, module_)

        finalizer(instance) do wasm_instance
            if wasm_instance.ptr != C_NULL
                LibWasmtime.wasm_instance_delete(wasm_instance.ptr)
                wasm_instance.ptr = C_NULL
            end
        end
    end
end

Base.show(io::IO, ::WasmInstance) = print(io, "WasmInstance()")
Base.unsafe_convert(::Type{Ptr{wasm_instance_t}}, instance::WasmInstance) = instance.ptr
Base.isvalid(instance::WasmInstance) = instance.ptr != C_NULL
