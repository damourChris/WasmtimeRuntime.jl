module WasmtimeRuntime

# Include LibWasmtime for low-level bindings
include("LibWasmtime.jl")
using .LibWasmtime
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

export WasmtimeObject, WasmtimeResource, WasmtimeValue, WasmtimeType
export AbstractEngine, AbstractConfig
export AbstractStore, AbstractModule, AbstractInstance
export AbstractFunc, AbstractMemory, AbstractGlobal, AbstractTable

end
