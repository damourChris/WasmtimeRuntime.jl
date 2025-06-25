using Random
using Test
using WasmtimeRuntime

# Set deterministic seed for reproducible tests
Random.seed!(1234)

@testset "Value System - Type-Safe Conversions" begin
    @testset "WasmValue type hierarchy" begin
        @test WasmI32 <: WasmValue{Int32}
        @test WasmI64 <: WasmValue{Int64}
        @test WasmF32 <: WasmValue{Float32}
        @test WasmF64 <: WasmValue{Float64}
        @test WasmFuncRef <: WasmValue{Union{AbstractFunc,Nothing}}
        @test WasmExternRef <: WasmValue{Any}
        @test WasmV128 <: WasmValue{NTuple{16,UInt8}}
    end

    @testset "WasmValue creation and properties" begin
        # Test integer values
        i32_val = WasmI32(42)
        @test i32_val isa WasmI32
        @test i32_val.value == 42

        i64_val = WasmI64(Int64(1234567890))
        @test i64_val isa WasmI64
        @test i64_val.value == Int64(1234567890)

        # Test floating point values
        f32_val = WasmF32(3.14f0)
        @test f32_val isa WasmF32
        @test f32_val.value == 3.14f0

        f64_val = WasmF64(2.718281828)
        @test f64_val isa WasmF64
        @test f64_val.value == 2.718281828

        # Test reference values
        funcref_val = WasmFuncRef(nothing)
        @test funcref_val isa WasmFuncRef
        @test funcref_val.func === nothing

        externref_val = WasmExternRef("test string")
        @test externref_val isa WasmExternRef
        @test externref_val.value == "test string"

        # Test V128 value
        v128_data = ntuple(i -> UInt8(i), 16)
        v128_val = WasmV128(v128_data)
        @test v128_val isa WasmV128
        @test v128_val.value == v128_data
    end

    @testset "Type conversion predicates" begin
        @test is_wasm_convertible(Int32) == true
        @test is_wasm_convertible(Int64) == true
        @test is_wasm_convertible(Float32) == true
        @test is_wasm_convertible(Float64) == true

        # These should not be convertible
        @test is_wasm_convertible(String) == false
        @test is_wasm_convertible(Int8) == false
        @test is_wasm_convertible(Vector{Int}) == false
    end

    @testset "to_wasm conversions" begin
        @test to_wasm(Int32(42)) == WasmI32(42)
        @test to_wasm(Int64(123)) == WasmI64(123)
        @test to_wasm(Float32(3.14)) == WasmF32(3.14f0)
        @test to_wasm(Float64(2.718)) == WasmF64(2.718)
    end

    @testset "from_wasm conversions" begin
        @test from_wasm(Int32, WasmI32(42)) == 42
        @test from_wasm(Int64, WasmI64(123)) == 123
        @test from_wasm(Float32, WasmF32(3.14f0)) == 3.14f0
        @test from_wasm(Float64, WasmF64(2.718)) == 2.718
    end

    @testset "Round-trip conversions" begin
        # Test that to_wasm -> from_wasm preserves values
        test_values = [Int32(42), Int64(-9876543210), Float32(1.5f0), Float64(-123.456789)]

        for val in test_values
            wasm_val = to_wasm(val)
            recovered_val = from_wasm(typeof(val), wasm_val)
            @test recovered_val == val
        end
    end
end
