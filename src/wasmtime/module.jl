# Module implementation for WasmtimeRuntime

# Module implementation
mutable struct WasmtimeModule <: AbstractModule
    wasmtime_module_ptr::Ptr{LibWasmtime.wasmtime_module_t}

    function WasmtimeModule(engine::WasmEngine, wasm_bytes::Vector{UInt8})
        isvalid(engine) || throw(WasmtimeError("Invalid engine"))

        # Create a WasmByteVec from the bytes
        byte_vec = WasmByteVec(wasm_bytes)

        # Wasmtime_module_new expects a initialized pointer to pass to the C API
        module_ptr = Ref{Ptr{LibWasmtime.wasm_module_t}}(Ptr{wasmtime_module_t}())

        # Create the module using the wasm C API
        trap_ptr = GC.@preserve module_ptr LibWasmtime.wasmtime_module_new(
            engine,
            byte_vec,
            length(byte_vec),
            Base.pointer_from_objref(module_ptr),
        )

        check_error(trap_ptr)

        # Safety net - ensure we got a valid pointer
        if module_ptr == C_NULL
            throw(WasmtimeError("Failed to create WebAssembly module"))
        end

        module_obj = new(module_ptr)
        finalizer(module_obj) do m
            if m.ptr != C_NULL
                LibWasmtime.wasm_module_delete(m.ptr)
                m.ptr = C_NULL
            end
        end

        return module_obj
    end
end

Base.isvalid(module_obj::WasmtimeModule) = module_obj.ptr != C_NULL
Base.unsafe_convert(
    ::Type{Ptr{LibWasmtime.wasmtime_module_t}},
    module_obj::WasmtimeModule,
) = module_obj.wasmtime_module_ptr

# Module introspection functions
function exports(module_obj::WasmtimeModule)
    isvalid(module_obj) || throw(WasmtimeError("Invalid module"))

    # Initialize the vector properly - allocate it on the stack
    exports_vec = Ref(LibWasmtime.wasm_exporttype_vec_t(C_NULL, 0))
    LibWasmtime.wasm_module_exports(module_obj.ptr, exports_vec)

    # TODO: Process exports and return structured data
    # For now, return empty dict as placeholder
    return Dict{String,Any}()
end

function imports(module_obj::WasmtimeModule)
    isvalid(module_obj) || throw(WasmtimeError("Invalid module"))

    # Initialize the vector properly - allocate it on the stack
    imports_vec = Ref(LibWasmtime.wasm_importtype_vec_t(C_NULL, 0))
    LibWasmtime.wasm_module_imports(module_obj.ptr, imports_vec)

    # TODO: Process imports and return structured data
    # For now, return empty dict as placeholder
    return Dict{String,Any}()
end
