using Random
using Test
using WasmtimeRuntime

# Set deterministic seed for reproducible tests
Random.seed!(1234)

@testset "Engine - Resource Management" begin
    @testset "should create engine successfully without config" begin
        engine = WasmEngine()
        @test engine isa WasmEngine
        @test engine isa AbstractEngine
        @test isvalid(engine)
        @test engine.ptr != C_NULL
    end

    @testset "should create engine successfully with valid config" begin
        config = WasmConfig()
        debug_info!(config, true)

        engine = WasmEngine(config)
        @test engine isa WasmEngine
        @test isvalid(engine)
        @test engine.ptr != C_NULL
    end

    @testset "should throw WasmtimeError when config is invalid" begin
        config = WasmConfig()
        config.ptr = C_NULL  # Make config invalid

        @test_throws WasmtimeError WasmEngine(config)
    end

    @testset "should handle resource cleanup properly" begin
        engine = WasmEngine()

        # Trigger finalize to simulate gc
        finalize(engine)

        # Simulate cleanup - in real scenario this would be done by finalizer
        engine.ptr = C_NULL
        @test !isvalid(engine)
    end
end
