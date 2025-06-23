using Test
using Suppressor

# Include only the generator functions for testing (without running generation)
include("../gen/generator_functions.jl")

@testset "Target Architecture Detection" begin
    @testset "Basic Architecture Detection" begin
        target_info = @suppress get_detailed_target_info()

        # Test that all required fields are present
        @test haskey(target_info, :arch)
        @test haskey(target_info, :os)
        @test haskey(target_info, :word_size)
        @test haskey(target_info, :endianness)
        @test haskey(target_info, :cpu_target)
        @test haskey(target_info, :abi)
        @test haskey(target_info, :march)

        # Test that values are reasonable
        @test target_info[:arch] in [:x86_64, :aarch64, :i686]
        @test target_info[:os] in ["linux", "windows", "darwin"]
        @test target_info[:word_size] in [32, 64]
        @test target_info[:endianness] in [:big, :little]
        @test !isempty(target_info[:cpu_target])
        @test !isempty(target_info[:abi])
        @test !isempty(target_info[:march])
    end

    @testset "Architecture Specific Configuration" begin
        target_info = @suppress get_detailed_target_info()

        if target_info[:arch] == :x86_64
            @test target_info[:abi] == "lp64"
            @test target_info[:march] == "x86-64"
            @test occursin("x86_64", target_info[:cpu_target])
        elseif target_info[:arch] == :aarch64
            @test target_info[:abi] == "lp64"
            @test target_info[:march] == "armv8-a"
            @test occursin("aarch64", target_info[:cpu_target])
        elseif target_info[:arch] == :i686
            @test target_info[:abi] == "ilp32"
            @test target_info[:march] == "i686"
            @test occursin("i686", target_info[:cpu_target])
        end
    end

    @testset "OS Specific Configuration" begin
        target_info = @suppress get_detailed_target_info()

        if Sys.islinux()
            @test target_info[:os] == "linux"
            @test occursin("linux", target_info[:cpu_target])
        elseif Sys.iswindows()
            @test target_info[:os] == "windows"
            @test occursin("windows", target_info[:cpu_target])
        elseif Sys.isapple()
            @test target_info[:os] == "darwin"
            @test occursin("darwin", target_info[:cpu_target])
        end
    end
end
