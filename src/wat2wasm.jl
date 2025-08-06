"""
    wat2wasm(wat::AbstractString) -> WasmByteVec

Converts a WebAssembly Text format (WAT) string to its corresponding WebAssembly binary format (WASM).
Takes a WAT string as input and returns a `WasmByteVec` containing the compiled WASM bytes.
"""
function wat2wasm(wat::AbstractString)
    out = WasmByteVec()
    @throw_if_error GC.@preserve out LibWasmtime.wasmtime_wat2wasm(wat, length(wat), out)

    out
end

macro wat_str(wat::String)
    :(wat2wasm($wat))
end
