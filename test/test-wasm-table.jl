using Random
using Test
using WasmtimeRuntime

Random.seed!(1234)

@testset "WasmTableType Tests" begin
    @testset "Constructor Tests" begin
        @testset "should create WasmTableType with default limits" begin
            table_type = WasmTableType()

            @test table_type isa WasmTableType
            @test isvalid(table_type)
        end

        @testset "should create WasmTableType with custom limits" begin
            limits = (10 => 100)
            table_type = WasmTableType(limits)

            @test table_type isa WasmTableType
            @test isvalid(table_type)
        end

        @testset "should create WasmTableType with zero max (unlimited)" begin
            limits = (5 => 0)
            table_type = WasmTableType(limits)

            @test table_type isa WasmTableType
            @test isvalid(table_type)
        end

        @testset "should create WasmTableType from WasmLimits" begin
            wasm_limits = WasmLimits(2, 20)
            table_type = WasmTableType(wasm_limits)

            @test table_type isa WasmTableType
            @test isvalid(table_type)
        end
    end

    @testset "Edge Cases and Error Handling" begin
        @testset "should handle large limits within valid range" begin
            limits = (1000 => 2000)
            table_type = WasmTableType(limits)

            @test isvalid(table_type)
        end

        @testset "should handle WasmLimits validation through constructor" begin
            @test_nowarn WasmTableType((0 => 0))
            @test_nowarn WasmTableType((5 => 10))
            @test_nowarn WasmTableType((100 => 0))  # 0 means unlimited
        end
    end

    @testset "Interface Methods" begin
        @testset "should support unsafe_convert for C interop" begin
            table_type = WasmTableType((1 => 5))
            ptr = Base.unsafe_convert(
                Ptr{WasmtimeRuntime.LibWasmtime.wasm_tabletype_t},
                table_type,
            )

            @test ptr != C_NULL
            @test ptr isa Ptr{WasmtimeRuntime.LibWasmtime.wasm_tabletype_t}
        end

        @testset "should provide readable string representation" begin
            table_type = WasmTableType()
            str_repr = string(table_type)

            @test str_repr == "WasmTableType()"
        end

        @testset "should correctly validate table type" begin
            table_type = WasmTableType()
            @test isvalid(table_type)

            # Simulate invalidation
            old_ptr = table_type.ptr
            table_type.ptr = C_NULL
            @test !isvalid(table_type)

            # Restore for cleanup
            table_type.ptr = old_ptr
        end
    end
end

@testset "WasmTable Tests" begin
    @testset "Creation Tests" begin
        @testset "should create WasmTable with default table type" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            table_type = WasmTableType()

            table = WasmTable(store, table_type)

            @test table isa WasmTable
            @test isvalid(table)
        end

        @testset "should create WasmTable with custom limits" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            limits = (1 => 10)
            table_type = WasmTableType(limits)

            table = WasmTable(store, table_type)

            @test table isa WasmTable
            @test isvalid(table)
        end

        @testset "should create table with zero minimum entries" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            limits = (0 => 5)
            table_type = WasmTableType(limits)

            table = WasmTable(store, table_type)

            @test isvalid(table)
        end
    end

    @testset "Error Handling" begin
        @testset "should throw ArgumentError for invalid store" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            table_type = WasmTableType()

            # Invalidate store
            store.ptr = C_NULL

            @test_throws ArgumentError WasmTable(store, table_type)
        end

        @testset "should handle table creation failure gracefully" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            table_type = WasmTableType()

            # This should work normally
            @test_nowarn WasmTable(store, table_type)
        end
    end

    @testset "Store Validation" begin
        @testset "should validate store before creating table" begin
            engine = WasmEngine()
            valid_store = WasmStore(engine)
            table_type = WasmTableType((1 => 5))

            # This should work
            @test_nowarn WasmTable(valid_store, table_type)

            # Invalidate store
            valid_store.ptr = C_NULL

            # This should fail
            @test_throws ArgumentError WasmTable(valid_store, table_type)
        end
    end

    @testset "Interface Methods" begin
        @testset "should support unsafe_convert for C interop" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            table_type = WasmTableType()
            table = WasmTable(store, table_type)

            ptr = Base.unsafe_convert(Ptr{WasmtimeRuntime.LibWasmtime.wasm_table_t}, table)

            @test ptr != C_NULL
            @test ptr isa Ptr{WasmtimeRuntime.LibWasmtime.wasm_table_t}
        end

        @testset "should provide readable string representation" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            table_type = WasmTableType()
            table = WasmTable(store, table_type)

            str_repr = string(table)

            @test str_repr == "WasmTable()"
        end

        @testset "should correctly validate table" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            table_type = WasmTableType()
            table = WasmTable(store, table_type)

            @test isvalid(table)

            # Simulate invalidation
            old_ptr = table.ptr
            table.ptr = C_NULL
            @test !isvalid(table)

            # Restore for cleanup
            table.ptr = old_ptr
        end
    end

    @testset "AbstractVector Interface" begin
        @testset "should provide size information" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            table_type = WasmTableType((2 => 10))
            table = WasmTable(store, table_type)

            size_tuple = size(table)
            @test size_tuple isa Tuple{Int}
            @test length(size_tuple) == 1
            @test size_tuple[1] >= 0  # Size should be non-negative
        end

        @testset "should support indexing with bounds checking" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            table_type = WasmTableType((3 => 10))
            table = WasmTable(store, table_type)

            table_size = size(table)[1]

            if table_size > 0
                # Test valid indexing
                @test_nowarn table[1]
                @test_nowarn table[table_size]

                # Test invalid indexing
                @test_throws BoundsError table[0]
                @test_throws BoundsError table[table_size+1]
                @test_throws BoundsError table[-1]
            end
        end

        @testset "should return nothing for empty table slots" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            table_type = WasmTableType((1 => 5))
            table = WasmTable(store, table_type)

            table_size = size(table)[1]

            if table_size > 0
                # Initially, all slots should be empty (null)
                result = table[1]
                @test result === nothing || result isa Ptr{LibWasmtime.wasm_ref_t}
            end
        end
    end

    @testset "WasmTableType Extraction" begin
        @testset "should extract table type from existing table" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            original_type = WasmTableType((2 => 8))
            table = WasmTable(store, original_type)

            extracted_type = WasmTableType(table)

            @test extracted_type isa WasmTableType
            @test isvalid(extracted_type)
        end

        @testset "should handle type extraction from invalid table" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            table_type = WasmTableType()
            table = WasmTable(store, table_type)

            # Invalidate table
            table.ptr = C_NULL

            @test_throws ArgumentError WasmTableType(table)
        end
    end
end

@testset "Integration Tests" begin
    @testset "should work with engine and store lifecycle" begin
        engine = WasmEngine()
        store = WasmStore(engine)
        table_type = WasmTableType((1 => 10))
        table = WasmTable(store, table_type)

        @test isvalid(engine)
        @test isvalid(store)
        @test isvalid(table_type)
        @test isvalid(table)
    end

    @testset "should handle multiple tables with same store" begin
        engine = WasmEngine()
        store = WasmStore(engine)

        table_type1 = WasmTableType((2 => 5))
        table_type2 = WasmTableType((3 => 7))

        table1 = WasmTable(store, table_type1)
        table2 = WasmTable(store, table_type2)

        @test isvalid(table1)
        @test isvalid(table2)
        @test table1.ptr != table2.ptr  # Different table instances
    end

    @testset "should properly cleanup resources" begin
        engine = WasmEngine()
        store = WasmStore(engine)
        table_type = WasmTableType()
        table = WasmTable(store, table_type)

        # Force garbage collection to test finalizers
        table = nothing
        table_type = nothing
        GC.gc()

        # Test should complete without segfaults or errors
        @test true
    end
end

@testset "Performance Characteristics" begin
    @testset "should create tables efficiently" begin
        engine = WasmEngine()
        store = WasmStore(engine)

        # Time table creation
        creation_time = @timed begin
            for i = 1:10
                table_type = WasmTableType((i => i * 2))
                table = WasmTable(store, table_type)
                @test isvalid(table)
            end
        end

        # Creation should be reasonably fast (less than 1 second for 10 tables)
        @test creation_time.time < 1.0
    end

    @testset "should handle large table limits" begin
        engine = WasmEngine()
        store = WasmStore(engine)

        # Test with moderately large limits
        large_limits = (100 => 1000)
        table_type = WasmTableType(large_limits)

        @test_nowarn WasmTable(store, table_type)
    end
end

@testset "Type System Integration" begin
    @testset "should work with AbstractVector interface" begin
        engine = WasmEngine()
        store = WasmStore(engine)
        table_type = WasmTableType((1 => 5))
        table = WasmTable(store, table_type)

        @test table isa AbstractVector
        @test eltype(table) == Union{Nothing,Ptr{WasmtimeRuntime.LibWasmtime.wasm_ref_t}}
    end

    @testset "should support standard vector operations" begin
        engine = WasmEngine()
        store = WasmStore(engine)
        table_type = WasmTableType((2 => 10))
        table = WasmTable(store, table_type)

        @test length(table) >= 0
        @test ndims(table) == 1
        @test firstindex(table) == 1

        if length(table) > 0
            @test lastindex(table) == length(table)
        end
    end
end
