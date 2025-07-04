module WasmtimeRuntime

# Include LibWasmtime for low-level bindings
include("LibWasmtime.jl")
using .LibWasmtime

# Core types and utilities
include("types.jl")
export WasmtimeObject, WasmtimeResource, WasmtimeValue, WasmtimeType
export AbstractEngine, AbstractConfig
export AbstractStore, AbstractModule, AbstractInstance
export AbstractWasmExternType, AbstractWasmExtern
export AbstractFunc, AbstractMemory, AbstractGlobal, AbstractTable
export OptimizationLevel, ProfilingStrategy
export None, Speed, SpeedAndSize
export NoProfilingStrategy,
    JitdumpProfilingStrategy, VTuneProfilingStrategy, PerfMapProfilingStrategy
export WasmExternFunc,
    WasmExternGlobal, WasmExternTable, WasmExternMemory, WasmExternSharedMemory

include("errors.jl")
export WasmtimeError, check_error, @safe_resource

include("traps.jl")
export WasmTrap

include("utils.jl")
export WasmLimits

include("values.jl")
export WasmValue, WasmI32, WasmI64, WasmF32, WasmF64, WasmFuncRef, WasmExternRef, WasmV128
export is_wasm_convertible, to_wasm, from_wasm

include("vec.jl")
export WasmVec, WasmByteVec, WasmValVec, WasmName
export WasmPtrVec,
    WasmExternVec,
    WasmImportTypeVec,
    WasmExportTypeVec,
    WasmValtypeVec,
    WasmTableTypeVec,
    WasmExternTypeVec,
    WasmFrameVec
export to_julia_vector


include("wat2wasm.jl")
export wat2wasm, @wat_str

# Wasm
include("wasm/config.jl")
export WasmConfig
export debug_info!,
    optimization_level!, profiler!, consume_fuel!, epoch_interruption!, max_wasm_stack!

include("wasm/engine.jl")
export WasmEngine

include("wasm/store.jl")
export WasmStore
export add_extern_func!


include("wasm/module.jl")
export WasmModule
export validate, exports, imports, wat_to_wasm

include("wasm/instance.jl")
export WasmInstance

include("wasm/externs/function.jl")
export WasmFunc, WasmFuncType, WasmValType

include("wasm/externs/memory.jl")
export WasmMemory, WasmMemoryType

include("wasm/externs/table.jl")
export WasmTable, WasmTableType

include("wasm/externs/global.jl")
export WasmGlobal, WasmGlobalType


include("wasm/extern.jl")
export WasmExtern, WasmExternObjectType, externtype


# Wasmtime
include("wasmtime/store.jl")
export WasmtimeStore
export add_fuel!, fuel_consumed, set_epoch_deadline!

include("wasmtime/module.jl")
export WasmtimeModule

include("wasmtime/instance.jl")
export WasmtimeInstance
export instantiate

# Error types
export WasmtimeError

# Core types
export Config, Engine, Store
export WasmValue, WasmI32, WasmI64, WasmF32, WasmF64, WasmFuncRef, WasmExternRef, WasmV128



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
