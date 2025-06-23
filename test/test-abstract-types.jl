# Test the core abstract type hierarchy - Phase 1 Foundation
using WasmtimeRuntime

@testset "Abstract Type Hierarchy" begin
    @testset "WasmtimeObject is the root type" begin
        @test WasmtimeObject isa Type
        @test isabstracttype(WasmtimeObject)
    end

    @testset "WasmtimeResource subtypes WasmtimeObject" begin
        @test WasmtimeResource <: WasmtimeObject
        @test isabstracttype(WasmtimeResource)
    end

    @testset "WasmtimeValue subtypes WasmtimeObject" begin
        @test WasmtimeValue <: WasmtimeObject
        @test isabstracttype(WasmtimeValue)
    end

    @testset "WasmtimeType subtypes WasmtimeObject" begin
        @test WasmtimeType <: WasmtimeObject
        @test isabstracttype(WasmtimeType)
    end

    @testset "Engine types" begin
        @test AbstractEngine <: WasmtimeResource
        @test isabstracttype(AbstractEngine)

        @test AbstractConfig <: WasmtimeObject
        @test isabstracttype(AbstractConfig)
    end

    @testset "Runtime object types" begin
        @test AbstractStore <: WasmtimeResource
        @test AbstractModule <: WasmtimeResource
        @test AbstractInstance <: WasmtimeResource

        @test isabstracttype(AbstractStore)
        @test isabstracttype(AbstractModule)
        @test isabstracttype(AbstractInstance)
    end

    @testset "WebAssembly object types" begin
        @test AbstractFunc <: WasmtimeResource
        @test AbstractMemory <: WasmtimeResource
        @test AbstractGlobal <: WasmtimeResource
        @test AbstractTable <: WasmtimeResource

        @test isabstracttype(AbstractFunc)
        @test isabstracttype(AbstractMemory)
        @test isabstracttype(AbstractGlobal)
        @test isabstracttype(AbstractTable)
    end
end
