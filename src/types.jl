# Core abstract types for WasmtimeRuntime
using CEnum

# Core abstract types
abstract type WasmtimeObject end
abstract type WasmtimeResource <: WasmtimeObject end
abstract type WasmtimeValue <: WasmtimeObject end
abstract type WasmtimeType <: WasmtimeObject end

# Engine and compilation
abstract type AbstractEngine <: WasmtimeResource end
abstract type AbstractConfig <: WasmtimeObject end

# Runtime objects
abstract type AbstractStore <: WasmtimeResource end
abstract type AbstractModule <: WasmtimeResource end
abstract type AbstractInstance <: WasmtimeResource end

# WebAssembly objects
abstract type AbstractFunc <: WasmtimeResource end
abstract type AbstractMemory <: WasmtimeResource end
abstract type AbstractGlobal <: WasmtimeResource end
abstract type AbstractTable <: WasmtimeResource end

# Core enums for type safety
@enum OptimizationLevel begin
    None = 0
    Speed = 1
    SpeedAndSize = 2
end

@enum ProfilingStrategy begin
    NoProfilingStrategy = 0
    JitdumpProfilingStrategy = 1
    VTuneProfilingStrategy = 2
    PerfMapProfilingStrategy = 3
end
