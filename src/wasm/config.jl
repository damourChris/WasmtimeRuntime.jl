# Configuration management for WasmtimeRuntime

# Configuration builder pattern
mutable struct WasmConfig <: AbstractConfig
    ptr::Ptr{LibWasmtime.wasm_config_t}
    consumed::Bool  # Track if config has been consumed by engine creation

    function WasmConfig(ptr::Ptr{LibWasmtime.wasm_config_t})
        if ptr == C_NULL
            throw(WasmtimeError("Failed to create Config"))
        end
        config = new(ptr, false)
        finalizer(config) do c
            if c.ptr != C_NULL && !c.consumed
                LibWasmtime.wasm_config_delete(c.ptr)
                c.ptr = C_NULL
            else
                # if config was consumed, c.ptr should already be null but in case
                c.ptr = C_NULL  # Prevent double deletion
            end
        end
        return config
    end
end

# Public constructor with keyword arguments (also works as default constructor)
function WasmConfig(;
    debug_info::Bool = false,
    optimization_level::OptimizationLevel = Speed,
    profiling_strategy::ProfilingStrategy = NoProfilingStrategy,
    consume_fuel::Bool = false,
    epoch_interruption::Bool = false,
    max_wasm_stack::Union{Integer,Nothing} = nothing,
)
    # Create basic config first
    ptr = LibWasmtime.wasm_config_new()
    config = WasmConfig(ptr)  # Use internal constructor

    try
        # Apply configuration options
        debug_info!(config, debug_info)
        optimization_level!(config, optimization_level)
        profiler!(config, profiling_strategy)
        consume_fuel!(config, consume_fuel)
        epoch_interruption!(config, epoch_interruption)

        if max_wasm_stack !== nothing
            max_wasm_stack!(config, max_wasm_stack)
        end

        return config
    catch e
        # Clean up on error - the finalizer will handle cleanup automatically
        rethrow(e)
    end
end

Base.isvalid(config::WasmConfig) = config.ptr != C_NULL && !config.consumed

# Mark config as consumed (used internally by Engine constructor)
function _consume!(config::WasmConfig)
    config.consumed = true
    return config
end

# Fluent configuration API - return config for method chaining
function debug_info!(config::WasmConfig, enable::Bool = true)
    isvalid(config) || throw(WasmtimeError("Invalid config"))
    LibWasmtime.wasmtime_config_debug_info_set(config.ptr, enable)
    return config
end

function optimization_level!(config::WasmConfig, level::OptimizationLevel)
    isvalid(config) || throw(WasmtimeError("Invalid config"))
    LibWasmtime.wasmtime_config_cranelift_opt_level_set(config.ptr, UInt8(level))
    return config
end

function profiler!(config::WasmConfig, strategy::ProfilingStrategy)
    isvalid(config) || throw(WasmtimeError("Invalid config"))
    LibWasmtime.wasmtime_config_profiler_set(config.ptr, Int32(strategy))
    return config
end

function consume_fuel!(config::WasmConfig, enable::Bool = true)
    isvalid(config) || throw(WasmtimeError("Invalid config"))
    LibWasmtime.wasmtime_config_consume_fuel_set(config.ptr, enable)
    return config
end

function epoch_interruption!(config::WasmConfig, enable::Bool = true)
    isvalid(config) || throw(WasmtimeError("Invalid config"))
    LibWasmtime.wasmtime_config_epoch_interruption_set(config.ptr, enable)
    return config
end

function max_wasm_stack!(config::WasmConfig, size::Integer)
    isvalid(config) || throw(WasmtimeError("Invalid config"))
    LibWasmtime.wasmtime_config_max_wasm_stack_set(config.ptr, size)
    return config
end
