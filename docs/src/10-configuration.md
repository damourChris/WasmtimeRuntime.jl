# Configuration Guide

This guide covers comprehensive configuration of the Wasmtime engine for optimal performance and debugging.

## Basic Configuration

### Default Configuration

```julia
using WasmtimeRuntime

# Default configuration
config = WasmConfig()
engine = WasmEngine(config)
```

### Keyword Constructor

```julia
config = WasmConfig(
    debug_info = true,
    optimization_level = Speed,
    profiling_strategy = NoProfilingStrategy,
    consume_fuel = false,
    epoch_interruption = false,
    max_wasm_stack = 1024 * 1024  # 1MB
)
```

## Configuration Options

### Debug Information

Enable debug information for better error messages and debugging:

```julia
config = WasmConfig()
debug_info!(config, true)
```

Debug info includes:

- Source line mappings
- Function names
- Local variable information

### Optimization Levels

Control compilation optimization:

```julia
# No optimization (fastest compilation)
optimization_level!(config, None)

# Speed optimization (balanced)
optimization_level!(config, Speed)

# Size and speed optimization (slowest compilation)
optimization_level!(config, SpeedAndSize)
```

**Optimization Level Trade-offs:**

- `None`: Fast compilation, slower execution
- `Speed`: Balanced compilation and execution speed
- `SpeedAndSize`: Slower compilation, fastest execution

### Profiling

Enable profiling for performance analysis:

```julia
# No profiling (default)
profiler!(config, NoProfilingStrategy)

# JIT dump profiling (Linux perf)
profiler!(config, JitdumpProfilingStrategy)

# VTune profiling (Intel VTune)
profiler!(config, VTuneProfilingStrategy)

# Performance map profiling
profiler!(config, PerfMapProfilingStrategy)
```

### Resource Limits

#### Fuel Consumption

Limit execution time by tracking "fuel":

```julia
# Enable fuel consumption
consume_fuel!(config, true)
engine = WasmEngine(config)
store = Store(engine)

# Add fuel
add_fuel!(store, 10000)

# Check consumed fuel
consumed = fuel_consumed(store)
```

#### Stack Limits

Control WebAssembly stack size:

```julia
# Set maximum stack size (1MB)
max_wasm_stack!(config, 1024 * 1024)
```

#### Epoch Interruption

Enable epoch-based interruption for long-running computations:

```julia
# Enable epoch interruption
epoch_interruption!(config, true)
engine = WasmEngine(config)
store = Store(engine)

# Set epoch deadline
set_epoch_deadline!(store, 1000)  # 1000 ticks
```

## Method Chaining

Configuration methods return the config object for chaining:

```julia
config = WasmConfig()
    |> c -> debug_info!(c, true)
    |> c -> optimization_level!(c, Speed)
    |> c -> consume_fuel!(c, true)
    |> c -> max_wasm_stack!(c, 2 * 1024 * 1024)

engine = WasmEngine(config)
```

## Common Configuration Patterns

### Development Configuration

Optimal for development and debugging:

```julia
dev_config = Config(
    debug_info = true,
    optimization_level = None,  # Fast compilation
    consume_fuel = true,        # Prevent infinite loops
    max_wasm_stack = 512 * 1024
)
```

### Production Configuration

Optimal for production performance:

```julia
prod_config = Config(
    debug_info = false,
    optimization_level = SpeedAndSize,
    consume_fuel = false,
    epoch_interruption = true,  # For long-running tasks
    max_wasm_stack = 4 * 1024 * 1024
)
```

### Profiling Configuration

For performance analysis:

```julia
profile_config = Config(
    debug_info = true,
    optimization_level = Speed,
    profiling_strategy = VTuneProfilingStrategy,
    consume_fuel = true
)
```

## Configuration Validation

Configurations are validated when creating engines:

```julia
config = WasmConfig()
config.ptr = C_NULL  # Invalid configuration

try
    engine = WasmEngine(config)  # Throws WasmtimeError
catch e::WasmtimeError
    println("Invalid configuration: $(e.message)")
end
```

## Environment-Specific Settings

### Resource-Constrained Environments

```julia
minimal_config = Config(
    debug_info = false,
    optimization_level = None,
    consume_fuel = true,
    max_wasm_stack = 128 * 1024  # 128KB
)
```

### High-Performance Computing

```julia
hpc_config = Config(
    debug_info = false,
    optimization_level = SpeedAndSize,
    consume_fuel = false,
    max_wasm_stack = 16 * 1024 * 1024  # 16MB
)
```

## Configuration Lifecycle

Configurations are consumed when creating engines:

```julia
config = WasmConfig()
debug_info!(config, true)

engine = WasmEngine(config)
# config is now consumed and cannot be reused

# This would throw an error:
# engine2 = WasmEngine(config)  # Error: config already consumed
```

## Best Practices

1. **Create configurations once** per application lifecycle
2. **Share engines** across multiple stores when possible
3. **Enable fuel consumption** during development to catch infinite loops
4. **Use appropriate optimization levels** based on deployment needs
5. **Set reasonable stack limits** to prevent memory exhaustion
6. **Enable debug info** only when needed (impacts performance)

## Troubleshooting

### Common Configuration Errors

```julia
# Invalid configuration usage
config = WasmConfig()
engine1 = WasmEngine(config)
# engine2 = WasmEngine(config)  # Error: consumed config

# Solution: Create new config
config2 = WasmConfig()
engine2 = Engine(config2)
```

### Performance Issues

If WebAssembly execution is slow:

1. Check optimization level (use `SpeedAndSize` for production)
2. Disable debug info in production
3. Verify fuel consumption isn't enabled unnecessarily
4. Increase stack size if needed

### Memory Issues

If running out of memory:

1. Reduce `max_wasm_stack` size
2. Enable fuel consumption to limit execution
3. Use epoch interruption for long-running tasks
4. Monitor store lifetime and cleanup
