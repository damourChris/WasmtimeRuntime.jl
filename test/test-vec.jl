using Test
using WasmtimeRuntime
using WasmtimeRuntime.LibWasmtime

@testset "WasmVec Functionality" begin

    @testset "should create empty vector correctly" begin
        empty_vec = WasmVec{wasm_byte_vec_t,UInt8}()

        @test length(empty_vec) == 0
        @test size(empty_vec) == (0,)
        @test isempty(empty_vec)
    end

    @testset "should construct from Julia vector with correct properties" begin
        julia_data = UInt8[0x48, 0x65, 0x6c, 0x6c, 0x6f]
        wasm_vec = WasmVec{wasm_byte_vec_t,UInt8}(julia_data)

        wasm_vec = WasmVec{wasm_byte_vec_t,UInt8}(julia_data)

        @test length(wasm_vec) == 5
        @test size(wasm_vec) == (5,)
        @test !isempty(wasm_vec)
    end

    @testset "should provide correct element access" begin
        julia_data = UInt8[0x48, 0x65, 0x6c, 0x6c, 0x6f]
        wasm_vec = WasmVec{wasm_byte_vec_t,UInt8}(julia_data)

        @test wasm_vec[1] == 0x48
        @test wasm_vec[2] == 0x65
        @test wasm_vec[5] == 0x6f
    end

    @testset "should enforce bounds checking" begin
        wasm_vec = WasmVec{wasm_byte_vec_t,UInt8}(UInt8[1, 2, 3])

        @test_throws BoundsError wasm_vec[0]
        @test_throws BoundsError wasm_vec[4]
    end

    @testset "should allow element modification" begin
        wasm_vec = WasmVec{wasm_byte_vec_t,UInt8}(UInt8[1, 2, 3])

        wasm_vec[1] = 0x42
        @test wasm_vec[1] == 0x42
    end

    @testset "should convert back to Julia vector preserving data" begin
        julia_data = UInt8[0x48, 0x65, 0x6c, 0x6c, 0x6f]
        wasm_vec = WasmVec{wasm_byte_vec_t,UInt8}(julia_data)
        wasm_vec[1] = 0x42

        result = to_julia_vector(wasm_vec)
        @test result isa Vector{UInt8}
        @test length(result) == 5
        @test result[1] == 0x42
        @test result[2:end] == julia_data[2:end]

        collected = collect(wasm_vec)
        @test collected == result
    end

    @testset "should create independent copies" begin
        julia_data = UInt8[1, 2, 3]
        wasm_vec = WasmVec{wasm_byte_vec_t,UInt8}(julia_data)
        copied_vec = copy(wasm_vec)

        @test length(copied_vec) == length(wasm_vec)
        @test collect(copied_vec) == collect(wasm_vec)

        wasm_vec[2] = 0x00
        @test copied_vec[2] != 0x00
    end

    @testset "should support convenience constructors with automatic type detection" begin
        julia_bytes = UInt8[1, 2, 3, 4]

        auto_vec = WasmVec(julia_bytes)
        @test auto_vec isa WasmVec{wasm_byte_vec_t,UInt8}
        @test length(auto_vec) == 4
        @test collect(auto_vec) == julia_bytes

        byte_vec = WasmByteVec(julia_bytes)
        @test byte_vec isa WasmByteVec
        @test length(byte_vec) == 4

        empty_auto = WasmVec(UInt8)
        @test empty_auto isa WasmVec{wasm_byte_vec_t,UInt8}
        @test length(empty_auto) == 0
    end

    @testset "should implement AbstractVector interface correctly" begin
        data = UInt8[10, 20, 30, 40, 50]
        vec = WasmVec(data)

        collected_iter = [x for x in vec]
        @test collected_iter == data

        @test firstindex(vec) == 1
        @test lastindex(vec) == 5

        indices = collect(eachindex(vec))
        @test indices == [1, 2, 3, 4, 5]

        @test Base.IndexStyle(typeof(vec)) == IndexLinear()

        @test vec[1:3] == data[1:3]
        @test vec[end] == data[end]
        @test vec[(end-1):end] == data[(end-1):end]
    end

    @testset "should handle memory management correctly" begin
        function create_and_destroy_vec()
            data = UInt8[1, 2, 3, 4, 5]
            vec = WasmVec(data)
            @test length(vec) == 5
            return nothing  # vec goes out of scope
        end

        for i = 1:10
            create_and_destroy_vec()
        end

        GC.gc()  # Force garbage collection
        @test true  # No segfaults indicates proper cleanup
    end

    @testset "should enforce type safety for unsupported types" begin
        @test_throws AssertionError WasmVec([1, 2, 3])  # Int64 unsupported
        @test_throws AssertionError WasmVec(["a", "b", "c"])  # String unsupported
    end

    @testset "should reject invalid type conversions" begin
        vec = WasmVec(UInt8[1, 2, 3])

        @test_throws TypeError vec[1] = "wrong type"

        @test_throws InexactError vec[2] = 3.14  # Float64 unsupported
        @test_throws InexactError vec[1] = 1.5  # Fractional part

        @test_throws BoundsError vec[0] = UInt8(0)  # Out of bounds
    end

    @testset "should reject invalid bounds access and indexing" begin
        vec = WasmVec(UInt8[1, 2, 3])

        @test_throws BoundsError vec[0]  # Invalid index
        @test_throws BoundsError vec[4]  # Out of bounds index

        @test_throws BoundsError vec[0:3]  # Invalid range start
    end

    @testset "should accept valid type conversions" begin
        vec = WasmVec(UInt8[1, 2, 3])

        vec[1] = UInt8(1)
        @test vec[1] == 0x01

        vec[2] = UInt8(255)
        @test vec[2] == 0xff
    end

    @testset "should provide safe unsafe conversions" begin
        data = UInt8[0x41, 0x42, 0x43]
        vec = WasmVec(data)

        struct_ptr = Base.unsafe_convert(Ptr{wasm_byte_vec_t}, vec)
        @test struct_ptr != C_NULL

        data_ptr = Base.unsafe_convert(Ptr{UInt8}, vec)
        @test data_ptr != C_NULL
        @test data_ptr == vec.data

        @test unsafe_load(data_ptr, 1) == 0x41
        @test unsafe_load(data_ptr, 2) == 0x42
        @test unsafe_load(data_ptr, 3) == 0x43
    end

    @testset "should handle edge cases correctly" begin
        @testset "empty vector" begin
            empty_vec = WasmVec(UInt8[])
            @test length(empty_vec) == 0
            @test isempty(empty_vec)
            @test collect(empty_vec) == UInt8[]
        end

        @testset "single element" begin
            single_vec = WasmVec(UInt8[42])
            @test length(single_vec) == 1
            @test single_vec[1] == 42
            @test collect(single_vec) == [42]
        end

        @testset "large vector" begin
            large_data = UInt8[i % 256 for i = 1:1000]
            large_vec = WasmVec(large_data)
            @test length(large_vec) == 1000
            @test collect(large_vec) == large_data
        end
    end

    @testset "should maintain vector properties under operations" begin
        # Property-based testing for vector invariants
        test_cases = [UInt8[], UInt8[42], UInt8[1, 2, 3], UInt8[i % 256 for i = 1:50]]

        for data in test_cases
            vec = WasmVec(data)

            # Property: length preservation
            @test length(vec) == length(data)

            # Property: element preservation
            @test collect(vec) == data

            # Property: indexing consistency
            for i in eachindex(data)
                @test vec[i] == data[i]
            end

            # Property: copy independence
            if !isempty(vec)
                copied = copy(vec)
                original_first = vec[1]
                vec[1] = UInt8(0)
                @test copied[1] == original_first
                vec[1] = original_first  # Restore
            end
        end
    end

    @testset "should support type aliases correctly" begin
        @test WasmByteVec == WasmVec{wasm_byte_vec_t,UInt8}
        @test WasmExternVec == WasmVec{wasm_extern_vec_t,Ptr{wasm_extern_t}}
        @test WasmImportTypeVec == WasmVec{wasm_importtype_vec_t,Ptr{wasm_importtype_t}}

        byte_data = UInt8[1, 2, 3]
        typed_vec = WasmByteVec(byte_data)
        @test typed_vec isa WasmByteVec
        @test length(typed_vec) == 3
    end
end

@testset "WasmVec Integration" begin
    @testset "should work with Wasmtime engine creation" begin
        config = wasm_config_new()
        @test config != C_NULL

        engine = wasm_engine_new_with_config(config)
        @test engine != C_NULL

        wasm_engine_delete(engine)
        @test true  # Successful cleanup indicates proper integration
    end
end
