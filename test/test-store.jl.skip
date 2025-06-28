using Random
using Test
using WasmtimeRuntime

# Set deterministic seed for reproducible tests
Random.seed!(1234)

@testset "Store - Context Management" begin
    @testset "should create store successfully with valid engine" begin
        engine = WasmEngine()
        store = WasmStore(engine)

        @test store isa WasmStore
        @test store isa AbstractStore
        @test isvalid(store)
        @test store.ptr != C_NULL
    end

    @testset "should throw WasmtimeError when engine is invalid" begin
        engine = WasmEngine()
        engine.ptr = C_NULL  # Make engine invalid

        @test_throws WasmtimeError WasmStore(engine)
    end

    @testset "Store fuel management" begin
        # Create store with fuel consumption enabled
        config = WasmConfig()
        consume_fuel!(config, true)
        engine = WasmEngine(config)
        store = WasmtimeStore(engine)

        # Test adding fuel
        initial_fuel = add_fuel!(store, 1000)
        @test initial_fuel isa UInt64

        # Test fuel consumed tracking
        consumed = fuel_consumed(store)
        @test consumed isa UInt64
    end

    @testset "Store fuel management errors" begin
        # Create store without fuel consumption
        engine = WasmEngine()
        store = WasmtimeStore(engine)

        # Adding fuel to a store without fuel consumption enabled
        # might work or might fail, depending on Wasmtime version
        # Let's just test that it doesn't crash
        try
            add_fuel!(store, 500)
            # If it succeeds, that's fine
        catch WasmtimeError
            # If it fails with WasmtimeError, that's also expected
        end

        # fuel_consumed should fail if fuel tracking not enabled
        @test_throws WasmtimeError fuel_consumed(store)
    end

    @testset "Store epoch management" begin
        config = WasmConfig()
        epoch_interruption!(config, true)
        engine = WasmEngine(config)
        store = WasmtimeStore(engine)

        # Test setting epoch deadline
        result = set_epoch_deadline!(store, 100)
        @test result === store  # Should return store for chaining
    end

    @testset "Store operations with invalid store" begin
        engine = WasmEngine()
        store = WasmtimeStore(engine)
        store.ptr = C_NULL  # Make store invalid

        @test !isvalid(store)
        @test_throws WasmtimeError add_fuel!(store, 100)
        @test_throws WasmtimeError fuel_consumed(store)
        @test_throws WasmtimeError set_epoch_deadline!(store, UInt64(50))
    end


end
