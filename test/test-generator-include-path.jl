using Test
using Pkg.Artifacts
using Suppressor
using Random

# Set deterministic seed for reproducible tests
Random.seed!(1234)

# Include the generator functions for testing
include("../gen/generator_functions.jl")

@testset "Wasmtime Include Path Resolution" begin
    @testset "Artifact Path Resolution" begin
        # Test that the function doesn't throw errors
        @test_logs min_level = Logging.Warn @suppress_out get_wasmtime_include_path()

        # Test that it returns a valid path
        include_path = @suppress get_wasmtime_include_path()
        @test isa(include_path, String)
        @test !isempty(include_path)
    end

    @testset "Path Validation" begin
        include_path = @suppress get_wasmtime_include_path()

        # Test that the path exists and is a directory
        @test isdir(include_path)

        # Test that it contains header files
        files = readdir(include_path; join = true)
        header_files = filter(f -> endswith(f, ".h"), files)

        # Should contain at least some header files
        @test length(header_files) > 0
    end
end
