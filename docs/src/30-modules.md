# WebAssembly Modules

WebAssembly modules are the fundamental unit of code in WebAssembly. This guide covers module creation, validation, introspection, and management.

## Module Basics

### Creating Modules

#### From Bytes

```julia
# Read WebAssembly binary
wasm_bytes = read("module.wasm")
module_obj = WasmModule(engine, wasm_bytes)
```

#### From WebAssembly Text (WAT) (✅ Working Feature)

```julia
# WAT to WASM conversion is implemented and working
wat_content = """
(module
  (func $add (param $x i32) (param $y i32) (result i32)
    local.get $x
    local.get $y
    i32.add)
  (export "add" (func $add)))
"""

# Convert WAT to WASM bytes
wasm_bytes = wat2wasm(wat_content)
module_obj = WasmModule(engine, wasm_bytes)
```

#### From File Path (File Reading)

```julia
# Read file and create module
wasm_bytes = read("path/to/module.wasm")
module_obj = WasmModule(engine, wasm_bytes)
```

### Module Properties

```julia
module_obj = WasmModule(engine, wasm_bytes)

# Check validity
isvalid(module_obj)  # Returns true if module is valid

# Access underlying engine
module_obj.engine === engine  # true
```

## Module Validation

### Validating WebAssembly Bytes

Before creating a module, validate the WebAssembly bytes:

```julia
engine = WasmEngine()
wasm_bytes = read("module.wasm")

# Validate before creating module
if validate(engine, wasm_bytes)
    module_obj = WasmModule(engine, wasm_bytes)
    println("Module is valid!")
else
    println("Invalid WebAssembly bytes")
end
```

### Validation Behavior

```julia
# Valid empty module
empty_wasm = UInt8[0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]
validate(engine, empty_wasm)  # true

# Invalid bytes
invalid_wasm = UInt8[0x00, 0x00, 0x00, 0x00]
validate(engine, invalid_wasm)  # false

# Empty bytes
validate(engine, UInt8[])  # false
```

## Module Introspection

### Exports (🚧 Partial Implementation)

Query what the module exports:

```julia
module_obj = WasmModule(engine, wasm_bytes)
module_exports = exports(module_obj)

# Currently returns Dict{String, Any}() - placeholder data
# Full export introspection planned for future release
```

### Imports (🚧 Partial Implementation)

Query what the module requires as imports:

```julia
module_imports = imports(module_obj)

# Currently returns Dict{String, Any}() - placeholder data
# Full import introspection planned for future release
```

### Module Structure (🚧 Limited)

```julia
# Basic module information (returns placeholder data)
println("Module exports: ", length(exports(module_obj)))  # Currently 0
println("Module imports: ", length(imports(module_obj)))  # Currently 0
```

## Module Lifecycle

### Creation and Memory Management

Modules are automatically memory-managed:

```julia
function create_module()
    engine = WasmEngine()
    wasm_bytes = read("module.wasm")
    return WasmModule(engine, wasm_bytes)
end

module_obj = create_module()
# Module and engine are cleaned up when GC'd
```

### Module Reuse

Modules can be instantiated multiple times:

```julia
engine = WasmEngine()
module_obj = WasmModule(engine, wasm_bytes)

# Create multiple instances
store1 = WasmStore(engine)
store2 = WasmStore(engine)

instance1 = Instance(store1, module_obj)
instance2 = Instance(store2, module_obj)

# Each instance has separate state
```

### Sharing Across Engines

Modules are tied to their engine:

```julia
engine1 = Engine()
engine2 = Engine()

module_obj = WasmModule(engine1, wasm_bytes)

# This works - same engine
store1 = Store(engine1)
instance1 = Instance(store1, module_obj)

# This would fail - different engine
store2 = Store(engine2)
# instance2 = Instance(store2, module_obj)  # Error!
```

## Error Handling

### Module Creation Errors

```julia
try
    # Invalid WebAssembly bytes
    invalid_bytes = UInt8[0x00, 0x00, 0x00, 0x00]
    module_obj = WasmModule(engine, invalid_bytes)
catch e::WasmtimeError
    println("Failed to create module: $(e.message)")
end
```

### File System Errors

```julia
try
    # Non-existent file
    module_obj = WasmModule(engine, "nonexistent.wasm")
catch e::SystemError
    println("File not found: $(e.msg)")
end

try
    # File with invalid content
    module_obj = WasmModule(engine, "invalid_file.txt")
catch e::WasmtimeError
    println("Invalid WebAssembly content: $(e.message)")
end
```

### Validation Errors

```julia
# Safe module creation with validation
function safe_create_module(engine, bytes_or_path)
    try
        if isa(bytes_or_path, String)
            # File path
            bytes = read(bytes_or_path)
        else
            # Byte array
            bytes = bytes_or_path
        end

        if !validate(engine, bytes)
            throw(WasmtimeError("Invalid WebAssembly module"))
        end

        return WasmModule(engine, bytes)
    catch e
        rethrow(e)
    end
end
```

## Advanced Module Operations

### Module Compilation Performance

```julia
# For better performance, reuse engines
engine = Engine(Config(optimization_level = SpeedAndSize))

# Compile multiple modules with the same engine
modules = []
for wasm_file in ["module1.wasm", "module2.wasm", "module3.wasm"]
    push!(modules, WasmModule(engine, wasm_file))
end
```

### Module Caching Pattern

```julia
# Simple module cache
module_cache = Dict{String, WasmModule}()

function get_module(engine, file_path)
    if haskey(module_cache, file_path)
        return module_cache[file_path]
    else
        module_obj = WasmModule(engine, file_path)
        module_cache[file_path] = module_obj
        return module_obj
    end
end
```

### Batch Module Processing

```julia
function process_modules(engine, wasm_files)
    results = []

    for file in wasm_files
        try
            # Validate first
            bytes = read(file)
            if validate(engine, bytes)
                module_obj = WasmModule(engine, bytes)
                push!(results, (file, module_obj, :success))
            else
                push!(results, (file, nothing, :invalid))
            end
        catch e
            push!(results, (file, nothing, :error))
        end
    end

    return results
end
```

## WAT to WASM Conversion (Future)

The `wat_to_wasm` function is planned but not yet implemented:

```julia
# Placeholder implementation
function convert_wat_when_available()
    wat_content = """
    (module
      (func $hello (result i32)
        i32.const 42)
      (export "hello" (func $hello)))
    """

    try
        wasm_bytes = wat_to_wasm(wat_content)
        return WasmModule(engine, wasm_bytes)
    catch e::WasmtimeError
        if occursin("not yet implemented", e.message)
            println("WAT conversion not available yet")
            return nothing
        else
            rethrow(e)
        end
    end
end
```

## Best Practices

### Module Creation

1. **Validate before creating**: Always validate WebAssembly bytes
2. **Reuse engines**: Share engines across multiple modules
3. **Handle errors gracefully**: Wrap module creation in try-catch
4. **Cache compiled modules**: Avoid recompiling the same module

### Performance

1. **Use appropriate optimization**: Configure engine optimization level
2. **Minimize module recreation**: Reuse modules when possible
3. **Batch operations**: Process multiple modules efficiently

### Error Recovery

```julia
function robust_module_creation(engine, source)
    # Try different creation methods
    if isa(source, String) && isfile(source)
        try
            return WasmModule(engine, source)
        catch e
            @warn "Failed to load from file: $source" exception=e
        end
    end

    if isa(source, Vector{UInt8})
        if validate(engine, source)
            try
                return WasmModule(engine, source)
            catch e
                @warn "Failed to create from bytes" exception=e
            end
        else
            @warn "Invalid WebAssembly bytes"
        end
    end

    return nothing
end
```

## Debugging Modules

### Module Inspection

```julia
function inspect_module(module_obj)
    println("Module validity: ", isvalid(module_obj))
    println("Module pointer: ", module_obj.ptr)
    println("Engine pointer: ", module_obj.engine.ptr)

    # Introspection (when implemented)
    exports_info = exports(module_obj)
    imports_info = imports(module_obj)

    println("Exports count: ", length(exports_info))
    println("Imports count: ", length(imports_info))
end
```

### Common Issues

1. **Module creation fails**: Check WebAssembly bytes validity
2. **Engine mismatch**: Ensure module and store use same engine
3. **File not found**: Verify file paths and permissions
4. **Memory issues**: Monitor module lifecycle and cleanup

The module system provides a robust foundation for WebAssembly execution while maintaining Julia's ease of use and safety guarantees.
