using Random
using Test
using WasmtimeRuntime

Random.seed!(1234)

@testset "General Wasm Function Tests" begin
    @testset "should create a valid WASM func" begin
        # Create a simple julia function
        function add(x::Int, y::Int)::Int
            return x + y
        end

        # Create a store
        engine = WasmEngine()
        store = WasmStore(engine)

        # Create the function
        wasm_func = WasmFunc(store, add)

        # Try to call the function
        result = wasm_func(3, 4)

        @test result == WasmValue(7)
    end

    @testset "should error gracefully with useful error message on wrong args" begin

        # @testset "wrong type" begin
        #     function add(x::Int, y::Int)::Int
        #         return x + y
        #     end

        #     # Create a store
        #     engine = WasmEngine()
        #     store = WasmStore(engine)

        #     # Create the function
        #     wasm_func = WasmFunc(store, add)

        #     # Try to call the function
        #     @test_throws WasmtimeError wasm_func("string", 4)
        #     @test_throws WasmtimeError wasm_func("string", "string")
        #     @test_throws WasmtimeError wasm_func(x -> x^2, "string")
        # end
        @testset "wrong number of arg" begin
            function add(x::Int, y::Int)::Int
                return x + y
            end

            # Create a store
            engine = WasmEngine()
            store = WasmStore(engine)

            # Create the function
            wasm_func = WasmFunc(store, add)

            # Try to call the function
            @test_throws WasmtimeError wasm_func(4)
            @test_throws WasmtimeError wasm_func(4, 2, 4)
        end
    end

    # Future implementation
    # @testset "should create a valid WASM func with multiple signatures" begin
    #     # Create a simple julia function with multiple signatures
    #     function add(x::Int, y::Int)::Int
    #         return x + y
    #     end

    #     # function add(x::Float64, y::Float64)::Float64
    #     #     return x + y
    #     # end

    #     # Create a store
    #     engine = WasmEngine()
    #     store = WasmStore(engine)

    #     # Create the function
    #     wasm_func = WasmFunc(store, add)

    #     # Try to call the function with both signatures
    #     result_int = wasm_func(3, 4)
    #     @test result_int == WasmValue(7)

    #     # result_float = wasm_func(3.0, 4.0)
    #     # @test result_float == WasmValue(7.0)

    #     # # Clean up
    #     # finalizer(wasm_func)
    # end
end
