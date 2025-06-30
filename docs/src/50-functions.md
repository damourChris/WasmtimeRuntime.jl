# Function Calling and Type Conversion

WasmtimeRuntime.jl provides a WasmFunc struct to create and interface with WebAssembly functions.

## Defining WebAssembly Functions

### Example: Function taking (i32, i32) → i32

```julia
function add(x::Int32, y::Int32)::Int32
    return x + y
end

engine = WasmEngine()
store = WasmStore(engine)

# Create a WebAssembly function from a Julia function
wasm_func = WasmFunc(store, add)
```

!!! note
    The `WasmFunc` constructor automatically infers the function signature from the Julia function's type annotations.
    For now, it only supports functions with a single signature, i.e., no overloading.

## Function Calling

### Direct Function Calls

```julia
# Specify parameter types explicitly
result = WasmFunc(store, add)(42, 24)  # Returns Int32

# Will throw an error if the types do not match
result = WasmFunc(store, add)(42.0, 24)  # Throws error
```
