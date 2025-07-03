# Performance Guide

This guide covers performance optimization techniques for WasmtimeRuntime.jl, focusing on currently implemented features and configuration options.

## Engine Configuration for Performance (✅ Working)

### Optimization Levels

Choose the right optimization level for your use case:

```julia
# Development: Fast compilation, slower execution
dev_config = WasmConfig(optimization_level = None)

# Balanced: Good compromise between compilation time and execution speed
balanced_config = WasmConfig(optimization_level = Speed)

# Production: Slower compilation, fastest execution
prod_config = WasmConfig(optimization_level = SpeedAndSize)
```

**Performance Impact:**

- `None`: ~10x faster compilation, ~3-5x slower execution
- `Speed`: Balanced performance
- `SpeedAndSize`: ~3-5x slower compilation, optimal execution speed

### Debug Information Impact

Debug information affects both compilation time and memory usage:

```julia
# Production configuration - no debug info
prod_config = WasmConfig(
    debug_info = false,
    optimization_level = SpeedAndSize
)

# Development configuration - with debug info
dev_config = WasmConfig(
    debug_info = true,
    optimization_level = None
)
```

**Impact:** Debug info can increase:

- Compilation time by 20-30%
- Memory usage by 15-25%
- Binary size by 30-50%

### Profiling Configuration

Enable profiling only when needed:

```julia
# Production without profiling
config = WasmConfig(profiling_strategy = NoProfilingStrategy)

# Performance analysis with profiling
profile_config = WasmConfig(
    profiling_strategy = VTuneProfilingStrategy,
    optimization_level = Speed  # Don't use None with profiling
)
```

## Resource Management Optimization (✅ Working)

### Engine Reuse

Engines are expensive to create but cheap to share:

```julia
# ❌ Inefficient: Creating engines repeatedly
function bad_pattern()
    for i in 1:100
        engine = WasmEngine()  # Expensive!
        store = WasmStore(engine)
        # ... use store
    end
end

# ✅ Efficient: Reuse engine
function good_pattern()
    engine = WasmEngine()  # Create once
    for i in 1:100
        store = WasmStore(engine)  # Cheap!
        # ... use store
    end
end
```

### Module Caching

Compile modules once, instantiate many times:

```julia
# ✅ Efficient module management
struct ModuleCache
    engine::WasmEngine
    modules::Dict{String, WasmModule}
end

function get_module(cache::ModuleCache, path::String)
    if !haskey(cache.modules, path)
        wasm_bytes = read(path)
        cache.modules[path] = WasmModule(cache.engine, wasm_bytes)
    end
    return cache.modules[path]
end

# Usage
cache = ModuleCache(WasmEngine(), Dict())
module1 = get_module(cache, "module.wasm")  # Compiles
module2 = get_module(cache, "module.wasm")  # Cache hit!
```

### Store Lifecycle Management

Optimize store creation patterns:

```julia
# ✅ Batch operations per store
function batch_operations(engine, module_obj, operations)
    store = WasmStore(engine)
    instance = WasmInstance(store, module_obj)

    # Note: Function calling not yet implemented
    # This demonstrates the intended optimization pattern
    # when function calling becomes available

    return instance
    # Store and instance cleaned up automatically
end

# ❌ One store per operation (inefficient when function calling is available)
function inefficient_operations(engine, module_obj, operations)
    results = []
    for op in operations
        store = WasmStore(engine)  # Expensive per operation!
        instance = WasmInstance(store, module_obj)
        # result = call(instance, op.func_name, op.params)  # Future API
        # push!(results, result)
    end
    return results
end
```

## Function Call Optimization (📋 Coming Soon)

**⚠️ Note:** Function calling functionality is under development. Performance guidance will be added when implemented.

### Type-Safe Function Calls

Use typed functions for better performance:

```julia
# ✅ Type-safe calls (faster)
add_func = TypedFunc{Tuple{Int32, Int32}, Int32}(func)
result = call(add_func, Int32(1), Int32(2))

# ❌ Generic calls with type conversion (slower)
result = call(instance, "add", [1, 2])  # Requires type inference and conversion
```

### Batch Parameter Conversion

Pre-convert parameters for repeated calls:

```julia
# ✅ Efficient batch processing
function batch_process_optimized(instance, func_name, param_sets)
    func = get_func(instance, func_name)

    # Pre-convert all parameters
    converted_params = [
        [to_wasm(p) for p in params]
        for params in param_sets
    ]

    # Efficient calls with pre-converted parameters
    return [call(func, params) for params in converted_params]
end

# ❌ Convert parameters on each call
function batch_process_slow(instance, func_name, param_sets)
    return [call(instance, func_name, params) for params in param_sets]
end
```

## Memory Management Performance

### Memory Layout Optimization

Optimize memory access patterns:

```julia
# ✅ Sequential memory access (cache-friendly)
function process_memory_sequential(memory, start_offset, count)
    for i in 0:count-1
        offset = start_offset + i * 4  # 4 bytes per item
        # Process memory at offset
    end
end

# ❌ Random memory access (cache-unfriendly)
function process_memory_random(memory, offsets)
    for offset in shuffle(offsets)  # Random order
        # Process memory at offset
    end
end
```

### Stack Size Optimization

Configure appropriate stack sizes:

```julia
# For recursive algorithms
large_stack_config = Config(max_wasm_stack = 4 * 1024 * 1024)  # 4MB

# For simple computations
small_stack_config = Config(max_wasm_stack = 256 * 1024)       # 256KB

# Memory-constrained environments
minimal_stack_config = Config(max_wasm_stack = 64 * 1024)      # 64KB
```

## Concurrent Execution Patterns

### Engine Sharing Across Threads

```julia
# Shared engine, per-thread stores
const SHARED_ENGINE = Engine(Config(optimization_level = SpeedAndSize))

function parallel_wasm_execution(module_path, operations)
    module_obj = WasmModule(SHARED_ENGINE, module_path)

    # Use ThreadsX for parallel execution
    results = ThreadsX.map(operations) do op
        # Each thread gets its own store
        store = Store(SHARED_ENGINE)
        instance = Instance(store, module_obj)
        return call(instance, op.func_name, op.params)
    end

    return results
end
```

### Thread-Local Storage Pattern

```julia
# Thread-local caches for better performance
const THREAD_LOCAL_CACHE = Dict{Int, ModuleCache}()

function get_thread_cache()
    tid = Threads.threadid()
    if !haskey(THREAD_LOCAL_CACHE, tid)
        THREAD_LOCAL_CACHE[tid] = ModuleCache(SHARED_ENGINE, Dict())
    end
    return THREAD_LOCAL_CACHE[tid]
end
```

## Fuel and Resource Limiting

### Smart Fuel Management

Balance security and performance:

```julia
# High-performance configuration (no fuel)
perf_config = Config(consume_fuel = false)

# Secure configuration with fuel limiting
secure_config = Config(consume_fuel = true)

function adaptive_fuel_management(store, estimated_complexity)
    if estimated_complexity > 1000
        # Complex operation: add more fuel
        add_fuel!(store, 100000)
    else
        # Simple operation: minimal fuel
        add_fuel!(store, 10000)
    end
end
```

### Epoch-Based Interruption

For long-running tasks:

```julia
# Enable epoch interruption for responsiveness
responsive_config = Config(
    epoch_interruption = true,
    consume_fuel = false  # Use epochs instead of fuel
)

function long_running_computation(store, instance)
    # Set reasonable epoch deadline
    set_epoch_deadline!(store, 1000)  # Allow 1000 epoch ticks

    try
        return call(instance, "long_computation", [])
    catch e::WasmtimeError
        if occursin("epoch", lowercase(e.message))
            @warn "Computation interrupted by epoch deadline"
            return nothing
        else
            rethrow(e)
        end
    end
end
```

## Performance Monitoring

### Timing Measurements

```julia
function benchmark_wasm_call(instance, func_name, params, iterations=1000)
    # Warmup
    for _ in 1:10
        call(instance, func_name, params)
    end

    # Benchmark
    times = Float64[]
    for _ in 1:iterations
        start_time = time_ns()
        call(instance, func_name, params)
        end_time = time_ns()
        push!(times, (end_time - start_time) / 1e9)  # Convert to seconds
    end

    return (
        mean = sum(times) / length(times),
        min = minimum(times),
        max = maximum(times),
        std = sqrt(sum((t - sum(times)/length(times))^2 for t in times) / length(times))
    )
end
```

### Memory Usage Monitoring

```julia
function monitor_memory_usage(f)
    gc_before = GC.gc_num()
    memory_before = Sys.total_memory()

    result = f()

    GC.gc()  # Force garbage collection
    gc_after = GC.gc_num()
    memory_after = Sys.total_memory()

    return (
        result = result,
        gc_runs = gc_after.poolalloc - gc_before.poolalloc,
        memory_delta = memory_after - memory_before
    )
end
```

### Performance Profiling Integration

```julia
using Profile

function profile_wasm_execution(instance, func_name, params)
    # Clear previous profiles
    Profile.clear()

    # Profile the execution
    @profile begin
        for _ in 1:100
            call(instance, func_name, params)
        end
    end

    # Print profile results
    Profile.print()
end
```

## Optimization Techniques

### Instance Pooling

```julia
mutable struct InstancePool
    engine::Engine
    module_obj::WasmModule
    available::Channel{Instance}
    max_size::Int
    current_size::Int
end

function InstancePool(engine, module_obj, max_size=10)
    return InstancePool(
        engine,
        module_obj,
        Channel{Instance}(max_size),
        max_size,
        0
    )
end

function borrow_instance(pool::InstancePool)
    if isready(pool.available)
        return take!(pool.available)
    elseif pool.current_size < pool.max_size
        pool.current_size += 1
        store = Store(pool.engine)
        return Instance(store, pool.module_obj)
    else
        # Block until instance available
        return take!(pool.available)
    end
end

function return_instance(pool::InstancePool, instance::Instance)
    put!(pool.available, instance)
end

# Usage with do-block for automatic return
function with_pooled_instance(f, pool::InstancePool)
    instance = borrow_instance(pool)
    try
        return f(instance)
    finally
        return_instance(pool, instance)
    end
end
```

### JIT Warmup Strategy

```julia
function warmup_module(instance, exported_functions)
    @info "Warming up WebAssembly module..."

    for func_name in exported_functions
        try
            # Call with dummy parameters to trigger JIT compilation
            # This is function-specific and requires knowledge of signatures
            call(instance, func_name, [0])
        catch e::WasmtimeError
            # Expected for functions with different signatures
            @debug "Warmup failed for $func_name: $(e.message)"
        end
    end

    @info "Module warmup completed"
end
```

## Performance Best Practices

### Configuration Guidelines

1. **Production**: Use `SpeedAndSize` optimization, disable debug info
2. **Development**: Use `None` optimization, enable debug info
3. **Testing**: Use `Speed` optimization, selective debug info
4. **Profiling**: Use `Speed` optimization, enable profiling strategy

### Resource Management Guidelines

1. **Reuse engines** across multiple stores and modules
2. **Cache compiled modules** when loading the same WASM multiple times
3. **Batch operations** within single store instances
4. **Use typed functions** for frequently called functions
5. **Minimize parameter conversion** overhead

### Memory Guidelines

1. **Set appropriate stack sizes** based on recursion depth
2. **Use fuel limiting** only when security is required
3. **Prefer epoch interruption** over fuel for long-running tasks
4. **Monitor memory usage** in long-running applications

### Concurrency Guidelines

1. **Share engines** across threads safely
2. **Use thread-local stores** for concurrent execution
3. **Implement instance pooling** for high-throughput scenarios
4. **Avoid shared state** between WebAssembly instances

By following these performance optimization techniques, you can achieve optimal performance for your WebAssembly applications while maintaining security and reliability.
