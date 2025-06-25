using Test
using Random
using WasmtimeRuntime

# Set deterministic seed for reproducible tests
Random.seed!(1234)

@testset "Config - Builder Pattern Implementation" begin
    @testset "Config creation and basic properties" begin
        # Test default constructor
        config = Config()
        @test config isa Config
        @test config isa AbstractConfig
        @test isvalid(config)

        # Test that config has a valid pointer
        @test config.ptr != C_NULL
    end

    @testset "Config fluent API - method chaining" begin
        config = Config()

        # Test that fluent methods return the config for chaining
        result1 = debug_info!(config, true)
        @test result1 === config

        result2 = optimization_level!(config, Speed)
        @test result2 === config

        result3 = profiler!(config, JitdumpProfilingStrategy)
        @test result3 === config

        result4 = consume_fuel!(config, true)
        @test result4 === config

        result5 = epoch_interruption!(config, false)
        @test result5 === config

        result6 = max_wasm_stack!(config, 1024)
        @test result6 === config
    end

    @testset "Config method chaining workflow" begin
        # Test complete fluent chain
        config = Config()
        debug_info!(config, true)
        optimization_level!(config, SpeedAndSize)
        profiler!(config, VTuneProfilingStrategy)
        consume_fuel!(config, true)
        epoch_interruption!(config, true)
        max_wasm_stack!(config, 2048)

        @test isvalid(config)
        @test config.ptr != C_NULL
        @test config.consumed == false  # Should not be consumed yet
    end

    @testset "Config error handling with invalid config" begin
        config = Config()
        # Simulate invalid config by setting ptr to NULL
        config.ptr = C_NULL

        @test !isvalid(config)
        @test_throws WasmtimeError debug_info!(config, true)
        @test_throws WasmtimeError optimization_level!(config, Speed)
        @test_throws WasmtimeError profiler!(config, NoProfilingStrategy)
        @test_throws WasmtimeError consume_fuel!(config, true)
        @test_throws WasmtimeError epoch_interruption!(config, true)
        @test_throws WasmtimeError max_wasm_stack!(config, 1024)
    end

    @testset "Config keyword constructor" begin
        # Test default values
        config1 = Config()
        @test isvalid(config1)

        # Test with specific options
        config2 = Config(
            debug_info = true,
            optimization_level = SpeedAndSize,
            profiling_strategy = JitdumpProfilingStrategy,
            consume_fuel = true,
            epoch_interruption = false,
            max_wasm_stack = 4096,
        )
        @test isvalid(config2)
    end

    @testset "Config finalization and cleanup" begin
        # Test that finalizer cleans up resources
        config = Config()
        ptr_before = config.ptr
        config.consumed = true

        # Trigger finalize to simulate gc
        finalize(config)

        @test config.ptr == C_NULL  # Should be cleaned up
        @test !isvalid(config)  # Should no longer be valid
    end
end
