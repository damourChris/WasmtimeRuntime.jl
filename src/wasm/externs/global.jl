"""
    WasmGlobalType(valtype::WasmValtype, mutability::Bool) -> WasmGlobalType

WebAssembly global type descriptor that defines the type and mutability of a global variable.

# Arguments
- `valtype::WasmValtype`: The value type (Int32, Int64, Float32, Float64)
- `mutability::Bool`: true for mutable globals, false for immutable globals

# Examples
```julia
# Create a mutable Int32 global type
valtype = WasmValType(Int32)
global_type = WasmGlobalType(valtype, true)

# Create an immutable Float64 global type
valtype = WasmValType(Float64)
global_type = WasmGlobalType(valtype, false)
```
"""
mutable struct WasmGlobalType
    ptr::Ptr{LibWasmtime.wasm_globaltype_t}

    function WasmGlobalType(valtype::WasmValType, mutability::Bool)
        if !isvalid(valtype)
            throw(ArgumentError("Invalid WasmValtype"))
        end

        globaltype_ptr = LibWasmtime.wasm_globaltype_new(
            valtype,
            mutability ? LibWasmtime.WASM_CONST : LibWasmtime.WASM_VAR,
        )

        if globaltype_ptr == C_NULL
            throw(ArgumentError("Failed to create WasmGlobalType"))
        end

        globaltype = new(globaltype_ptr)
        finalizer(globaltype) do gt
            if gt.ptr != C_NULL
                LibWasmtime.wasm_globaltype_delete(gt.ptr)
                gt.ptr = C_NULL
            end
        end

        return globaltype
    end

end

Base.unsafe_convert(
    ::Type{Ptr{LibWasmtime.wasm_globaltype_t}},
    globaltype::WasmGlobalType,
) = globaltype.ptr
Base.show(io::IO, globaltype::WasmGlobalType) = print(io, "WasmGlobalType()")
Base.isvalid(globaltype::WasmGlobalType) = globaltype.ptr != C_NULL

"""
    WasmGlobal(store::WasmStore, global_type::WasmGlobalType, initial_value::WasmValue) -> WasmGlobal

WebAssembly global variable that can hold a single value of a specific type.

Global variables can be either mutable or immutable as defined by their type.
They maintain their value throughout the lifetime of a WebAssembly instance.

# Arguments
- `store::WasmStore`: The store that owns this global
- `global_type::WasmGlobalType`: Type descriptor defining value type and mutability
- `initial_value::WasmValue`: Initial value for the global variable

# Examples
```julia
engine = WasmEngine()
store = WasmStore(engine)

# Create a mutable Int32 global
valtype = WasmValType(Int32)
global_type = WasmGlobalType(valtype, true)  # mutable
global_var = WasmGlobal(store, global_type, WasmValue(Int32(42)))

# Create an immutable Float64 global
valtype = WasmValType(Float64)
global_type = WasmGlobalType(valtype, false)  # immutable
global_var = WasmGlobal(store, global_type, WasmValue(3.14159))
```
"""
mutable struct WasmGlobal
    ptr::Ptr{LibWasmtime.wasm_global_t}
end

function WasmGlobal(
    store::WasmStore,
    global_type::WasmGlobalType,
    initial_value::wasm_val_t,
)
    if !isvalid(store) || !isvalid(global_type)
        throw(ArgumentError("Invalid store or global type"))
    end

    @assert initial_value != C_NULL "Initial value must not be null"
    # if !isvalid(initial_value)
    #     throw(ArgumentError("Invalid initial value for global"))
    # end

    global_ptr = LibWasmtime.wasm_global_new(store, global_type, Ref(initial_value))

    if global_ptr == C_NULL
        throw(ArgumentError("Failed to create WasmGlobal"))
    end

    global_ = WasmGlobal(global_ptr)

    finalizer(global_) do g
        if g.ptr != C_NULL
            LibWasmtime.wasm_global_delete(g.ptr)
            g.ptr = C_NULL
        end
    end

    return global_
end

Base.unsafe_convert(::Type{Ptr{LibWasmtime.wasm_global_t}}, global_::WasmGlobal) =
    global_.ptr
Base.show(io::IO, global_::WasmGlobal) = print(io, "WasmGlobal()")
Base.isvalid(global_::WasmGlobal) = global_.ptr != C_NULL
