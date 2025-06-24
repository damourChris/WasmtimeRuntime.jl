module WasmtimeRuntime

# Include LibWasmtime for low-level bindings
include("LibWasmtime.jl")
using .LibWasmtime
# Include all components in the correct order
include("types.jl")
include("errors.jl")
include("config.jl")
include("engine.jl")
include("store.jl")
include("values.jl")
include("module.jl")
include("instance.jl")
include("objects.jl")

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

export debug_info!,
    optimization_level!, profiler!, consume_fuel!, epoch_interruption!, max_wasm_stack!

# Store management
export add_fuel!, fuel_consumed, set_epoch_deadline!

# Conversion functions
export is_wasm_convertible, to_wasm, from_wasm

export WasmModule, Instance, Func, Memory, Global, Table
export validate, exports, imports, wat_to_wasm, instantiate

end
