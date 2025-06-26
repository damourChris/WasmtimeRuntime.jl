module WasmtimeRuntime

# Include LibWasmtime for low-level bindings
include("LibWasmtime.jl")
using .LibWasmtime

# Core types and utilities
include("types.jl")
include("errors.jl")
include("vec.jl")
include("values.jl")
include("objects.jl")

# Wasm
include("wasm/engine.jl")
include("wasm/module.jl")
include("wasm/config.jl")

# Wasmtime
include("wasmtime/store.jl")
include("wasmtime/instance.jl")

export WasmtimeObject, WasmtimeResource, WasmtimeValue, WasmtimeType
export AbstractEngine, AbstractConfig
export AbstractStore, AbstractModule, AbstractInstance
export AbstractFunc, AbstractMemory, AbstractGlobal, AbstractTable

# Enums
export OptimizationLevel, ProfilingStrategy
export None, Speed, SpeedAndSize
export NoProfilingStrategy,
    JitdumpProfilingStrategy, VTuneProfilingStrategy, PerfMapProfilingStrategy

# Error types
export WasmtimeError

# Core types
export Config, Engine, Store
export WasmValue, WasmI32, WasmI64, WasmF32, WasmF64, WasmFuncRef, WasmExternRef, WasmV128

# Generic vector wrapper
export WasmVec,
    WasmPtrVec,
    WasmByteVec,
    WasmName,
    WasmExternVec,
    WasmImportTypeVec,
    WasmExportTypeVec,
    WasmValtypeVec,
    WasmValVec,
    WasmTableTypeVec,
    WasmExternTypeVec,
    WasmFrameVec
export WasmValtypeVec, WasmValVec, WasmTableTypeVec, WasmExternTypeVec, WasmFrameVec
export WasmPtrVec, to_julia_vector

# Configuration functions
export debug_info!,
    optimization_level!, profiler!, consume_fuel!, epoch_interruption!, max_wasm_stack!

# Store management
export add_fuel!, fuel_consumed, set_epoch_deadline!

# Conversion functions
export is_wasm_convertible, to_wasm, from_wasm

export WasmModule, Instance, Func, Memory, Global, Table
export validate, exports, imports, wat_to_wasm, instantiate

end
