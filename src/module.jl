# Module implementation for WasmtimeRuntime

# Module implementation
mutable struct WasmModule <: AbstractModule
    ptr::Ptr{LibWasmtime.wasmtime_module_t}
    engine::Engine

    function WasmModule(engine::Engine, wasm_bytes::Vector{UInt8})
        isvalid(engine) || throw(WasmtimeError("Invalid engine"))

        # Validate WebAssembly bytes first
        validate(engine, wasm_bytes) || throw(WasmtimeError("Invalid WebAssembly module"))

        ptr_ref = Ref{Ptr{LibWasmtime.wasmtime_module_t}}()
        error_ptr = LibWasmtime.wasmtime_module_new(
            engine.ptr,
            pointer(wasm_bytes),
            length(wasm_bytes),
            ptr_ref,
        )

        check_error(error_ptr)

        module_obj = new(ptr_ref[], engine)
        finalizer(module_obj) do m
            if m.ptr != C_NULL
                LibWasmtime.wasmtime_module_delete(m.ptr)
                m.ptr = C_NULL
            end
        end

        return module_obj
    end
end

Base.isvalid(module_obj::WasmModule) = module_obj.ptr != C_NULL

# Multiple ways to create modules
WasmModule(engine::Engine, path::AbstractString) = WasmModule(engine, read(path))

function WasmModule(engine::Engine, wat::AbstractString, ::Val{:wat})
    wasm_bytes = wat_to_wasm(wat)
    WasmModule(engine, wasm_bytes)
end

# Validation function
function validate(engine::Engine, wasm_bytes::Vector{UInt8})::Bool
    # Check for invalid engine first
    if !isvalid(engine)
        return false
    end

    # Check for empty bytes - this is not a valid WASM module
    if isempty(wasm_bytes)
        return false
    end

    try
        error_ptr = LibWasmtime.wasmtime_module_validate(
            engine.ptr,
            pointer(wasm_bytes),
            length(wasm_bytes),
        )
        # wasmtime_module_validate returns NULL on success, error pointer on failure
        return error_ptr == C_NULL
    catch
        return false
    end
end

# WAT to WASM conversion (placeholder)
function wat_to_wasm(wat::AbstractString)::Vector{UInt8}
    # This is a placeholder
    # For now, assume the input is already WASM bytes
    throw(WasmtimeError("WAT to WASM conversion not yet implemented"))
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
