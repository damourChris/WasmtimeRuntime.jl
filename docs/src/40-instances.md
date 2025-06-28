# WebAssembly Instances

WebAssembly instances represent the runtime instantiation of modules with their own isolated state.

Each `Instance` in Wasmtime *only* represents Module Instances.
As such from the WASM specification perspective:
> A module instance is the runtime representation of a module. It is created by instantiating a module,
> and collects runtime representations of all entities that are imported, defined, or exported by the module.

## Instance Basics

### Creating Instances

```julia
# Basic instance creation
engine = WasmEngine()
store = WasmStore(engine)
wasm_bytes = read("module.wasm")
module_obj = WasModule(engine, wasm_bytes)

# Create instance
instance = WasmInstance(store, module_obj)
```

## Instance State Management

### Isolated State

Each instance maintains its own state:

```julia
# Create multiple instances from the same module
instance1 = Instance(store1, module_obj)
instance2 = Instance(store2, module_obj)

# Each instance has separate:
# - Memory contents
# - Global variable values
# - Function state
```

### Store Association

Instances are bound to specific stores:

```julia
engine = Engine()
store1 = Store(engine)
store2 = Store(engine)

module_obj = WasmModule(engine, wasm_bytes)

# Each instance tied to its store
instance1 = Instance(store1, module_obj)
instance2 = Instance(store2, module_obj)

# Instances cannot be used with different stores
```

### Memory Sharing

Within the same store, instances can share certain resources:

```julia
# Multiple instances in the same store
store = Store(engine)
instance1 = Instance(store, module_obj)
instance2 = Instance(store, module_obj)

# They share the store context but maintain separate module state
```

## Error Handling

### Instance Creation Errors

```julia
try
    # Invalid store
    store.ptr = C_NULL
    instance = Instance(store, module_obj)
catch e::WasmtimeError
    println("Invalid store: $(e.message)")
end

try
    # Invalid module
    module_obj.ptr = C_NULL
    instance = Instance(store, module_obj)
catch e::WasmtimeError
    println("Invalid module: $(e.message)")
end
```
