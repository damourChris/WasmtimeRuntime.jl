# Conversion

## Wat to Wasm

The `wat2wasm` function converts WebAssembly Text Format (WAT) to WebAssembly binary format (WASM).
This is useful for compiling WAT code into a format that can be executed by WebAssembly runtimes.

```julia
using WasmtimeRuntime

wat = """
(module
  (func (export "add") (param i32 i32) (result i32)
    local.get 0
    local.get 1
    i32.add)
  )
"""

wasm = wat2wasm(wat)
```

For convenience, you can also use the `@wat_str` macro to convert a WAT string into a WASM binary format:

```julia
using WasmtimeRuntime

wasm_binary = @wat_str """
(module
  (func (export "add") (param i32 i32) (result i32)
    local.get 0
    local.get 1
    i32.add)
  )
"""

# or simply:

wasm_binary = wat"""
(module
  (func (export "add") (param i32 i32) (result i32)
    local.get 0
    local.get 1
    i32.add)
  )
"""
```
