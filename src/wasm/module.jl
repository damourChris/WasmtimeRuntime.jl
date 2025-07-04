# Module implementation for WasmtimeRuntime

# Module implementation
mutable struct WasmModule <: AbstractModule
    ptr::Ptr{LibWasmtime.wasm_module_t}
    store::WasmStore

    function WasmModule(store::WasmStore, wasm_bytes::WasmByteVec)

        # Create the module using the wasm C API
        module_ptr = LibWasmtime.wasm_module_new(store.ptr, wasm_bytes)

        if module_ptr == C_NULL
            throw(WasmtimeError("Failed to create WebAssembly module"))
        end

        module_obj = new(module_ptr, store)
        finalizer(module_obj) do m
            if m.ptr != C_NULL
                LibWasmtime.wasm_module_delete(m.ptr)
                m.ptr = C_NULL
            end
        end

        return module_obj
    end
end

Base.isvalid(module_obj::WasmModule) = module_obj.ptr != C_NULL
Base.unsafe_convert(::Type{Ptr{LibWasmtime.wasm_module_t}}, module_obj::WasmModule) =
    module_obj.ptr
Base.show(io::IO, module_obj::WasmModule) = print(io, "WasmModule()")

function WasmModule(store::WasmStore, wat::AbstractString)
    wasm_bytes = wat_to_wasm(wat)
    WasmModule(store, wasm_bytes)
end

# Validation function
function validate(store::WasmStore, wasm_bytes::Vector{UInt8})::Bool
    # Check for invalid store first
    if !isvalid(store)
        return false
    end

    # Check for empty bytes - this is not a valid WASM module
    if isempty(wasm_bytes)
        return false
    end

    try
        # Create a WasmByteVec from the bytes
        byte_vec = WasmByteVec(wasm_bytes)

        # wasm_module_validate returns 1 on success, 0 on failure
        result = LibWasmtime.wasm_module_validate(store.ptr, byte_vec)
        return result != 0
    catch
        return false
    end
end

function validate(module_obj::WasmModule, wasm_bytes::Vector{UInt8})::Bool
    isvalid(module_obj) || throw(WasmtimeError("Invalid module"))

    # Validate the module using the store's wasm_ptr
    return validate(module_obj.store, module_obj.wasm_bytes)
end

# Module introspection functions
function exports(module_obj::WasmModule)
    isvalid(module_obj) || throw(WasmtimeError("Invalid module"))

    # Initialize the vector properly - allocate it on the stack
    exports_vec = Ref(LibWasmtime.wasm_exporttype_vec_t(C_NULL, 0))
    LibWasmtime.wasm_module_exports(module_obj.ptr, exports_vec)

    # TODO: Process exports and return structured data
    # For now, return empty dict as placeholder
    return Dict{String,Any}()
end

function imports(module_obj::WasmModule)
    isvalid(module_obj) || throw(WasmtimeError("Invalid module"))

    # Initialize the vector properly - allocate it on the stack
    imports_vec = Ref(LibWasmtime.wasm_importtype_vec_t(C_NULL, 0))
    LibWasmtime.wasm_module_imports(module_obj.ptr, imports_vec)

    # TODO: Process imports and return structured data
    # For now, return empty dict as placeholder
    return Dict{String,Any}()
end
