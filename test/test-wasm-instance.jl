using Random
using Test
using WasmtimeRuntime
using WasmtimeRuntime.LibWasmtime

Random.seed!(1234)  # For reproducibility

@testset "WasmInstance Construction and Validity" begin
    @testset "should construct a valid instance" begin
        engine = WasmEngine()
        store = WasmStore(engine)
        wasm_bytes = UInt8[
            0x00,
            0x61,
            0x73,
            0x6d,  # WASM magic number
            0x01,
            0x00,
            0x00,
            0x00,   # Version 1
        ]
        module_ = WasmModule(store, WasmByteVec(wasm_bytes))
        instance = WasmInstance(store, module_)

        @test isa(instance, WasmInstance)
        @test Base.isvalid(instance)

        # unsafe_convert
        ptr = Base.unsafe_convert(Ptr{wasm_instance_t}, instance)
        @test ptr != C_NULL
    end

    @testset "should throw on invalid store" begin
        engine = WasmEngine()
        invalid_store = WasmStore(engine) # Create a valid store first, then invalidate it after creating the module
        wasm_bytes = UInt8[
            0x00,
            0x61,
            0x73,
            0x6d,  # WASM magic number
            0x01,
            0x00,
            0x00,
            0x00,   # Version 1
        ]
        module_ = WasmModule(invalid_store, WasmByteVec(wasm_bytes))

        # Create an invalid store by setting the pointer to C_NULL
        invalid_store.ptr = C_NULL

        @test_throws WasmtimeError WasmInstance(invalid_store, module_)
    end

    @testset "should throw on invalid module" begin
        engine = WasmEngine()
        store = WasmStore(engine)
        wasm_bytes = UInt8[
            0x00,
            0x61,
            0x73,
            0x6d,  # WASM magic number
            0x01,
            0x00,
            0x00,
            0x00,   # Version 1
        ]
        invalid_module = WasmModule(store, WasmByteVec(wasm_bytes))

        # invalid the module by setting the pointer to C_NULL
        invalid_module.ptr = C_NULL

        @test_throws WasmtimeError WasmInstance(store, invalid_module)
    end

end
