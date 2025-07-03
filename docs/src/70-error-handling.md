# Error Handling

WasmtimeRuntime.jl provides comprehensive error handling for WebAssembly operations. This guide covers error types, handling patterns, and debugging strategies.

## Error Types

### WasmtimeError

The primary exception type for WebAssembly-related errors:

```julia
struct WasmtimeError <: Exception
    message::String
end
```

All WebAssembly operations that can fail throw `WasmtimeError` with descriptive messages.

### Common Error Categories

#### Configuration Errors

```julia
try
    config = Config()
    config.ptr = C_NULL  # Simulate invalid config
    engine = Engine(config)
catch e::WasmtimeError
    println("Configuration error: $(e.message)")
end
```

#### Module Errors

```julia
try
    # Invalid WebAssembly bytes
    invalid_bytes = UInt8[0x00, 0x00, 0x00, 0x00]
    module_obj = WasmModule(engine, invalid_bytes)
catch e::WasmtimeError
    println("Module compilation error: $(e.message)")
end
```

#### Instance Errors

```julia
try
    # Invalid store
    store.ptr = C_NULL
    instance = Instance(store, module_obj)
catch e::WasmtimeError
    println("Instantiation error: $(e.message)")
end
```

#### Function Call Errors

```julia
try
    # Wrong parameter count or type
    result = call(instance, "add", [42, 24, 33])  # Function expects 2 params
catch e::WasmtimeError
    println("Function call error: $(e.message)")
end
```

## Error Handling Patterns

### Basic Try-Catch

```julia
function safe_wasm_operation()
    try
        engine = Engine()
        store = Store(engine)
        module_obj = WasmModule(engine, wasm_bytes)
        instance = Instance(store, module_obj)
        result = call(instance, "main", [])
        return result
    catch e::WasmtimeError
        @error "WebAssembly operation failed" exception=e
        return nothing
    end
end
```

### Specific Error Handling

```julia
function handle_specific_errors()
    try
        result = call(instance, "divide", [10, 0])
        return result
    catch e::WasmtimeError
        if occursin("trap", lowercase(e.message))
            @warn "Division by zero trapped"
            return 0
        elseif occursin("type", lowercase(e.message))
            @error "Type mismatch in function call"
            rethrow(e)
        else
            @error "Unknown WebAssembly error" exception=e
            rethrow(e)
        end
    end
end
```

### Error Recovery Patterns

```julia
function retry_with_fallback(primary_func, fallback_func, max_retries=3)
    for attempt in 1:max_retries
        try
            return primary_func()
        catch e::WasmtimeError
            @warn "Attempt $attempt failed" exception=e

            if attempt == max_retries
                @info "Trying fallback function"
                try
                    return fallback_func()
                catch fallback_error::WasmtimeError
                    @error "Both primary and fallback failed"
                           primary=e fallback=fallback_error
                    rethrow(e)  # Rethrow original error
                end
            end

            sleep(0.1 * attempt)  # Exponential backoff
        end
    end
end
```

## Trap Handling

WebAssembly traps are runtime errors that occur during execution:

### Common Trap Scenarios

```julia
# Division by zero
try
    result = call(instance, "divide", [10, 0])
catch e::WasmtimeError
    if occursin("trap", lowercase(e.message))
        println("Trapped: Division by zero")
    end
end

# Out of bounds memory access
try
    result = call(instance, "read_memory", [1000000])  # Large offset
catch e::WasmtimeError
    if occursin("trap", lowercase(e.message)) && occursin("bounds", lowercase(e.message))
        println("Trapped: Memory access out of bounds")
    end
end

# Stack overflow
try
    result = call(instance, "recursive_function", [10000])  # Deep recursion
catch e::WasmtimeError
    if occursin("trap", lowercase(e.message)) && occursin("stack", lowercase(e.message))
        println("Trapped: Stack overflow")
    end
end
```

### Trap Recovery

```julia
function safe_wasm_call_with_trap_recovery(instance, func_name, params, default_value=nothing)
    try
        return call(instance, func_name, params)
    catch e::WasmtimeError
        if occursin("trap", lowercase(e.message))
            @warn "Function trapped, returning default value"
                  function=func_name params=params exception=e
            return default_value
        else
            # Re-throw non-trap errors
            rethrow(e)
        end
    end
end
```

## Resource Management Errors

### Store Lifecycle Errors

```julia
function handle_store_lifecycle()
    local store, instance

    try
        engine = Engine()
        store = Store(engine)
        module_obj = WasmModule(engine, wasm_bytes)
        instance = Instance(store, module_obj)

        # Use instance...
        result = call(instance, "main", [])

    catch e::WasmtimeError
        @error "Store operation failed" exception=e

        # Check if store is still valid
        if isdefined(@__MODULE__, :store) && !isvalid(store)
            @warn "Store became invalid during operation"
        end

        rethrow(e)
    finally
        # Cleanup is automatic via finalizers
        # Manual cleanup if needed
    end
end
```

### Memory Management Errors

```julia
function handle_memory_errors(instance)
    try
        # Attempt to access memory export
        memory_export = get_export(instance, "memory")

        # Future: Memory operations
        # data = read_memory(memory, offset, length)

    catch e::WasmtimeError
        if occursin("not found", e.message)
            @warn "Memory export not found, module may not export memory"
            return nothing
        elseif occursin("bounds", e.message)
            @error "Memory access out of bounds" exception=e
            return nothing
        else
            rethrow(e)
        end
    end
end
```

## Validation and Prevention

### Input Validation

```julia
function validate_inputs(engine, wasm_bytes, func_name, params)
    # Validate engine
    if !isvalid(engine)
        throw(ArgumentError("Invalid engine"))
    end

    # Validate WebAssembly bytes
    if isempty(wasm_bytes)
        throw(ArgumentError("Empty WebAssembly bytes"))
    end

    if !validate(engine, wasm_bytes)
        throw(ArgumentError("Invalid WebAssembly module"))
    end

    # Validate function name
    if isempty(func_name)
        throw(ArgumentError("Empty function name"))
    end

    # Validate parameters
    for (i, param) in enumerate(params)
        if !is_wasm_convertible(typeof(param))
            @warn "Parameter $i of type $(typeof(param)) may not be convertible to WebAssembly"
        end
    end

    return true
end
```

### Defensive Programming

```julia
function defensive_wasm_call(instance, func_name, params; timeout=5.0, max_fuel=10000)
    # Input validation
    if !isvalid(instance)
        throw(ArgumentError("Invalid instance"))
    end

    if !isvalid(instance.store)
        throw(ArgumentError("Invalid store"))
    end

    # Set up fuel limiting if available
    try
        add_fuel!(instance.store, max_fuel)
    catch e::WasmtimeError
        # Fuel not enabled, continue without it
        @debug "Fuel consumption not enabled"
    end

    # Timeout handling (conceptual - actual implementation would need threading)
    try
        # Future: Implement timeout via epoch interruption
        result = call(instance, func_name, params)
        return result
    catch e::WasmtimeError
        if occursin("fuel", lowercase(e.message))
            @error "Function execution exhausted fuel limit" limit=max_fuel
        elseif occursin("epoch", lowercase(e.message))
            @error "Function execution timed out" timeout=timeout
        end
        rethrow(e)
    end
end
```

## Error Reporting and Debugging

### Detailed Error Context

```julia
function detailed_error_report(e::WasmtimeError, context...)
    @error """
    WebAssembly Error Details:
    Message: $(e.message)
    Context: $(join(string.(context), ", "))
    Stack trace follows:
    """ exception=(e, catch_backtrace())
end

# Usage
try
    result = call(instance, "complex_function", [1, 2, 3])
catch e::WasmtimeError
    detailed_error_report(e, "complex_function", "params=[1,2,3]", "instance=$(instance)")
    rethrow(e)
end
```

### Error Aggregation

```julia
struct WasmtimeErrorCollector
    errors::Vector{Tuple{String, WasmtimeError}}
end

function collect_errors()
    return WasmtimeErrorCollector([])
end

function try_operation!(collector::WasmtimeErrorCollector, operation_name::String, f)
    try
        return f()
    catch e::WasmtimeError
        push!(collector.errors, (operation_name, e))
        return nothing
    end
end

function report_collected_errors(collector::WasmtimeErrorCollector)
    if !isempty(collector.errors)
        @error "Multiple WebAssembly errors occurred:"
        for (name, error) in collector.errors
            @error "  $name: $(error.message)"
        end
    end
end

# Usage
collector = collect_errors()
result1 = try_operation!(collector, "function1", () -> call(instance, "func1", []))
result2 = try_operation!(collector, "function2", () -> call(instance, "func2", []))
report_collected_errors(collector)
```

### Error Context Stack

```julia
mutable struct ErrorContext
    stack::Vector{String}
end

function push_context!(ctx::ErrorContext, description::String)
    push!(ctx.stack, description)
end

function pop_context!(ctx::ErrorContext)
    if !isempty(ctx.stack)
        pop!(ctx.stack)
    end
end

function with_error_context(f, ctx::ErrorContext, description::String)
    push_context!(ctx, description)
    try
        return f()
    catch e::WasmtimeError
        error_msg = "$(e.message)\nContext: $(join(reverse(ctx.stack), " → "))"
        rethrow(WasmtimeError(error_msg))
    finally
        pop_context!(ctx)
    end
end

# Usage
ctx = ErrorContext([])
try
    with_error_context(ctx, "Loading module") do
        module_obj = WasmModule(engine, wasm_bytes)

        with_error_context(ctx, "Creating instance") do
            instance = Instance(store, module_obj)

            with_error_context(ctx, "Calling main function") do
                call(instance, "main", [])
            end
        end
    end
catch e::WasmtimeError
    println("Error with context: $(e.message)")
end
```

## Best Practices

### Error Handling Strategy

1. **Be Specific**: Handle different error types appropriately
2. **Fail Fast**: Validate inputs early to catch errors sooner
3. **Provide Context**: Include relevant information in error messages
4. **Log Appropriately**: Use different log levels for different error severities
5. **Clean Recovery**: Ensure resources are cleaned up after errors

### Error Prevention

```julia
# Comprehensive safety wrapper
function safe_wasm_execution(;
    engine_config = nothing,
    wasm_source,
    function_name,
    parameters = [],
    fuel_limit = 10000,
    validate_inputs = true
)
    local engine, store, module_obj, instance

    try
        # Create engine with error handling
        engine = if engine_config === nothing
            Engine()
        else
            Engine(engine_config)
        end

        # Validate WebAssembly source
        wasm_bytes = if isa(wasm_source, String)
            if !isfile(wasm_source)
                throw(ArgumentError("WebAssembly file not found: $wasm_source"))
            end
            read(wasm_source)
        else
            wasm_source
        end

        if validate_inputs && !validate(engine, wasm_bytes)
            throw(ArgumentError("Invalid WebAssembly module"))
        end

        # Create store with fuel limiting
        store = Store(engine)
        try
            add_fuel!(store, fuel_limit)
        catch e::WasmtimeError
            @debug "Fuel limiting not available"
        end

        # Create module and instance
        module_obj = WasmModule(engine, wasm_bytes)
        instance = Instance(store, module_obj)

        # Execute function
        result = call(instance, function_name, parameters)

        return (result = result, success = true, error = nothing)

    catch e::Exception
        error_msg = if e isa WasmtimeError
            "WebAssembly error: $(e.message)"
        else
            "System error: $(string(e))"
        end

        @error error_msg exception=e
        return (result = nothing, success = false, error = e)
    end
end
```

### Testing Error Conditions

```julia
# Test error handling in your code
function test_error_handling()
    # Test invalid engine
    @test_throws WasmtimeError begin
        config = Config()
        config.ptr = C_NULL
        Engine(config)
    end

    # Test invalid module
    @test_throws WasmtimeError begin
        WasmModule(engine, UInt8[0x00, 0x00, 0x00, 0x00])
    end

    # Test function call with wrong parameters
    @test_throws WasmtimeError begin
        call(instance, "add", [])  # Missing parameters
    end
end
```

Robust error handling is essential for production WebAssembly applications. By following these patterns, you can build resilient systems that gracefully handle errors and provide meaningful feedback to users and developers.
