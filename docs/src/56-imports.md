# WebAssembly Import Types

The `WasmImportType` struct represents WebAssembly import declarations that specify external dependencies a module requires. This documentation covers creating, managing, and working with import type definitions.

!!! For now, only function imports are supported.

## Overview

WebAssembly imports allow modules to specify external functions, globals, memories, or tables they need from the host environment or other modules. The `WasmImportType` represents the type signature and naming information for these imports.

## Creating Import Types

### From String Parameters

Create import types by specifying the module name, import name, and function signature:

```julia
# Create a function type first
params = [Int32, Float64]
results = [Int32]
functype = WasmFuncType(params, results)

# Create the import type
import_type = WasmImportType("math_module", "add_numbers", functype)
```

### From Existing Pointers

Reconstruct import types from C API pointers:

```julia
# From an existing import type pointer
ptr = some_existing_import_ptr
import_type = WasmImportType(ptr)

println(import_type.module_name)  # Extracted module name
println(import_type.import_name)  # Extracted import name
```

## Import Type Properties

### Basic Properties

Access the core properties of an import type:

```julia
import_type = WasmImportType("env", "print", functype)

# Access module and import names
@show import_type.module_name   # "env"
@show import_type.import_name   # "print"

# Check validity
@show isvalid(import_type)      # true

# Get import name (convenience function)
@show name(import_type)         # "print"
```

## Common Use Cases

### Module Import Declarations

Define what a module needs from its environment:

```julia
# Print function: takes string, returns nothing
print_type = WasmFuncType([String], [])
print_import = WasmImportType("env", "print", print_type)

# Math function: takes two numbers, returns one
add_type = WasmFuncType([Int32, Int32], [Int32])
add_import = WasmImportType("math", "add", add_type)

# Memory import: (would use WasmMemoryType when available)
# memory_import = WasmImportType("env", "memory", memory_type)
```

### Import Validation

Validate import signatures before module instantiation:

```julia
function validate_import(import_type::WasmImportType)
    if !isvalid(import_type)
        return false, "Invalid import type"
    end

    if import_type.module_name == ""
        return false, "Empty module name"
    end

    if import_type.import_name == ""
        return false, "Empty import name"
    end

    return true, "Valid"
end

is_valid, message = validate_import(import_type)
println("Import validation: $message")
```

### Import Inspection

Analyze module import requirements:

```julia
function analyze_import(import_type::WasmImportType)
    println("Import Analysis:")
    println("  Module: $(import_type.module_name)")
    println("  Name: $(import_type.import_name)")
    println("  Valid: $(isvalid(import_type))")

    # Could extract more type information here
    # when function type inspection is available
end

analyze_import(import_type)
```

## Working with Function Types

### Simple Function Imports

Common patterns for function imports:

```julia
# No parameters, no return value (like print)
void_type = WasmFuncType([], [])
print_import = WasmImportType("console", "log", void_type)

# One parameter, one return value
unary_type = WasmFuncType([Int32], [Int32])
abs_import = WasmImportType("math", "abs", unary_type)

# Multiple parameters, one return value
binary_type = WasmFuncType([Int32, Int32], [Int32])
add_import = WasmImportType("math", "add", binary_type)

# Multiple parameters, multiple return values
multi_type = WasmFuncType([Int32, Float64], [Int32, Float64])
complex_import = WasmImportType("utils", "process", multi_type)
```

### Type Safety

Ensure type compatibility:

```julia
function create_safe_import(module_name, import_name, params, results)
    try
        functype = WasmFuncType(params, results)
        return WasmImportType(module_name, import_name, functype)
    catch e
        @error "Failed to create import" module=module_name name=import_name error=e
        return nothing
    end
end

# Usage
import_type = create_safe_import("env", "func", [Int32], [Int32])
if import_type !== nothing
    println("Successfully created import")
end
```

## Error Handling

### Common Error Scenarios

Handle various error conditions:

```julia
# Empty names
try
    WasmImportType("", "function", functype)
catch ArgumentError as e
    println("Empty module name: $(e.msg)")
end

try
    WasmImportType("module", "", functype)
catch ArgumentError as e
    println("Empty import name: $(e.msg)")
end

# Invalid pointers
try
    WasmImportType(Ptr{LibWasmtime.wasm_importtype_t}(C_NULL))
catch ArgumentError as e
    println("Null pointer: $(e.msg)")
end

# Invalid function type
invalid_functype = WasmFuncType([Int32], [Int32])
invalid_functype.ptr = C_NULL

try
    WasmImportType("module", "function", invalid_functype)
catch e
    println("Invalid function type: $(e)")
end
```

### Defensive Programming

Build robust import handling:

```julia
function safe_import_creation(module_name, import_name, functype)
    # Validate inputs
    if isempty(module_name) || isempty(import_name)
        throw(ArgumentError("Module and import names cannot be empty"))
    end

    if !isvalid(functype)
        throw(ArgumentError("Invalid function type"))
    end

    # Create import
    try
        import_type = WasmImportType(module_name, import_name, functype)

        # Verify creation succeeded
        if !isvalid(import_type)
            throw(WasmtimeError("Failed to create valid import type"))
        end

        return import_type
    catch e
        @error "Import creation failed" module=module_name name=import_name exception=e
        rethrow(e)
    end
end
```

## Integration Patterns

### Module Import Lists

Build complete import specifications:

```julia
function create_module_imports()
    imports = WasmImportType[]

    # Console functions
    log_type = WasmFuncType([String], [])
    push!(imports, WasmImportType("console", "log", log_type))

    error_type = WasmFuncType([String], [])
    push!(imports, WasmImportType("console", "error", error_type))

    # Math functions
    add_type = WasmFuncType([Int32, Int32], [Int32])
    push!(imports, WasmImportType("math", "add", add_type))

    sqrt_type = WasmFuncType([Float64], [Float64])
    push!(imports, WasmImportType("math", "sqrt", sqrt_type))

    return imports
end

module_imports = create_module_imports()
for imp in module_imports
    println("Import: $(imp.module_name).$(imp.import_name)")
end
```

### Import Resolution

Match imports with available functions:

```julia
function resolve_imports(imports::Vector{WasmImportType}, available_modules)
    resolved = Dict()
    unresolved = WasmImportType[]

    for import_type in imports
        module_name = import_type.module_name
        import_name = import_type.import_name

        if haskey(available_modules, module_name) &&
           haskey(available_modules[module_name], import_name)
            resolved[import_name] = available_modules[module_name][import_name]
        else
            push!(unresolved, import_type)
        end
    end

    return resolved, unresolved
end
```

## Best Practices

### Naming Conventions

Follow consistent naming patterns:

```julia
# Use clear, descriptive names
good_import = WasmImportType("environment", "print_string", functype)

# Avoid abbreviated or unclear names
# bad_import = WasmImportType("env", "prt", functype)  # Unclear

# Use consistent module grouping
console_log = WasmImportType("console", "log", log_type)
console_error = WasmImportType("console", "error", error_type)
console_warn = WasmImportType("console", "warn", warn_type)
```

### Error Messages

Provide actionable error information:

```julia
function validate_import_name(name::String, context::String)
    if isempty(name)
        throw(ArgumentError("$context name cannot be empty"))
    end

    if length(name) > 256
        throw(ArgumentError("$context name too long (max 256 characters): $name"))
    end

    # Add other validation as needed
    return true
end

# Usage
validate_import_name(module_name, "Module")
validate_import_name(import_name, "Import")
```

### Memory Management

Handle resources properly:

```julia
function process_imports_safely(import_specs)
    imports = WasmImportType[]

    try
        for spec in import_specs
            functype = WasmFuncType(spec.params, spec.results)
            import_type = WasmImportType(spec.module, spec.name, functype)
            push!(imports, import_type)
        end

        # Process imports...
        return process_import_list(imports)

    catch e
        @error "Failed to process imports" exception=e
        # Cleanup handled by finalizers
        rethrow(e)
    end
end
```

## Performance Considerations

### Batch Operations

Create imports efficiently:

```julia
function create_imports_batch(specifications)
    # Pre-allocate result vector
    imports = Vector{WasmImportType}(undef, length(specifications))

    for (i, spec) in enumerate(specifications)
        functype = WasmFuncType(spec.params, spec.results)
        imports[i] = WasmImportType(spec.module, spec.name, functype)
    end

    return imports
end
```

### Reuse Function Types

Avoid recreating identical function types:

```julia
# Cache common function types
const COMMON_FUNCTYPES = Dict(
    :void_void => WasmFuncType([], []),
    :i32_i32 => WasmFuncType([Int32], [Int32]),
    :i32_i32_i32 => WasmFuncType([Int32, Int32], [Int32]),
)

function create_import_with_cache(module_name, import_name, type_key)
    functype = COMMON_FUNCTYPES[type_key]
    return WasmImportType(module_name, import_name, functype)
end

# Usage
print_import = create_import_with_cache("console", "log", :void_void)
add_import = create_import_with_cache("math", "add", :i32_i32_i32)
```

## API Reference

### Constructor Methods

```julia
# From string parameters
WasmImportType(module_name::String, import_name::String, functype::WasmFuncType)

# From C pointer
WasmImportType(ptr::Ptr{LibWasmtime.wasm_importtype_t})
```

### Instance Methods

```julia
# Check validity
isvalid(import_type::WasmImportType) -> Bool

# Get import name
name(import_type::WasmImportType) -> String

# Convert to C pointer
Base.unsafe_convert(::Type{Ptr{LibWasmtime.wasm_importtype_t}}, import_type) -> Ptr

# Display information
Base.show(io::IO, import_type::WasmImportType)
```

### Properties

```julia
import_type.ptr          # C API pointer
import_type.module_name  # Module name string
import_type.import_name  # Import name string
```

---

**Note**: Import types are fundamental to WebAssembly module linking and instantiation. Proper import type definition ensures modules can successfully resolve their external dependencies.
