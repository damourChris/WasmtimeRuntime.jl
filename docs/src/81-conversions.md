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
