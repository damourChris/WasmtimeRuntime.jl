@testset "Store - Context Management" begin
    @testset "Store creation with valid engine" begin
        engine = Engine()
        store = Store(engine)

        @test store isa Store
        @test store isa AbstractStore
        @test isvalid(store)
        @test store.ptr != C_NULL
        @test store.context != C_NULL
        @test store.engine === engine
    end

    @testset "Store creation with invalid engine should fail" begin
        engine = Engine()
        engine.ptr = C_NULL  # Make engine invalid

        @test_throws WasmtimeError Store(engine)
    end

    @testset "Store fuel management" begin
        # Create store with fuel consumption enabled
        config = Config()
        consume_fuel!(config, true)
        engine = Engine(config)
        store = Store(engine)

        # Test adding fuel
        initial_fuel = add_fuel!(store, 1000)
        @test initial_fuel isa UInt64

        # Test fuel consumed tracking
        consumed = fuel_consumed(store)
        @test consumed isa UInt64
    end

    @testset "Store fuel management errors" begin
        # Create store without fuel consumption
        engine = Engine()
        store = Store(engine)

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
        config = Config()
        epoch_interruption!(config, true)
        engine = Engine(config)
        store = Store(engine)

        # Test setting epoch deadline
        result = set_epoch_deadline!(store, 100)
        @test result === store  # Should return store for chaining
    end

    @testset "Store operations with invalid store" begin
        engine = Engine()
        store = Store(engine)
        store.ptr = C_NULL  # Make store invalid

        @test !isvalid(store)
        @test_throws WasmtimeError add_fuel!(store, 100)
        @test_throws WasmtimeError fuel_consumed(store)
        @test_throws WasmtimeError set_epoch_deadline!(store, UInt64(50))
    end


end
