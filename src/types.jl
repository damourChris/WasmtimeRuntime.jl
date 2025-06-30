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
abstract type AbstractWasmExtern <: WasmtimeObject end

# WebAssembly externs
abstract type AbstractWasmExternType <: WasmtimeType end
abstract type AbstractWasmExternObject <: AbstractWasmExtern end

abstract type AbstractFunc <: AbstractWasmExternObject end
abstract type AbstractMemory <: AbstractWasmExternObject end
abstract type AbstractSharedMemory <: AbstractWasmExternObject end
abstract type AbstractGlobal <: AbstractWasmExternObject end
abstract type AbstractTable <: AbstractWasmExternObject end


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

@enum WasmExternKind begin
    WasmExternFunc = LibWasmtime.WASM_EXTERN_FUNC |> Int
    WasmExternGlobal = LibWasmtime.WASM_EXTERN_GLOBAL |> Int
    WasmExternTable = LibWasmtime.WASM_EXTERN_TABLE |> Int
    WasmExternMemory = LibWasmtime.WASM_EXTERN_MEMORY |> Int
end
