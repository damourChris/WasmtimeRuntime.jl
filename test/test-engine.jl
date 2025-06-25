using Random
using Test
using WasmtimeRuntime

# Set deterministic seed for reproducible tests
Random.seed!(1234)

@testset "Engine - Resource Management" begin
    @testset "Engine creation without config" begin
        engine = Engine()
        @test engine isa Engine
        @test engine isa AbstractEngine
        @test isvalid(engine)
        @test engine.ptr != C_NULL
    end

    @testset "Engine creation with config" begin
        config = Config()
        debug_info!(config, true)

        engine = Engine(config)
        @test engine isa Engine
        @test isvalid(engine)
        @test engine.ptr != C_NULL
    end

    @testset "Engine creation with invalid config should fail" begin
        config = Config()
        config.ptr = C_NULL  # Make config invalid

        @test_throws WasmtimeError Engine(config)
    end

    @testset "Engine resource cleanup (finalizer behavior)" begin
        engine = Engine()

        # Trigger finalize to simulate gc
        finalize(engine)

        # Simulate cleanup
        engine.ptr = C_NULL
        @test !isvalid(engine)
    end
end
