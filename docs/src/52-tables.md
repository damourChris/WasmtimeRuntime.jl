# WebAssembly Tables

WebAssembly tables are resizable arrays that hold references to functions or other WebAssembly objects. In WasmtimeRuntime.jl, tables are represented by the `WasmTable` type, which provides a Julia-friendly interface for working with WebAssembly table objects.

## Table Types

### WasmTableType

The `WasmTableType` represents the type information for a WebAssembly table, including its size limits and element type.

```julia
# Create a table type with default limits (0 => 0)
table_type = WasmTableType()

# Create a table type with custom limits
table_type = WasmTableType(10 => 100)  # min=10, max=100

# Create from WasmLimits
limits = WasmLimits(5, 50)
table_type = WasmTableType(limits)
```

#### Size Limits

Table limits specify the minimum and maximum number of elements:

- **Minimum**: Initial number of elements (must be ≥ 0)
- **Maximum**: Maximum number of elements (0 means unlimited)

```julia
# Table with 5 initial elements, max 20
table_type = WasmTableType(5 => 20)

# Table with 10 initial elements, unlimited growth
table_type = WasmTableType(10 => 0)

# Empty table that can grow up to 100 elements
table_type = WasmTableType(0 => 100)
```

## Creating Tables

Tables are created using a `WasmStore` and `WasmTableType`:

```julia
# Set up WebAssembly environment
engine = WasmEngine()
store = WasmStore(engine)

# Create table type and table
table_type = WasmTableType(5 => 50)
table = WasmTable(store, table_type)
```

## Table Interface

`WasmTable` implements the `AbstractVector` interface, providing familiar array-like operations:

### Size and Indexing

```julia
# Get table size
table_size = length(table)
size_tuple = size(table)  # Returns (length,)

# Access elements (1-based indexing)
first_element = table[1]
last_element = table[end]

# Check bounds
if length(table) > 0
    element = table[1]  # Safe access
end
```

### Element Access

Table elements are function references or other WebAssembly references:

```julia
# Access table element
element = table[1]

if element === nothing
    println("Slot is empty")
else
    println("Slot contains a reference")
    # element is a Ptr{LibWasmtime.wasm_ref_t}
end
```

## Type Information

Extract type information from existing tables:

```julia
# Get table type from table
extracted_type = WasmTableType(table)
```

## Error Handling

Common error scenarios and how to handle them:

### Invalid Store

```julia
engine = WasmEngine()
store = WasmStore(engine)
store.ptr = C_NULL  # Invalidate store

table_type = WasmTableType()

# This will throw ArgumentError
try
    table = WasmTable(store, table_type)
catch e
    println("Failed to create table: ", e)
end
```

### Bounds Checking

```julia
table_type = WasmTableType(3 => 10)
table = WasmTable(store, table_type)

# These will throw BoundsError
try
    table[0]     # Invalid: 0-based indexing
    table[-1]    # Invalid: negative index
    table[100]   # Invalid: beyond table size
catch BoundsError
    println("Index out of bounds")
end
```

### Invalid Limits

```julia

try
    invalid_limits = WasmLimits(10, 5)  # max < min <---  This will throw ArgumentError
    table_type = WasmTableType(invalid_limits)
catch ArgumentError
    println("Invalid table limits")
end
```

## Advanced Usage

### Working with Multiple Tables

```julia
engine = WasmEngine()
store = WasmStore(engine)

# Create multiple tables with different sizes
small_table = WasmTable(store, WasmTableType(2 => 10))
large_table = WasmTable(store, WasmTableType(50 => 1000))

println("Small table size: ", length(small_table))
println("Large table size: ", length(large_table))
```

### Resource Management

Tables are automatically cleaned up when they go out of scope:

```julia
function create_temporary_table()
    engine = WasmEngine()
    store = WasmStore(engine)
    table_type = WasmTableType(5 => 20)
    table = WasmTable(store, table_type)

    # Use table...
    return length(table)
end

size = create_temporary_table()
# Table is automatically cleaned up when function exits
```

### Performance Considerations

For optimal performance:

1. **Reuse stores**: Create one store and use it for multiple tables
2. **Appropriate sizing**: Set realistic minimum and maximum limits
3. **Avoid frequent type extraction**: Cache `WasmTableType` objects when needed

```julia
engine = WasmEngine()
store = WasmStore(engine)  # Reuse this store

# Create multiple tables efficiently
tables = [WasmTable(store, WasmTableType(i => i*10)) for i in 1:5]
```

## Integration with WebAssembly Modules

Tables are typically used with WebAssembly modules that export or import table objects:

```julia
# Example: working with a module that uses tables
engine = WasmEngine()
store = WasmStore(engine)

# Create table for module
table_type = WasmTableType(10 => 100)
table = WasmTable(store, table_type)

# Table can be passed to module instantiation
# (specific module loading code would depend on your WebAssembly module)
```

## Type System Integration

`WasmTable` integrates well with Julia's type system:

```julia
table = WasmTable(store, WasmTableType(5 => 20))

# Type checking
@assert table isa AbstractVector
@assert eltype(table) == Union{Nothing, Ptr{LibWasmtime.wasm_ref_t}}

# Standard vector operations
@assert ndims(table) == 1
@assert firstindex(table) == 1
```

## Best Practices

1. **Validate inputs**: Always check that stores and table types are valid
2. **Handle bounds**: Use proper bounds checking when accessing elements
3. **Resource cleanup**: Let Julia's garbage collector handle cleanup automatically
4. **Error handling**: Wrap table operations in try-catch blocks for robustness

```julia
function safe_table_access(table, index)
    try
        if index in 1:length(table)
            return table[index]
        else
            @warn "Index $index out of bounds for table of size $(length(table))"
            return nothing
        end
    catch e
        @error "Error accessing table: $e"
        return nothing
    end
end
```
