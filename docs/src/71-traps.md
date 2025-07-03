# WebAssembly Traps

WebAssembly traps are runtime exceptions that occur during WebAssembly execution when the program encounters an unrecoverable error. WasmtimeRuntime.jl provides the `WasmTrap` type to handle these exceptional conditions.

## WasmTrap Overview

`WasmTrap` represents a WebAssembly trap - a runtime error that immediately terminates execution of the WebAssembly program. Traps are distinct from regular Julia exceptions in that they originate from the WebAssembly runtime itself.

```julia
struct WasmTrap <: Exception
    ptr::Ptr{LibWasmtime.wasm_trap_t}
    msg::AbstractString
end
```

## Creating WasmTrap Instances

Traps are typically created automatically by the WebAssembly runtime, but you can also create them from existing trap pointers:

```julia
# From a C pointer (internal use)
# trap_ptr  <--- Assume this is a valid pointer to a wasm_trap_t object
trap = WasmTrap(trap_ptr)

# The trap message is automatically extracted
println(trap.msg)  # "integer divide by zero"
```

## Common Trap Scenarios

### Division by Zero

```julia
wasm_code = wat"""
(module
  (func (export "divide") (param i32 i32) (result i32)
    local.get 0
    local.get 1
    i32.div_s))
"""

engine = Engine()
store = Store(engine)
module_obj = WasmModule(engine, wat2wasm(wasm_code))
instance = Instance(store, module_obj)

try
    # This will trap due to division by zero
    result = call(instance, "divide", [10, 0])
catch trap::WasmTrap
    println("Caught trap: $(trap.msg)")
    # Output: "Caught trap: integer divide by zero"
end
```

### Memory Access Out of Bounds

```julia
wasm_code = wat"""
(module
  (memory (export "memory") 1)
  (func (export "load") (param i32) (result i32)
    local.get 0
    i32.load))
"""

engine = Engine()
store = Store(engine)
module_obj = WasmModule(engine, wat2wasm(wasm_code))
instance = Instance(store, module_obj)

try
    # This will trap due to out-of-bounds memory access
    result = call(instance, "load", [100000])  # Beyond memory bounds
catch trap::WasmTrap
    println("Memory access trap: $(trap.msg)")
    # Output: "Memory access trap: out of bounds memory access"
end
```

### Stack Overflow

```julia
wasm_code = wat"""
(module
  (func (export "recurse") (param i32) (result i32)
    local.get 0
    i32.const 1
    i32.sub
    local.tee 0
    i32.const 0
    i32.gt_s
    if (result i32)
      local.get 0
      call 0  ; recursive call
    else
      local.get 0
    end))
"""

engine = Engine()
store = Store(engine)
module_obj = WasmModule(engine, wat2wasm(wasm_code))
instance = Instance(store, module_obj)

try
    # This will trap due to stack overflow
    result = call(instance, "recurse", [10000])
catch trap::WasmTrap
    println("Stack overflow trap: $(trap.msg)")
    # Output: "Stack overflow trap: call stack exhausted"
end
```

### Integer Overflow

```julia
wasm_code = wat"""
(module
  (func (export "overflow") (param i32) (result i32)
    local.get 0
    i32.const -1
    i32.div_s))
"""

engine = Engine()
store = Store(engine)
module_obj = WasmModule(engine, wat2wasm(wasm_code))
instance = Instance(store, module_obj)

try
    # This will trap due to integer overflow
    result = call(instance, "overflow", [typemin(Int32)])
catch trap::WasmTrap
    println("Overflow trap: $(trap.msg)")
    # Output: "Overflow trap: integer overflow"
end
```

## Trap Handling Patterns

### Basic Trap Handling

```julia
function safe_wasm_call(instance, func_name, params)
    try
        return call(instance, func_name, params)
    catch trap::WasmTrap
        @warn "WebAssembly trap occurred" function=func_name message=trap.msg
        return nothing
    end
end
```

### Specific Trap Type Handling

```julia
function handle_specific_traps(instance, func_name, params)
    try
        return call(instance, func_name, params)
    catch trap::WasmTrap
        msg = lowercase(trap.msg)

        if occursin("divide by zero", msg)
            @warn "Division by zero detected, returning zero"
            return 0
        elseif occursin("out of bounds", msg)
            @error "Memory access violation" function=func_name params=params
            rethrow(trap)
        elseif occursin("stack exhausted", msg)
            @error "Stack overflow detected" function=func_name
            rethrow(trap)
        else
            @error "Unknown trap type" message=trap.msg
            rethrow(trap)
        end
    end
end
```

### Trap Recovery with Fallback

```julia
function call_with_fallback(instance, primary_func, fallback_func, params)
    try
        return call(instance, primary_func, params)
    catch trap::WasmTrap
        @warn "Primary function trapped, trying fallback"
              primary=primary_func fallback=fallback_func message=trap.msg

        try
            return call(instance, fallback_func, params)
        catch fallback_trap::WasmTrap
            @error "Both primary and fallback functions trapped"
                   primary_trap=trap.msg fallback_trap=fallback_trap.msg
            rethrow(trap)  # Rethrow original trap
        end
    end
end
```

## WasmTrap API Reference

### Fields

- `ptr::Ptr{LibWasmtime.wasm_trap_t}` - Raw pointer to the underlying C trap object
- `msg::AbstractString` - Human-readable trap message

### Methods

#### Constructors

```julia
WasmTrap(ptr::Ptr{LibWasmtime.wasm_trap_t})
```

Creates a `WasmTrap` from a C pointer, automatically extracting the trap message.

#### Comparison Operations

```julia
trap1 == trap2          # Compare two traps
trap == ptr             # Compare trap with C pointer
trap != other_trap      # Inequality comparison
```

#### Utility Functions

```julia
Base.isvalid(trap)      # Check if trap pointer is valid
Base.show(io, trap)     # Display trap information
Base.showerror(io, trap) # Display trap as error
```

#### Conversion Functions

```julia
Base.unsafe_convert(::Type{WasmTrap}, ptr)
Base.unsafe_convert(::Type{Ptr{LibWasmtime.wasm_trap_t}}, trap)
```

## Best Practices

### 1. Always Handle Traps

WebAssembly traps should always be handled, as they represent runtime errors:

```julia
# ✅ Good - Handle traps appropriately
try
    result = call(instance, "risky_function", params)
    return result
catch trap::WasmTrap
    @error "Function trapped" message=trap.msg
    return default_value
end

# ❌ Bad - Ignore potential traps
result = call(instance, "risky_function", params)  # May throw unhandled trap
```

### 2. Log Trap Information

Include trap messages in logs for debugging:

```julia
# ✅ Good - Include trap context
catch trap::WasmTrap
    @error "WebAssembly trap occurred"
           func=func_name
           params=params
           message=trap.msg
           stack_trace=stacktrace()
end
```

### 3. Validate Inputs

Prevent common traps by validating inputs:

```julia
function safe_divide(instance, a, b)
    if b == 0
        @warn "Division by zero prevented"
        return 0
    end

    return call(instance, "divide", [a, b])
end
```

### 4. Use Appropriate Error Recovery

Choose recovery strategies based on trap type:

```julia
function adaptive_trap_handling(instance, func_name, params)
    try
        return call(instance, func_name, params)
    catch trap::WasmTrap
        msg = lowercase(trap.msg)

        # Recoverable errors
        if occursin("divide by zero", msg)
            return 0  # Safe default
        end

        # Non-recoverable errors
        if occursin("out of bounds", msg) || occursin("stack exhausted", msg)
            rethrow(trap)  # Let caller handle
        end

        # Unknown traps
        @error "Unknown trap type, rethrowing" message=trap.msg
        rethrow(trap)
    end
end
```

## Performance Considerations

### Trap Overhead

Catching traps has minimal overhead, but creating trap objects involves:

- Message extraction from C runtime
- String allocation for the message
- Julia object creation

### Avoiding Traps

The best performance strategy is preventing traps:

```julia
# ✅ Prevent traps when possible
function optimized_divide(instance, a, b)
    if b == 0
        return 0  # Avoid trap entirely
    end
    return call(instance, "divide", [a, b])
end

# ❌ Rely on trap handling
function slow_divide(instance, a, b)
    try
        return call(instance, "divide", [a, b])
    catch trap::WasmTrap
        return 0  # Trap handling is slower
    end
end
```

## Common Pitfalls

### 1. Ignoring Trap Messages

```julia
# ❌ Bad - Ignore valuable trap information
catch trap::WasmTrap
    return nothing  # Lost debugging information
end

# ✅ Good - Log trap details
catch trap::WasmTrap
    @error "Trap occurred" message=trap.msg
    return nothing
end
```

### 2. Incorrect Trap Classification

```julia
# ❌ Bad - Overly broad trap handling
catch trap::WasmTrap
    return default_value  # May mask serious errors
end

# ✅ Good - Specific trap handling
catch trap::WasmTrap
    if occursin("divide by zero", trap.msg)
        return 0  # Safe recovery
    else
        rethrow(trap)  # Don't mask other errors
    end
end
```

## Summary

`WasmTrap` provides robust handling for WebAssembly runtime errors. Key points:

- Traps represent unrecoverable WebAssembly runtime errors
- Always handle traps appropriately in production code
- Use trap messages for debugging and error analysis
- Implement appropriate recovery strategies based on trap type
- Prefer preventing traps over handling them when possible
- Log trap information for debugging and monitoring

Understanding and properly handling WebAssembly traps is essential for building robust applications with WasmtimeRuntime.jl.
