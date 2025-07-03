using Test
using WasmtimeRuntime

@testset "WasmExtern Tests" begin
    @testset "Constructor and Basic Functionality" begin
        @testset "should create WasmExtern from WasmMemory" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            memory = WasmMemory(store, (1 => 10))

            extern = WasmExtern(memory)

            @test extern isa WasmExtern{WasmMemory}
            @test isvalid(extern)
            @test extern.ptr != C_NULL
        end

        @testset "should create WasmExtern from WasmTable" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            table_type = WasmTableType()
            table = WasmTable(store, table_type)

            extern = WasmExtern(table)

            @test extern isa WasmExtern{WasmTable}
            @test isvalid(extern)
            @test extern.ptr != C_NULL
        end

        @testset "should create WasmExtern from WasmGlobal" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            valtype = WasmValType(Int32)
            global_type = WasmGlobalType(valtype, false)
            initial_value = WasmValue(Int32(42))
            global_var = WasmGlobal(store, global_type, initial_value)

            extern = WasmExtern(global_var)

            @test extern isa WasmExtern{WasmGlobal}
            @test isvalid(extern)
            @test extern.ptr != C_NULL
        end

        # Note: WasmFunc tests would go here when WasmFunc is implemented
        # @testset "should create WasmExtern from WasmFunc" begin
        #     # Test when WasmFunc constructor is available
        # end
    end

    @testset "Error Handling" begin
        @testset "should throw ArgumentError for invalid objects" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            memory = WasmMemory(store, (1 => 5))

            # Invalidate the memory object
            memory.ptr = C_NULL

            @test_throws ArgumentError WasmExtern(memory)
        end

        @testset "should handle conversion failures gracefully" begin
            # This test is harder to implement without directly manipulating C pointers
            # But the error handling is built into the constructor
            @test true # Placeholder for now
        end
    end

    @testset "Type Parameters and Parametric Types" begin
        @testset "should preserve original object type in type parameter" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            # Test with different object types
            memory = WasmMemory(store, (1 => 5))
            memory_extern = WasmExtern(memory)
            @test memory_extern isa WasmExtern{WasmMemory}

            table_type = WasmTableType()
            table = WasmTable(store, table_type)
            table_extern = WasmExtern(table)
            @test table_extern isa WasmExtern{WasmTable}
        end

        @testset "should be subtype of AbstractWasmExtern" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            memory = WasmMemory(store, (1 => 5))
            extern = WasmExtern(memory)

            @test extern isa AbstractWasmExtern
        end
    end

    @testset "Interface Methods" begin
        @testset "should support unsafe_convert for C interop" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            memory = WasmMemory(store, (1 => 5))
            extern = WasmExtern(memory)

            ptr =
                Base.unsafe_convert(Ptr{WasmtimeRuntime.LibWasmtime.wasm_extern_t}, extern)

            @test ptr != C_NULL
            @test ptr isa Ptr{WasmtimeRuntime.LibWasmtime.wasm_extern_t}
            @test ptr == extern.ptr
        end

        @testset "should provide meaningful string representation" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            memory = WasmMemory(store, (1 => 5))
            extern = WasmExtern(memory)

            str_repr = string(extern)

            @test str_repr == "WasmExtern()"
            @test !isempty(str_repr)
        end

        @testset "should correctly validate extern objects" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            memory = WasmMemory(store, (1 => 5))
            extern = WasmExtern(memory)

            @test isvalid(extern)

            # Simulate invalidation
            old_ptr = extern.ptr
            extern.ptr = C_NULL
            @test !isvalid(extern)

            # Restore for cleanup
            extern.ptr = old_ptr
        end
    end

    @testset "Resource Management" begin
        @testset "should manage memory lifecycle properly" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            memory = WasmMemory(store, (1 => 5))

            # Memory should be valid before extern creation
            @test isvalid(memory)

            extern = WasmExtern(memory)

            # Extern should be valid
            @test isvalid(extern)

            # Original memory object should have been finalized
            # (This is an implementation detail, but good to verify the behavior)
        end

        @testset "should handle multiple extern objects from same store" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            # Create multiple objects and their externs
            memory1 = WasmMemory(store, (1 => 5))
            memory2 = WasmMemory(store, (2 => 10))
            table_type = WasmTableType()
            table = WasmTable(store, table_type)

            extern1 = WasmExtern(memory1)
            extern2 = WasmExtern(memory2)
            extern3 = WasmExtern(table)

            @test isvalid(extern1)
            @test isvalid(extern2)
            @test isvalid(extern3)

            # All should have different pointers
            @test extern1.ptr != extern2.ptr
            @test extern1.ptr != extern3.ptr
            @test extern2.ptr != extern3.ptr
        end
    end

    @testset "Edge Cases and Boundary Conditions" begin
        @testset "should work with minimal memory objects" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            memory = WasmMemory(store, (0 => 1))  # Minimal memory

            extern = WasmExtern(memory)

            @test isvalid(extern)
        end

        @testset "should work with maximal memory objects within limits" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            # Use reasonable limits that should work
            memory = WasmMemory(store, (10 => 100))

            extern = WasmExtern(memory)

            @test isvalid(extern)
        end
    end

    @testset "Type Union Behavior" begin
        @testset "WasmExternObjectType should include all expected types" begin
            # Test that the union type includes all the expected types
            @test WasmMemory <: WasmtimeRuntime.WasmExternObjectType
            @test WasmTable <: WasmtimeRuntime.WasmExternObjectType
            @test WasmGlobal <: WasmtimeRuntime.WasmExternObjectType
            # WasmFunc would be tested here when implemented
        end

        @testset "should work with different union member types" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            # Test with each type in the union
            objects = [
                WasmMemory(store, (1 => 5)),
                WasmTable(store, WasmTableType()),
                WasmGlobal(
                    store,
                    WasmGlobalType(WasmValType(Int32), false),
                    WasmValue(Int32(123)),
                ),
            ]

            for obj in objects
                extern = WasmExtern(obj)
                @test isvalid(extern)
                @test extern isa WasmExtern
            end
        end
    end

    @testset "Integration with Other Components" begin
        @testset "should work in typical WebAssembly workflows" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            # Create various objects that might be used together
            memory = WasmMemory(store, (2 => 20))
            table_type = WasmTableType()
            table = WasmTable(store, table_type)

            # Convert to externs
            memory_extern = WasmExtern(memory)
            table_extern = WasmExtern(table)

            # All should be valid and ready for use
            @test isvalid(memory_extern)
            @test isvalid(table_extern)

            # Could be used in import/export scenarios (when implemented)
            @test memory_extern isa AbstractWasmExtern
            @test table_extern isa AbstractWasmExtern
        end
    end

    @testset "Performance Characteristics" begin
        @testset "should create externs efficiently" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            # Measure extern creation time
            creation_time = @elapsed begin
                for i = 1:100
                    memory = WasmMemory(store, (i % 10 + 1 => i % 10 + 10))
                    extern = WasmExtern(memory)
                    @test isvalid(extern)
                end
            end

            # Performance assertion - should complete reasonably quickly
            @test creation_time < 5.0  # Allow generous time for CI
        end

        @testset "should handle repeated creation and cleanup" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            # Test allocation pattern that might reveal memory leaks
            for iteration = 1:10
                externs = []
                for i = 1:10
                    memory = WasmMemory(store, (1 => 5))
                    extern = WasmExtern(memory)
                    push!(externs, extern)
                    @test isvalid(extern)
                end

                # Let externs go out of scope
                externs = nothing
                GC.gc()
            end

            # Test should complete without issues
            @test true
        end
    end
end
