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

function exports(instance::WasmInstance)
    isvalid(instance) || throw(WasmtimeError("Invalid instance"))

    exports_vec = WasmExternVec()
    LibWasmtime.wasm_instance_exports(instance, exports_vec)

    # Preallocate a vector WasmExtern
    extern_vec = Vector{WasmExtern}(undef, length(exports_vec))

    # Turn the externs in a vector of original extern types
    for (i, extern) in enumerate(exports_vec)
        # Copy the extern to ensure we own it
        extern = LibWasmtime.wasm_extern_copy(extern)
        extern_vec[i] = WasmExtern(unwrap_extern(extern))
    end

    # Get the instance's module exports

    module_exports = exports(instance.module_)

    # Create WasmModuleExport objects for each export
    exports_dict = Dict{Symbol,WasmInstanceExport}()
    for (i, (export_name, _)) in enumerate(module_exports)
        exports_dict[Symbol(export_name)] = WasmInstanceExport(export_name, extern_vec[i])
    end

    return exports_dict
end
