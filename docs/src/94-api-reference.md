# API Reference

Comprehensive API documentation for all WasmtimeRuntime.jl components.

## Configuration

```@docs
Config
```

### Configuration Functions

```@docs
debug_info!
optimization_level!
profiler!
consume_fuel!
epoch_interruption!
max_wasm_stack!
```

## Runtime Components

### Engine

```@docs
Engine
```

### Store

```@docs
Store
add_fuel!
fuel_consumed
set_epoch_deadline!
```

## WebAssembly Modules

```@docs
WasmModule
validate
wat_to_wasm
```

### Module Functions

```@docs
exports
```

## WebAssembly Instances

```@docs
Instance
instantiate
get_export
```

## Functions

```@docs
Func
TypedFunc
get_func
get_typed_func
call
@wasm_call
@wasm_call_typed
@typed_func
```

## Values and Types

```@docs
WasmValue
WasmI32
WasmI64
WasmF32
WasmF64
WasmFuncRef
WasmExternRef
WasmV128
is_wasm_convertible
to_wasm
from_wasm
```

## WebAssembly Objects

```@docs
Memory
Global
Table
```

## Error Handling

```@docs
WasmtimeError
```

## Generic Vector Wrapper

```@docs
WasmVec
WasmByteVec
WasmName
to_julia_vector
```

## Abstract Types

```@docs
WasmtimeObject
WasmtimeResource
WasmtimeValue
WasmtimeType
AbstractEngine
AbstractConfig
AbstractStore
AbstractModule
AbstractInstance
AbstractFunc
AbstractMemory
AbstractGlobal
AbstractTable
```

## Enumerations

```@docs
OptimizationLevel
ProfilingStrategy
```
