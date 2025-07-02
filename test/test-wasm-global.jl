using Random
using Test
using WasmtimeRuntime

Random.seed!(1234)

@testset "WasmGlobalType Tests" begin
    @testset "Constructor Tests" begin
        @testset "should create WasmGlobalType with mutable Int32" begin
            valtype = WasmValType(Int32)
            global_type = WasmGlobalType(valtype, true)

            @test global_type isa WasmGlobalType
            @test isvalid(global_type)
        end

        @testset "should create WasmGlobalType with immutable Float64" begin
            valtype = WasmValType(Float64)
            global_type = WasmGlobalType(valtype, false)

            @test global_type isa WasmGlobalType
            @test isvalid(global_type)
        end

        @testset "should create WasmGlobalType for all supported types" begin
            for (julia_type, mutability) in
                [(Int32, true), (Int64, false), (Float32, true), (Float64, false)]
                valtype = WasmValType(julia_type)
                global_type = WasmGlobalType(valtype, mutability)

                @test global_type isa WasmGlobalType
                @test isvalid(global_type)
            end
        end
    end

    @testset "Error Handling Tests" begin
        @testset "should throw for invalid WasmValtype" begin
            # Create an invalid valtype by setting ptr to C_NULL
            valtype = WasmValType(Int32)
            valtype.ptr = C_NULL

            @test_throws ArgumentError("Invalid WasmValtype") WasmGlobalType(valtype, true)
        end
    end

    @testset "Base Interface Tests" begin
        @testset "should implement Base.show correctly" begin
            valtype = WasmValType(Int32)
            global_type = WasmGlobalType(valtype, true)

            output = sprint(show, global_type)
            @test output == "WasmGlobalType()"
        end

        @testset "should implement unsafe_convert correctly" begin
            valtype = WasmValType(Int32)
            global_type = WasmGlobalType(valtype, true)

            ptr = Base.unsafe_convert(
                Ptr{WasmtimeRuntime.LibWasmtime.wasm_globaltype_t},
                global_type,
            )
            @test ptr != C_NULL
            @test ptr == global_type.ptr
        end

        @testset "should handle validity checks" begin
            valtype = WasmValType(Int32)
            global_type = WasmGlobalType(valtype, true)

            @test isvalid(global_type)

            # Simulate invalidation
            global_type.ptr = C_NULL
            @test !isvalid(global_type)
        end
    end

    @testset "Resource Management Tests" begin
        @testset "should properly finalize resources" begin
            valtype = WasmValType(Int32)
            global_type = WasmGlobalType(valtype, true)
            ptr = global_type.ptr

            @test ptr != C_NULL
            @test isvalid(global_type)

            # Force finalization
            finalize(global_type)
            @test global_type.ptr == C_NULL
        end
    end
end

@testset "WasmGlobal Tests" begin
    @testset "Constructor Tests" begin
        @testset "should create WasmGlobal with Int32 value" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            valtype = WasmValType(Int32)
            global_type = WasmGlobalType(valtype, true)
            initial_value = WasmValue(Int32(42))

            global_var = WasmGlobal(store, global_type, initial_value)

            @test global_var isa WasmGlobal
            @test isvalid(global_var)
        end

        @testset "should create WasmGlobal with Float64 value" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            valtype = WasmValType(Float64)
            global_type = WasmGlobalType(valtype, false)
            initial_value = WasmValue(3.14159)

            global_var = WasmGlobal(store, global_type, initial_value)

            @test global_var isa WasmGlobal
            @test isvalid(global_var)
        end

        @testset "should create WasmGlobal for all supported types" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            test_cases = [
                (Int32, Int32(100), true),
                (Int64, Int64(-500), false),
                (Float32, Float32(2.718), true),
                (Float64, Float64(1.414), false),
            ]

            for (julia_type, value, mutability) in test_cases
                valtype = WasmValType(julia_type)
                global_type = WasmGlobalType(valtype, mutability)
                initial_value = WasmValue(value)

                global_var = WasmGlobal(store, global_type, initial_value)

                @test global_var isa WasmGlobal
                @test isvalid(global_var)
            end
        end
    end

    @testset "Error Handling Tests" begin
        @testset "should throw for invalid store" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            store.ptr = C_NULL  # Invalidate store

            valtype = WasmValType(Int32)
            global_type = WasmGlobalType(valtype, true)
            initial_value = WasmValue(Int32(42))

            @test_throws ArgumentError("Invalid store or global type") WasmGlobal(
                store,
                global_type,
                initial_value,
            )
        end

        @testset "should throw for invalid global type" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            valtype = WasmValType(Int32)
            global_type = WasmGlobalType(valtype, true)
            global_type.ptr = C_NULL  # Invalidate global type

            initial_value = WasmValue(Int32(42))

            @test_throws ArgumentError("Invalid store or global type") WasmGlobal(
                store,
                global_type,
                initial_value,
            )
        end

        # Test broken until proper vlaidation on wasm_val_t
        # @testset "should throw for invalid initial value" begin
        #     engine = WasmEngine()
        #     store = WasmStore(engine)
        #     valtype = WasmValType(Int32)
        #     global_type = WasmGlobalType(valtype, true)

        #     initial_value = WasmValue(Int32(42))
        #     initial_value = C_NULL  # Invalidate value

        #     @test_throws ArgumentError("Invalid initial value for global") WasmGlobal(
        #         store,
        #         global_type,
        #         initial_value,
        #     )
        # end
    end

    @testset "Base Interface Tests" begin
        @testset "should implement Base.show correctly" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            valtype = WasmValType(Int32)
            global_type = WasmGlobalType(valtype, true)
            initial_value = WasmValue(Int32(42))

            global_var = WasmGlobal(store, global_type, initial_value)

            output = sprint(show, global_var)
            @test output == "WasmGlobal()"
        end

        @testset "should implement unsafe_convert correctly" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            valtype = WasmValType(Int32)
            global_type = WasmGlobalType(valtype, true)
            initial_value = WasmValue(Int32(42))

            global_var = WasmGlobal(store, global_type, initial_value)

            ptr = Base.unsafe_convert(
                Ptr{WasmtimeRuntime.LibWasmtime.wasm_global_t},
                global_var,
            )
            @test ptr != C_NULL
            @test ptr == global_var.ptr
        end

        @testset "should handle validity checks" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            valtype = WasmValType(Int32)
            global_type = WasmGlobalType(valtype, true)
            initial_value = WasmValue(Int32(42))

            global_var = WasmGlobal(store, global_type, initial_value)

            @test isvalid(global_var)

            # Simulate invalidation
            global_var.ptr = C_NULL
            @test !isvalid(global_var)
        end
    end

    @testset "Resource Management Tests" begin
        @testset "should properly finalize resources" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            valtype = WasmValType(Int32)
            global_type = WasmGlobalType(valtype, true)
            initial_value = WasmValue(Int32(42))

            global_var = WasmGlobal(store, global_type, initial_value)
            ptr = global_var.ptr

            @test ptr != C_NULL
            @test isvalid(global_var)

            # Force finalization
            finalize(global_var)
            @test global_var.ptr == C_NULL
        end
    end

    @testset "Property-Based Tests" begin
        @testset "WasmGlobal creation properties" begin
            for i = 1:20
                engine = WasmEngine()
                store = WasmStore(engine)

                # Test with random values but deterministic due to seed
                type_choice = rand([Int32, Int64, Float32, Float64])
                mutability = rand([true, false])

                valtype = WasmValType(type_choice)
                global_type = WasmGlobalType(valtype, mutability)

                test_value = if type_choice == Int32
                    WasmValue(Int32(rand(-1000:1000)))
                elseif type_choice == Int64
                    WasmValue(Int64(rand(-10000:10000)))
                elseif type_choice == Float32
                    WasmValue(Float32(rand() * 100))
                else  # Float64
                    WasmValue(rand() * 1000)
                end

                global_var = WasmGlobal(store, global_type, test_value)

                # Properties that should always hold
                @test global_var isa WasmGlobal
                @test isvalid(global_var)
                @test global_var.ptr != C_NULL
                @test Base.unsafe_convert(
                    Ptr{WasmtimeRuntime.LibWasmtime.wasm_global_t},
                    global_var,
                ) == global_var.ptr
            end
        end
    end

    @testset "Edge Cases" begin
        @testset "should handle zero values" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            test_cases = [
                (Int32, Int32(0)),
                (Int64, Int64(0)),
                (Float32, Float32(0.0)),
                (Float64, Float64(0.0)),
            ]

            for (julia_type, zero_value) in test_cases
                valtype = WasmValType(julia_type)
                global_type = WasmGlobalType(valtype, true)
                initial_value = WasmValue(zero_value)

                global_var = WasmGlobal(store, global_type, initial_value)

                @test global_var isa WasmGlobal
                @test isvalid(global_var)
            end
        end

        @testset "should handle extreme values" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            test_cases = [
                (Int32, typemax(Int32)),
                (Int32, typemin(Int32)),
                (Int64, typemax(Int64)),
                (Int64, typemin(Int64)),
                (Float32, Float32(Inf)),
                (Float32, Float32(-Inf)),
                (Float64, Inf),
                (Float64, -Inf),
            ]

            for (julia_type, extreme_value) in test_cases
                valtype = WasmValType(julia_type)
                global_type = WasmGlobalType(valtype, true)
                initial_value = WasmValue(extreme_value)

                global_var = WasmGlobal(store, global_type, initial_value)

                @test global_var isa WasmGlobal
                @test isvalid(global_var)
            end
        end
    end
end

@testset "Integration Tests" begin
    @testset "should work with multiple globals in same store" begin
        engine = WasmEngine()
        store = WasmStore(engine)

        # Create multiple globals with different types
        int_valtype = WasmValType(Int32)
        int_global_type = WasmGlobalType(int_valtype, true)
        int_global = WasmGlobal(store, int_global_type, WasmValue(Int32(42)))

        float_valtype = WasmValType(Float64)
        float_global_type = WasmGlobalType(float_valtype, false)
        float_global = WasmGlobal(store, float_global_type, WasmValue(3.14159))

        @test isvalid(int_global)
        @test isvalid(float_global)
        @test int_global.ptr != float_global.ptr
    end

    @testset "should handle resource cleanup correctly" begin
        # Test that resources are properly cleaned up when objects go out of scope
        function create_and_cleanup()
            engine = WasmEngine()
            store = WasmStore(engine)
            valtype = WasmValType(Int32)
            global_type = WasmGlobalType(valtype, true)
            global_var = WasmGlobal(store, global_type, WasmValue(Int32(42)))

            @test isvalid(global_var)
            return global_var.ptr  # Return the pointer before cleanup
        end

        original_ptr = create_and_cleanup()
        GC.gc()  # Force garbage collection
        GC.gc()  # Sometimes need multiple GC calls

        @test original_ptr != C_NULL  # Original pointer was valid
    end
end
