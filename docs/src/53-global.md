# WebAssembly Global Variables

Global variables in WebAssembly are storage locations that persist for the lifetime of a WebAssembly instance. They can hold a single value of a specific type (Int32, Int64, Float32, or Float64) and can be either mutable or immutable.

## Global Types

### WasmGlobalType

Defines the characteristics of a global variable including its value type and mutability.

```julia
# Create a mutable Int32 global type
valtype = WasmValType(Int32)
global_type = WasmGlobalType(valtype, true)  # true = mutable

# Create an immutable Float64 global type
valtype = WasmValType(Float64)
global_type = WasmGlobalType(valtype, false)  # false = immutable
```

**Constructor Parameters:**

- `valtype::WasmValtype`: The WebAssembly value type
- `mutability::Bool`: Whether the global can be modified after creation

## Global Variables

### WasmGlobal

Represents an actual global variable instance with a value.

```julia
engine = WasmEngine()
store = WasmStore(engine)

# Create a mutable counter global
valtype = WasmValType(Int32)
global_type = WasmGlobalType(valtype, true)
counter = WasmGlobal(store, global_type, WasmValue(Int32(0)))

# Create an immutable constant
valtype = WasmValType(Float64)
global_type = WasmGlobalType(valtype, false)
pi_constant = WasmGlobal(store, global_type, WasmValue(3.14159))
```

**Constructor Parameters:**

- `store::WasmStore`: The store that owns this global
- `global_type::WasmGlobalType`: Type descriptor defining characteristics
- `initial_value::WasmValue`: Starting value for the global

## Supported Types

WebAssembly globals support four primitive types:

| Julia Type | WebAssembly Type | Description |
|------------|------------------|-------------|
| `Int32` | `i32` | 32-bit signed integer |
| `Int64` | `i64` | 64-bit signed integer |
| `Float32` | `f32` | 32-bit floating point |
| `Float64` | `f64` | 64-bit floating point |

```julia
# Examples for each type
int32_global = WasmGlobal(store, WasmGlobalType(WasmValType(Int32), true), WasmValue(Int32(42)))
int64_global = WasmGlobal(store, WasmGlobalType(WasmValType(Int64), true), WasmValue(Int64(1000)))
float32_global = WasmGlobal(store, WasmGlobalType(WasmValType(Float32), true), WasmValue(Float32(2.718)))
float64_global = WasmGlobal(store, WasmGlobalType(WasmValType(Float64), true), WasmValue(3.14159))
```

## Mutability

Global variables can be either mutable or immutable:

### Mutable Globals

```julia
# Can be modified after creation
valtype = WasmValType(Int32)
mutable_type = WasmGlobalType(valtype, true)  # true = mutable
counter = WasmGlobal(store, mutable_type, WasmValue(Int32(0)))
```

### Immutable Globals

```julia
# Cannot be modified after creation
valtype = WasmValType(Float64)
immutable_type = WasmGlobalType(valtype, false)  # false = immutable
constant = WasmGlobal(store, immutable_type, WasmValue(3.14159))
```

## Common Usage Patterns

### Application Configuration

```julia
# Store application constants as immutable globals
debug_mode = WasmGlobal(store,
    WasmGlobalType(WasmValType(Int32), false),
    WasmValue(Int32(1)))  # 1 = debug on

max_iterations = WasmGlobal(store,
    WasmGlobalType(WasmValType(Int32), false),
    WasmValue(Int32(1000)))
```

### Runtime State

```julia
# Track mutable runtime state
frame_counter = WasmGlobal(store,
    WasmGlobalType(WasmValType(Int64), true),
    WasmValue(Int64(0)))

last_error_code = WasmGlobal(store,
    WasmGlobalType(WasmValType(Int32), true),
    WasmValue(Int32(0)))
```

### Mathematical Constants

```julia
# Store frequently used mathematical constants
pi = WasmGlobal(store,
    WasmGlobalType(WasmValType(Float64), false),
    WasmValue(3.141592653589793))

e = WasmGlobal(store,
    WasmGlobalType(WasmValType(Float64), false),
    WasmValue(2.718281828459045))
```

## Resource Management

Global variables automatically manage their memory through Julia's finalizer system:

```julia
# Resources are automatically cleaned up
function create_globals()
    engine = WasmEngine()
    store = WasmStore(engine)

    valtype = WasmValType(Int32)
    global_type = WasmGlobalType(valtype, true)
    global_var = WasmGlobal(store, global_type, WasmValue(Int32(42)))

    return global_var
end

global_var = create_globals()
# When global_var goes out of scope, memory is automatically freed
```

## Error Handling

Common errors when working with globals:

### Invalid Value Type

```julia
# Error: Using an invalid WasmValtype
valtype = WasmValType(Int32)
valtype.ptr = C_NULL  # Simulate corruption
# This will throw ArgumentError("Invalid WasmValtype")
global_type = WasmGlobalType(valtype, true)
```

### Invalid Store or Type

```julia
engine = WasmEngine()
store = WasmStore(engine)
store.ptr = C_NULL  # Simulate corruption

valtype = WasmValType(Int32)
global_type = WasmGlobalType(valtype, true)
# This will throw ArgumentError("Invalid store or global type")
global_var = WasmGlobal(store, global_type, WasmValue(Int32(42)))
```

<!-- ### Invalid Initial Value
```julia
initial_value = WasmValue(Int32(42))
initial_value.ptr = C_NULL  # Simulate corruption
# This will throw ArgumentError("Invalid initial value for global")
global_var = WasmGlobal(store, global_type, initial_value)
``` -->

## Best Practices

### 1. Use Descriptive Names

```julia
# Good: Clear purpose
max_retry_count = WasmGlobal(store, WasmGlobalType(WasmValType(Int32), false), WasmValue(Int32(3)))

# Avoid: Unclear purpose
x = WasmGlobal(store, WasmGlobalType(WasmValType(Int32), false), WasmValue(Int32(3)))
```

### 2. Choose Appropriate Mutability

```julia
# Immutable for constants
PI = WasmGlobal(store, WasmGlobalType(WasmValType(Float64), false), WasmValue(3.14159))

# Mutable for runtime state
request_count = WasmGlobal(store, WasmGlobalType(WasmValType(Int64), true), WasmValue(Int64(0)))
```

### 3. Initialize with Sensible Defaults

```julia
# Initialize counters to zero
counter = WasmGlobal(store, WasmGlobalType(WasmValType(Int32), true), WasmValue(Int32(0)))

# Initialize flags to false (0)
error_flag = WasmGlobal(store, WasmGlobalType(WasmValType(Int32), true), WasmValue(Int32(0)))
```

### 4. Group Related Globals

```julia
# Create related globals together for better organization
function create_math_constants(store)
    float_type = WasmGlobalType(WasmValType(Float64), false)

    return (
        pi = WasmGlobal(store, float_type, WasmValue(π)),
        e = WasmGlobal(store, float_type, WasmValue(ℯ)),
        golden_ratio = WasmGlobal(store, float_type, WasmValue(1.618033988749))
    )
end
```

## Integration with WebAssembly Modules

Global variables can be imported from or exported to WebAssembly modules:

```julia
# Globals created in Julia can be passed to WebAssembly instances
engine = WasmEngine()
store = WasmStore(engine)

# Create a global that WebAssembly can access
shared_counter = WasmGlobal(store,
    WasmGlobalType(WasmValType(Int32), true),
    WasmValue(Int32(0)))

# This global can then be used when instantiating WebAssembly modules
# (specific integration depends on module imports/exports)
```

## Performance Considerations

1. **Type Selection**: Choose the smallest appropriate type (Int32 vs Int64, Float32 vs Float64)
2. **Mutability**: Immutable globals may allow for better optimization
3. **Initialization**: Initialize globals with their expected initial values to avoid unnecessary updates
