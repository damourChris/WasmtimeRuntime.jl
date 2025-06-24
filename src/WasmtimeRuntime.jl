module WasmtimeRuntime

# Include LibWasmtime for low-level bindings
include("LibWasmtime.jl")
using .LibWasmtime
# Include all components in the correct order
include("types.jl")
include("errors.jl")
include("config.jl")
include("engine.jl")
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
export Config, Engine
export debug_info!,
    optimization_level!, profiler!, consume_fuel!, epoch_interruption!, max_wasm_stack!

end
