using Random
using Test
using WasmtimeRuntime

# Set deterministic seed for reproducible tests
Random.seed!(1234)

@testset "Engine - Resource Management" begin
    @testset "should create engine successfully without config" begin
        engine = Engine()
        @test engine isa Engine
        @test engine isa AbstractEngine
        @test isvalid(engine)
        @test engine.ptr != C_NULL
    end

    @testset "should create engine successfully with valid config" begin
        config = Config()
        debug_info!(config, true)

        engine = Engine(config)
        @test engine isa Engine
        @test isvalid(engine)
        @test engine.ptr != C_NULL
    end

    @testset "should throw WasmtimeError when config is invalid" begin
        config = Config()
        config.ptr = C_NULL  # Make config invalid

        @test_throws WasmtimeError Engine(config)
    end

    @testset "should handle resource cleanup properly" begin
        engine = Engine()

        # Trigger finalize to simulate gc
        finalize(engine)

        # Simulate cleanup - in real scenario this would be done by finalizer
        engine.ptr = C_NULL
        @test !isvalid(engine)
    end
end
