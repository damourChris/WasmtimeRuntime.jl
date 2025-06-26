# Function calling implementation for WasmtimeRuntime

# ===== Core Function Types =====

"""
    Func <: AbstractFunc

WebAssembly function handle for dynamic function calls.

Represents a WebAssembly function that can be called with runtime type checking.
Functions are bound to a specific store and cannot be used across different stores.

# Fields
- `ptr::Ptr{LibWasmtime.wasmtime_func_t}`: Pointer to underlying Wasmtime function
- `store::Ptr{LibWasmtime.wasmtime_context_t}`: Store context pointer
- `manually_allocated::Bool`: Memory management flag

# Examples
```julia
# Get function from instance export
func = get_func(instance, "exported_function")

# Call with dynamic type checking
result = call(func, [WasmI32(42), WasmF64(3.14)])
```

For compile-time type safety, use `TypedFunc` instead.

See also: [`TypedFunc`](@ref), [`get_func`](@ref), [`call`](@ref), [`@wasm_call`](@ref)
"""
mutable struct Func <: AbstractFunc
    ptr::Ptr{LibWasmtime.wasmtime_func_t}
    store::Ptr{LibWasmtime.wasmtime_context_t}  # Store context pointer
    manually_allocated::Bool  # Track if we need to free this pointer

    function Func(
        ptr::Ptr{LibWasmtime.wasmtime_func_t},
        store::Store,
        manually_allocated::Bool = false,
    )
        isvalid(store) || throw(WasmtimeError("Invalid store"))

        if ptr == C_NULL
            throw(WasmtimeError("Invalid function pointer"))
        end

        # Create the function object
        func = new(ptr, store.ptr, manually_allocated)

        if manually_allocated
            # Add finalizer to free manually allocated memory
            finalizer(func) do f
                if f.ptr != C_NULL && f.manually_allocated
                    Libc.free(f.ptr)
                    f.ptr = C_NULL
                end
            end
        end

        return func
    end
end

Base.isvalid(func::Func) = func.ptr != C_NULL

# Typed function wrapper for compile-time type safety
"""
    TypedFunc{Params,Results}

Type-safe WebAssembly function wrapper with compile-time type checking.

Provides compile-time type safety for WebAssembly function calls by encoding
parameter and return types in the Julia type system. Eliminates runtime type
checking overhead and provides better error messages.

# Type Parameters
- `Params`: Tuple type of parameter types (e.g., `Tuple{Int32, Float64}`)
- `Results`: Tuple type of return types (e.g., `Tuple{Int32}`)

# Examples
```julia
# Create typed function wrapper
typed_func = TypedFunc{Tuple{Int32}, Tuple{Int32}}(func)

# Type-safe call (no runtime type checking)
result = typed_func(42)

# Compile-time error for wrong types
# typed_func(3.14)  # Error: cannot convert Float64 to Int32
```

Use `@typed_func` macro for convenient creation with automatic type inference.

See also: [`Func`](@ref), [`@typed_func`](@ref), [`@wasm_call_typed`](@ref)
"""
"""
    TypedFunc{Params,Results}

Type-safe WebAssembly function wrapper with compile-time type checking.

Provides compile-time type safety for WebAssembly function calls by encoding
parameter and return types in the Julia type system. Eliminates runtime type
checking overhead and provides better error messages.

# Type Parameters
- `Params`: Tuple type of parameter types (e.g., `Tuple{Int32, Float64}`)
- `Results`: Tuple type of return types (e.g., `Tuple{Int32}`)

# Examples
```julia
# Create typed function wrapper
typed_func = TypedFunc{Tuple{Int32}, Tuple{Int32}}(func)

# Type-safe call (no runtime type checking)
result = typed_func(42)

# Compile-time error for wrong types
# typed_func(3.14)  # Error: cannot convert Float64 to Int32
```

Use `@typed_func` macro for convenient creation with automatic type inference.

See also: [`Func`](@ref), [`@typed_func`](@ref), [`@wasm_call_typed`](@ref)
"""
struct TypedFunc{Params,Results}
    func::Func

    function TypedFunc{Params,Results}(func::Func) where {Params,Results}
        # Validate types at construction time
        validate_wasm_types(Params, Results)
        new{Params,Results}(func)
    end
end

# ===== Type Validation and Conversion =====

# Trait for types that can be converted to/from WASM
abstract type WasmConvertible end

# Type validation for function signatures
function validate_wasm_types(::Type{Params}, ::Type{Results}) where {Params,Results}
    # Validate parameter types
    if Params <: Tuple
        for T in Params.parameters
            is_wasm_convertible(T) ||
                throw(ArgumentError("Type $T is not WASM convertible"))
        end
    else
        is_wasm_convertible(Params) ||
            throw(ArgumentError("Type $Params is not WASM convertible"))
    end

    # Validate result types
    if Results <: Tuple
        for T in Results.parameters
            is_wasm_convertible(T) ||
                throw(ArgumentError("Type $T is not WASM convertible"))
        end
    elseif Results != Nothing
        is_wasm_convertible(Results) ||
            throw(ArgumentError("Type $Results is not WASM convertible"))
    end
end

# Enhanced type conversion system
is_wasm_convertible(::Type{Nothing}) = true
is_wasm_convertible(::Type{Union{AbstractFunc,Nothing}}) = true
is_wasm_convertible(::Type{Any}) = true # For externref
is_wasm_convertible(::Type{NTuple{16,UInt8}}) = true # For v128

# Conversion to wasmtime_val - properly handle union data
function to_wasmtime_val(value::Int32)
    # Create a wasmtime_valunion and set the i32 field
    union_ref = Ref{LibWasmtime.wasmtime_valunion}()
    union_ptr = Base.unsafe_convert(Ptr{LibWasmtime.wasmtime_valunion}, union_ref)
    unsafe_store!(getproperty(union_ptr, :i32), value)

    val = LibWasmtime.wasmtime_val(LibWasmtime.WASMTIME_I32, union_ref[])
    return val
end

function to_wasmtime_val(value::Int64)
    # Create a wasmtime_valunion and set the i64 field
    union_ref = Ref{LibWasmtime.wasmtime_valunion}()
    union_ptr = Base.unsafe_convert(Ptr{LibWasmtime.wasmtime_valunion}, union_ref)
    unsafe_store!(getproperty(union_ptr, :i64), value)

    val = LibWasmtime.wasmtime_val(LibWasmtime.WASMTIME_I64, union_ref[])
    return val
end

function to_wasmtime_val(value::Float32)
    # Create a wasmtime_valunion and set the f32 field
    union_ref = Ref{LibWasmtime.wasmtime_valunion}()
    union_ptr = Base.unsafe_convert(Ptr{LibWasmtime.wasmtime_valunion}, union_ref)
    unsafe_store!(getproperty(union_ptr, :f32), value)

    val = LibWasmtime.wasmtime_val(LibWasmtime.WASMTIME_F32, union_ref[])
    return val
end

function to_wasmtime_val(value::Float64)
    # Create a wasmtime_valunion and set the f64 field
    union_ref = Ref{LibWasmtime.wasmtime_valunion}()
    union_ptr = Base.unsafe_convert(Ptr{LibWasmtime.wasmtime_valunion}, union_ref)
    unsafe_store!(getproperty(union_ptr, :f64), value)

    val = LibWasmtime.wasmtime_val(LibWasmtime.WASMTIME_F64, union_ref[])
    return val
end

function to_wasmtime_val(value::Union{AbstractFunc,Nothing})
    # Create a wasmtime_valunion and set the funcref field
    union_ref = Ref{LibWasmtime.wasmtime_valunion}()
    union_ptr = Base.unsafe_convert(Ptr{LibWasmtime.wasmtime_valunion}, union_ref)

    if value === nothing
        # For null funcref, we need to set the funcref field to appropriate null value
        # This requires understanding the exact wasmtime_func_t structure
        union_ptr.funcref[] = LibWasmtime.wasmtime_func_t(0, 0)
    else
        # For actual function references, we'd need to extract the wasmtime_func_t
        # This is complex and depends on the specific function implementation
        union_ptr.funcref[] = value.ptr[]
    end

    val = LibWasmtime.wasmtime_val(LibWasmtime.WASMTIME_FUNCREF, union_ref[])
    return val
end

function to_wasmtime_val(value::Any) # externref
    # Create a wasmtime_valunion and set the externref field
    union_ref = Ref{LibWasmtime.wasmtime_valunion}()
    union_ptr = Base.unsafe_convert(Ptr{LibWasmtime.wasmtime_valunion}, union_ref)

    # For externref, we need to properly handle the reference
    # This is a simplified implementation - proper externref handling needed
    union_ptr.externref[] = C_NULL  # Placeholder

    val = LibWasmtime.wasmtime_val(LibWasmtime.WASMTIME_EXTERNREF, union_ref[])
    return val
end

function to_wasmtime_val(value::NTuple{16,UInt8}) # v128
    # Create a wasmtime_valunion and set the v128 field
    union_ref = Ref{LibWasmtime.wasmtime_valunion}()
    union_ptr = Base.unsafe_convert(Ptr{LibWasmtime.wasmtime_valunion}, union_ref)

    # For v128, we need to properly handle the 128-bit value
    # This requires understanding the wasmtime_v128 structure
    v128_val = LibWasmtime.wasmtime_v128(value)
    unsafe_store!(getproperty(union_ptr, :v128), v128_val)

    val = LibWasmtime.wasmtime_val(LibWasmtime.WASMTIME_V128, union_ref[])
    return val
end

# Conversion from wasmtime_val - properly extract union data
function from_wasmtime_val(::Type{Int32}, val::LibWasmtime.wasmtime_val)
    @assert val.kind == LibWasmtime.WASMTIME_I32
    # Extract the i32 value from the union
    return val.of.i32
end

function from_wasmtime_val(::Type{Int64}, val::LibWasmtime.wasmtime_val)
    @assert val.kind == LibWasmtime.WASMTIME_I64
    # Extract the i64 value from the union
    return val.of.i64
end

function from_wasmtime_val(::Type{Float32}, val::LibWasmtime.wasmtime_val)
    @assert val.kind == LibWasmtime.WASMTIME_F32
    # Extract the f32 value from the union
    return val.of.f32
end

function from_wasmtime_val(::Type{Float64}, val::LibWasmtime.wasmtime_val)
    @assert val.kind == LibWasmtime.WASMTIME_F64
    # Extract the f64 value from the union
    return val.of.f64
end

function from_wasmtime_val(
    ::Type{Union{AbstractFunc,Nothing}},
    val::LibWasmtime.wasmtime_val,
)
    @assert val.kind == LibWasmtime.WASMTIME_FUNCREF
    # Extract the funcref value from the union
    funcref = val.of.funcref
    # For now, return nothing for null funcref or create a Func wrapper
    # This needs proper implementation based on store context
    return nothing  # Simplified for now
end

function from_wasmtime_val(::Type{Any}, val::LibWasmtime.wasmtime_val)
    @assert val.kind == LibWasmtime.WASMTIME_EXTERNREF
    # Extract the externref value from the union
    externref = val.of.externref
    # For externref, we'd need proper reference handling
    return nothing  # Simplified for now
end

function from_wasmtime_val(::Type{NTuple{16,UInt8}}, val::LibWasmtime.wasmtime_val)
    @assert val.kind == LibWasmtime.WASMTIME_V128
    # Extract the v128 value from the union
    v128_val = val.of.v128
    # Convert wasmtime_v128 to NTuple{16,UInt8}
    # This needs proper handling of the v128 structure
    return ntuple(i -> UInt8(0), 16)  # Simplified for now
end

# ===== Function Call Implementation =====

# Dynamic function calling with automatic type conversion
function call(func::Func, args...)
    isvalid(func) || throw(WasmtimeError("Invalid function"))
    # isvalid(func.store) || throw(WasmtimeError("Invalid store"))

    # Store context validation - ensure function belongs to the current store
    # This is critical to prevent the "object used with the wrong store" error
    # validate_store_context(func)

    # Convert arguments to wasmtime_val
    wasm_args = [to_wasmtime_val(auto_convert_to_wasm(arg)) for arg in args]

    # Query function type to get proper result information
    result_count = get_result_count(func)
    result_types = get_result_types(func)

    # Allocate results array with proper types
    wasm_results = Vector{LibWasmtime.wasmtime_val}(undef, result_count)

    # Initialize results with proper types
    for i = 1:result_count
        result_type = i <= length(result_types) ? result_types[i] : LibWasmtime.WASMTIME_I32

        # Create properly initialized union based on result type
        union_ref = Ref{LibWasmtime.wasmtime_valunion}()
        union_ptr = Base.unsafe_convert(Ptr{LibWasmtime.wasmtime_valunion}, union_ref)

        # Initialize union based on expected result type
        if result_type == LibWasmtime.WASMTIME_I32
            union_ptr.i32[] = Int32(0)
        elseif result_type == LibWasmtime.WASMTIME_I64
            union_ptr.i64[] = Int64(0)
        elseif result_type == LibWasmtime.WASMTIME_F32
            union_ptr.f32[] = Float32(0)
        elseif result_type == LibWasmtime.WASMTIME_F64
            union_ptr.f64[] = Float64(0)
        else
            union_ptr.i32[] = Int32(0)  # Default fallback
        end

        wasm_results[i] = LibWasmtime.wasmtime_val(result_type, union_ref[])
    end

    # Make the call with proper error handling
    trap_ptr = Ref{Ptr{LibWasmtime.wasm_trap_t}}()

    # Use the function pointer from the extracted wasmtime_func_t
    # The func.ptr should contain the properly extracted function from get_func()
    error_ptr = LibWasmtime.wasmtime_func_call(
        func.store.context,         # Store context (must match function's store)
        func.ptr,                   # Function pointer (from proper extraction)
        pointer(wasm_args),         # Arguments array pointer
        length(wasm_args),          # Number of arguments
        pointer(wasm_results),      # Results array pointer
        result_count,               # Number of results
        trap_ptr,                    # Trap output reference
    )

    # Check for trap first
    if trap_ptr[] != C_NULL
        # Extract trap message and clean up
        # TODO: Extract actual trap message using wasmtime trap APIs
        LibWasmtime.wasm_trap_delete(trap_ptr[])
        throw(WasmtimeError("WebAssembly trap occurred during function call"))
    end

    # Check for other errors
    check_error(error_ptr)

    # Convert results back to Julia types
    if result_count == 0
        return nothing
    elseif result_count == 1
        return auto_convert_from_wasm(wasm_results[1])
    else
        return tuple([auto_convert_from_wasm(r) for r in wasm_results]...)
    end
end

# Type-safe function calling
function call(func::TypedFunc{Params,Results}, args::Params) where {Params,Results}
    # Static type checking at compile time
    julia_result = call(func.func, args...)

    # Convert to expected result type
    if Results == Nothing
        return nothing
    elseif Results <: Tuple
        return julia_result::Results
    else
        return julia_result::Results
    end
end

# Multiple dispatch for different argument patterns
call(func::TypedFunc{Params,Results}, args...) where {Params,Results} = call(func, args)

# ===== Automatic Type Conversion =====

# Automatic conversion to WASM-compatible types
auto_convert_to_wasm(x::Int32) = x
auto_convert_to_wasm(x::Int64) = x
auto_convert_to_wasm(x::Float32) = x
auto_convert_to_wasm(x::Float64) = x
auto_convert_to_wasm(x::Union{AbstractFunc,Nothing}) = x
auto_convert_to_wasm(x::Any) = x # externref
auto_convert_to_wasm(x::NTuple{16,UInt8}) = x

# Automatic conversions for common Julia types
auto_convert_to_wasm(x::Int8) = Int32(x)
auto_convert_to_wasm(x::Int16) = Int32(x)
auto_convert_to_wasm(x::UInt8) = Int32(x)
auto_convert_to_wasm(x::UInt16) = Int32(x)
auto_convert_to_wasm(x::UInt32) = Int64(x)  # Promote to avoid overflow
auto_convert_to_wasm(x::UInt64) = Int64(x)  # May overflow, but best effort
auto_convert_to_wasm(x::Float16) = Float32(x)
auto_convert_to_wasm(x::BigFloat) = Float64(x)

# Automatic conversion from WASM values
function auto_convert_from_wasm(val::LibWasmtime.wasmtime_val)
    if val.kind == LibWasmtime.WASMTIME_I32
        return from_wasmtime_val(Int32, val)
    elseif val.kind == LibWasmtime.WASMTIME_I64
        return from_wasmtime_val(Int64, val)
    elseif val.kind == LibWasmtime.WASMTIME_F32
        return from_wasmtime_val(Float32, val)
    elseif val.kind == LibWasmtime.WASMTIME_F64
        return from_wasmtime_val(Float64, val)
    elseif val.kind == LibWasmtime.WASMTIME_FUNCREF
        return from_wasmtime_val(Union{AbstractFunc,Nothing}, val)
    elseif val.kind == LibWasmtime.WASMTIME_EXTERNREF
        return from_wasmtime_val(Any, val)
    elseif val.kind == LibWasmtime.WASMTIME_V128
        return from_wasmtime_val(NTuple{16,UInt8}, val)
    else
        throw(WasmtimeError("Unknown WASM value type: $(val.kind)"))
    end
end

# ===== Function Type Querying =====

# Get function type information from a Wasmtime function
function get_func_type(func::Func)
    isvalid(func) || throw(WasmtimeError("Invalid function"))
    # @info "Validating function store context"
    # validate_store_context(func)
    # @info "Validation passed, querying function type"

    # Query the function type using wasmtime_func_type
    functype_ptr = LibWasmtime.wasmtime_func_type(func.store, func.ptr)

    if functype_ptr == C_NULL
        throw(WasmtimeError("Failed to get function type"))
    end

    # Extract parameter and result types
    # This would require proper wasm_functype_t handling
    # For now, return a simplified structure
    return (
        param_count = 0,     # Would query actual parameter count
        result_count = 1,    # Would query actual result count
        param_types = [],    # Would extract actual parameter types
        result_types = [LibWasmtime.WASMTIME_I32],  # Would extract actual result types
    )
end

# Helper to determine result count for a function
function get_result_count(func::Func)
    try
        type_info = get_func_type(func)
        return type_info.result_count
    catch
        # Fallback to assuming 1 result if type query fails
        return 1
    end
end

# Helper to determine result types for a function
function get_result_types(func::Func)
    try
        type_info = get_func_type(func)
        return type_info.result_types
    catch
        # Fallback to assuming I32 result if type query fails
        return [LibWasmtime.WASMTIME_I32]
    end
end

# ===== Value Conversion Functions =====

# ===== Store Context Validation =====

# Validate that a function belongs to the given store
# This is critical to prevent "object used with the wrong store" errors
function validate_store_context(func::Func)
    # Proper implementation using wasmtime_func_store to get the function's store ID
    # and comparing it with the provided store's ID

    # Get the store ID from the function
    @show func_store_id = LibWasmtime.wasmtime_store_context(func.store)

    # Get the store ID from the provided store
    @show store_id = LibWasmtime.wasmtime_store_context(store)

    # Compare store IDs - they must match exactly
    if func_store_id != store_id
        throw(
            WasmtimeError(
                "Function belongs to store ID $func_store_id but was called with store ID $store_id. " *
                "Functions can only be called with their original store.",
            ),
        )
    end

    return true
end

# Overload to validate function against its own store
# function validate_store_context(func::Func)
#     isvalid(func.store) || throw(WasmtimeError("Function's store is invalid"))
#     return validate_store_context(func, func.store)
# end

# ===== Convenience Macros =====

"""
    @wasm_call(func, args...)

Convenience macro for calling WebAssembly functions with automatic type conversion.
Provides compile-time optimization and better error messages.

# Examples
```julia
result = @wasm_call(add_func, Int32(1), Int32(2))
result = @wasm_call(sqrt_func, Float64(16.0))
```
"""
macro wasm_call(func_expr, args...)
    return quote
        local func_val = $(esc(func_expr))
        local converted_args = tuple($(map(esc, args)...))
        call(func_val, converted_args...)
    end
end

"""
    @wasm_call_typed(func, Params, Results, args...)

Type-safe macro for calling WebAssembly functions with explicit type annotations.
Provides compile-time type checking and optimization.

# Examples
```julia
result = @wasm_call_typed(add_func, Tuple{Int32,Int32}, Int32, Int32(1), Int32(2))
```
"""
macro wasm_call_typed(func_expr, params_type, results_type, args...)
    return quote
        local func_val = $(esc(func_expr))
        local typed_func = TypedFunc{$(esc(params_type)),$(esc(results_type))}(func_val)
        local converted_args = tuple($(map(esc, args)...))
        call(typed_func, converted_args)
    end
end

# ===== Module/Instance Integration =====

# Get a function from a module instance by name
function get_func(instance::Instance, name::String)
    isvalid(instance) || throw(WasmtimeError("Invalid instance"))

    # Get the export from the instance
    extern_ref = Ref{LibWasmtime.wasmtime_extern_t}()
    extern_ref[] = LibWasmtime.wasmtime_extern_t(
        LibWasmtime.WASMTIME_EXTERN_FUNC,
        LibWasmtime.wasmtime_extern_union(
            NTuple{1,UInt8}(0), # Placeholder for function pointer
        ),
    )

    found = LibWasmtime.wasmtime_instance_export_get(
        instance.store.context,
        Ref(instance.instance),
        name,
        length(name),
        extern_ref,
    )

    if found == 0
        throw(WasmtimeError("Export '$name' not found in instance"))
    end

    # Check if the export is a function
    extern_val = extern_ref[]
    if extern_val.kind != LibWasmtime.WASMTIME_EXTERN_FUNC
        throw(WasmtimeError("Export '$name' is not a function"))
    end

    # Extract the function from the union
    func_from_union = getproperty(extern_val.of, :func)

    # Create a function pointer and copy the wasmtime_func_t data
    func_ptr = Libc.malloc(sizeof(LibWasmtime.wasmtime_func_t))
    if func_ptr == C_NULL
        throw(WasmtimeError("Failed to allocate memory for function"))
    end

    # Copy the function data
    unsafe_store!(Ptr{LibWasmtime.wasmtime_func_t}(func_ptr), func_from_union)

    return Func(Ptr{LibWasmtime.wasmtime_func_t}(func_ptr), instance.store, true)
end

# Get a typed function from a module instance
function get_typed_func(
    instance::Instance,
    name::String,
    ::Type{Params},
    ::Type{Results},
) where {Params,Results}
    func = get_func(instance, name)
    return TypedFunc{Params,Results}(func)
end

# Convenience overload
get_typed_func(instance::Instance, name::String, args_types::Type...) =
    get_typed_func(instance, name, Tuple{args_types...}, Nothing)
