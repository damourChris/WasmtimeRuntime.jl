module WasmtimeRuntime

# Include LibWasmtime for low-level bindings
include("LibWasmtime.jl")
using .LibWasmtime
# Include all components in the correct order
include("types.jl")
export WasmtimeObject, WasmtimeResource, WasmtimeValue, WasmtimeType
export AbstractEngine, AbstractConfig
export AbstractStore, AbstractModule, AbstractInstance
export AbstractFunc, AbstractMemory, AbstractGlobal, AbstractTable

end
