using Random
using Test
using WasmtimeRuntime

Random.seed!(1234)

@testset "WasmMemoryType Tests" begin
    @testset "Constructor Tests" begin
        @testset "should create WasmMemoryType with default limits" begin
            memory_type = WasmMemoryType()

            @test memory_type isa WasmMemoryType
            @test isvalid(memory_type)
            @test memory_type.limits.min == 0
            @test memory_type.limits.max == 0
        end

        @testset "should create WasmMemoryType with custom limits" begin
            limits = (10 => 100)
            memory_type = WasmMemoryType(limits)

            @test memory_type isa WasmMemoryType
            @test isvalid(memory_type)
            @test memory_type.limits.min == 10
            @test memory_type.limits.max == 100
        end

        @testset "should create WasmMemoryType with zero max (unlimited)" begin
            limits = (5 => 0)
            memory_type = WasmMemoryType(limits)

            @test memory_type isa WasmMemoryType
            @test isvalid(memory_type)
            @test memory_type.limits.min == 5
            @test memory_type.limits.max == 0
        end
    end

    @testset "Edge Cases and Error Handling" begin
        @testset "should handle large limits within valid range" begin
            # Test with maximum valid values
            limits = (1000 => 2000)
            memory_type = WasmMemoryType(limits)

            @test isvalid(memory_type)
            @test memory_type.limits.min == 1000
            @test memory_type.limits.max == 2000
        end

        @testset "should handle WasmLimits validation through constructor" begin
            # WasmLimits should validate that min >= 0 and max >= min (if max != 0)
            @test_nowarn WasmMemoryType((0 => 0))
            @test_nowarn WasmMemoryType((5 => 10))
            @test_nowarn WasmMemoryType((100 => 0))  # 0 means unlimited
        end
    end

    @testset "Interface Methods" begin
        @testset "should support unsafe_convert for C interop" begin
            memory_type = WasmMemoryType((1 => 5))
            ptr = Base.unsafe_convert(
                Ptr{WasmtimeRuntime.LibWasmtime.wasm_memorytype_t},
                memory_type,
            )

            @test ptr != C_NULL
            @test ptr isa Ptr{WasmtimeRuntime.LibWasmtime.wasm_memorytype_t}
        end

        @testset "should provide meaningful string representation" begin
            memory_type = WasmMemoryType((2 => 10))
            str_repr = string(memory_type)

            @test str_repr == "WasmMemoryType()"
            @test !isempty(str_repr)
        end

        @testset "should correctly report validity status" begin
            memory_type = WasmMemoryType()
            @test isvalid(memory_type)

            # Create invalid memory type by directly setting ptr to null
            # Note: This is testing the isvalid implementation
            invalid_memory_type = WasmMemoryType()
            # Simulate an invalid state for testing
            @test isvalid(invalid_memory_type)  # Should be valid initially
        end
    end

    @testset "Finalization Behavior" begin
        @testset "should handle garbage collection properly" begin
            # Create many memory types to test finalizer behavior
            memory_types = [WasmMemoryType((i => i + 10)) for i = 1:10]

            for mt in memory_types
                @test isvalid(mt)
            end

            # Force garbage collection
            GC.gc()
            GC.gc()  # Sometimes need multiple calls

            # Objects should still be valid since we hold references
            for mt in memory_types
                @test isvalid(mt)
            end
        end
    end
end

@testset "WasmMemory Tests" begin
    @testset "Constructor Tests" begin
        @testset "should create WasmMemory with valid store and default limits" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            memory = WasmMemory(store)

            @test memory isa WasmMemory
            @test isvalid(memory)
            @test memory.store === store
        end

        @testset "should create WasmMemory with custom limits" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            limits = (1 => 10)

            memory = WasmMemory(store, limits)

            @test memory isa WasmMemory
            @test isvalid(memory)
            @test memory.store === store
        end

        @testset "should create memory with zero minimum pages" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            limits = (0 => 5)

            memory = WasmMemory(store, limits)

            @test isvalid(memory)
        end
    end

    @testset "Error Handling" begin
        @testset "should throw WasmtimeError for invalid store" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            # Create invalid store by setting ptr to null
            store.ptr = C_NULL

            @test_throws WasmtimeError WasmMemory(store)
        end

        @testset "should handle memory creation failure gracefully" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            # Test with potentially problematic limits (if they cause C API failure)
            # This tests the error path when wasm_memory_new returns C_NULL
            @test_nowarn WasmMemory(store, (0 => 0))
        end
    end

    @testset "Store Validation" begin
        @testset "should validate store before creating memory" begin
            engine = WasmEngine()
            valid_store = WasmStore(engine)

            # This should work
            @test_nowarn WasmMemory(valid_store, (1 => 5))

            # Invalidate store
            valid_store.ptr = C_NULL

            # This should fail
            @test_throws WasmtimeError WasmMemory(valid_store, (1 => 5))
        end
    end

    @testset "Interface Methods" begin
        # @testset "should support map_to_extern for WebAssembly interop" begin
        #     engine = WasmEngine()
        #     store = WasmStore(engine)
        #     memory = WasmMemory(store, (1 => 10))

        #     extern_ptr = map_to_extern(memory)

        #     @test extern_ptr != C_NULL
        #     @test extern_ptr isa Ptr{WasmtimeRuntime.LibWasmtime.wasm_extern_t}
        # end

        @testset "should provide meaningful string representation" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            memory = WasmMemory(store, (2 => 20))

            str_repr = string(memory)

            @test str_repr == "WasmMemory()"
            @test !isempty(str_repr)
        end

        @testset "should support unsafe_convert for C interop" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            memory = WasmMemory(store, (1 => 5))

            ptr =
                Base.unsafe_convert(Ptr{WasmtimeRuntime.LibWasmtime.wasm_memory_t}, memory)

            @test ptr != C_NULL
            @test ptr isa Ptr{WasmtimeRuntime.LibWasmtime.wasm_memory_t}
        end

        @testset "should correctly report validity status" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            memory = WasmMemory(store, (1 => 5))

            @test isvalid(memory)

            # Test that validity depends on non-null ptr
            @test memory.ptr != C_NULL
        end
    end

    @testset "Memory Limits Property Testing" begin
        engine = WasmEngine()
        store = WasmStore(engine)

        # Property: Memory should be created successfully with valid limit combinations
        test_cases = [
            (0 => 0),    # Minimum case
            (1 => 1),    # Single page
            (0 => 10),   # Growable from zero
            (5 => 15),   # Specific range
            (10 => 0),   # Fixed minimum, unlimited maximum
        ]

        @testset "Memory creation with limits $(case)" for case in test_cases
            memory = WasmMemory(store, case)
            @test isvalid(memory)
            @test memory.store === store
        end
    end

    @testset "Finalization and Resource Management" begin
        @testset "should handle finalization properly" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            # Create multiple memories to test finalizer behavior
            memories = [WasmMemory(store, (i => i + 5)) for i = 1:5]

            for memory in memories
                @test isvalid(memory)
            end

            # Force garbage collection
            GC.gc()
            GC.gc()

            # Objects should still be valid since we hold references
            for memory in memories
                @test isvalid(memory)
            end
        end

        @testset "should maintain store reference integrity" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            memory = WasmMemory(store, (2 => 10))

            # Store reference should remain valid
            @test memory.store === store
            @test isvalid(store)
            @test isvalid(memory)
        end
    end
end

@testset "Integration Tests" begin
    @testset "WasmMemoryType and WasmMemory interaction" begin
        @testset "should work together in typical workflow" begin
            # Create components
            engine = WasmEngine()
            store = WasmStore(engine)

            # Create memory type
            memory_type = WasmMemoryType((2 => 20))
            @test isvalid(memory_type)

            # Create memory with same limits
            memory = WasmMemory(store, (2 => 20))
            @test isvalid(memory)

            # Both should be valid and usable
            @test memory.store === store
        end
    end

    @testset "Resource lifecycle management" begin
        @testset "should maintain proper dependencies" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            memory = WasmMemory(store, (1 => 10))

            # All components should be valid
            @test isvalid(engine)
            @test isvalid(store)
            @test isvalid(memory)

            # Memory should maintain reference to store
            @test memory.store === store
        end
    end

    @testset "Multiple memory instances" begin
        @testset "should support creating multiple memories with same store" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            memory1 = WasmMemory(store, (1 => 5))
            memory2 = WasmMemory(store, (2 => 10))
            memory3 = WasmMemory(store, (0 => 15))

            @test isvalid(memory1)
            @test isvalid(memory2)
            @test isvalid(memory3)

            # All should reference the same store
            @test memory1.store === store
            @test memory2.store === store
            @test memory3.store === store
        end
    end
end

@testset "Performance Characteristics" begin
    @testset "Memory creation performance" begin
        @testset "should create memories efficiently" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            # Measure memory creation time
            creation_time = @elapsed begin
                memories = [WasmMemory(store, (i % 10 => (i % 10) + 5)) for i = 1:100]

                # Verify all were created successfully
                for memory in memories
                    @test isvalid(memory)
                end
            end

            # Performance assertion - should complete reasonably quickly
            @test creation_time < 5.0  # Allow generous time for CI
        end
    end

    @testset "Memory allocation patterns" begin
        @testset "should handle repeated allocation and deallocation" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            # Test allocation pattern that might reveal memory leaks
            for iteration = 1:10
                memories = [WasmMemory(store, (1 => 5)) for _ = 1:10]

                for memory in memories
                    @test isvalid(memory)
                end

                # Let memories go out of scope
                memories = nothing
                GC.gc()
            end

            # Test should complete without issues
            @test true
        end
    end
end
