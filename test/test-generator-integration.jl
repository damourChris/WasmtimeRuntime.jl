using Test
using Clang.Generators
using Suppressor

# Include the generator functions for testing
include("../gen/generator_functions.jl")

@testset "Generator Integration Tests" begin
    @testset "Configuration Loading" begin
        # Test that generator configuration loads successfully
        config_path = joinpath(@__DIR__, "../gen/generator.toml")
        @test isfile(config_path)

        # Test that load_options works
        @test_nowarn load_options(config_path)

        options = load_options(config_path)
        @test isa(options, Dict)
        @test !isempty(options)
    end

    @testset "Complete Workflow Components" begin
        # Test that all major components can work together

        # 1. Logging setup
        @test_logs min_level = Logging.Warn @suppress_out setup_enhanced_logging()

        # 2. Target detection
        target_info = @suppress get_detailed_target_info()
        @test !isempty(target_info)

        # 3. Include path resolution
        include_path = @suppress get_wasmtime_include_path()
        @test isdir(include_path)

        # 4. Header discovery
        headers = @suppress find_wasmtime_headers(include_path)
        @test length(headers) > 0

        # 5. Clang arguments construction
        args = @suppress build_clang_args(target_info, include_path)
        @test length(args) > 0

        # 6. Configuration loading
        config_path = joinpath(@__DIR__, "../gen/generator.toml")
        options = load_options(config_path)
        @test !isempty(options)
    end

    @testset "Context Creation Preparation" begin
        # Test that we can prepare everything needed for context creation
        # without actually creating the context (which might be expensive)

        target_info = @suppress get_detailed_target_info()
        include_path = @suppress get_wasmtime_include_path()
        headers = @suppress find_wasmtime_headers(include_path)
        args = @suppress build_clang_args(target_info, include_path)
        config_path = joinpath(@__DIR__, "../gen/generator.toml")
        options = load_options(config_path)

        # Test that all components are compatible
        @test isa(headers, Vector{String})
        @test isa(args, Vector{String})
        @test isa(options, Dict)

        # Test that headers exist and are readable
        for header in headers[1:min(5, length(headers))]  # Test first 5 headers
            @test isfile(header)
            @test isreadable(header)
        end

        # Test that arguments are well-formed
        @test all(arg -> isa(arg, String), args)
        @test all(arg -> !isempty(arg), args)
    end

    @testset "Error Resilience" begin
        # Test behavior with invalid inputs

        # Test with empty include path - should work but may have warnings
        result = @suppress build_clang_args(@suppress(get_detailed_target_info()), "")
        @test isa(result, Vector{String})
        @test length(result) > 0

        # Test with non-existent configuration
        @test_throws Exception load_options("/nonexistent/config.toml")

        # Test with malformed target info
        incomplete_target = Dict(:arch => :x86_64)  # Missing required fields
        try
            result = build_clang_args(incomplete_target, "/tmp")
            # If no exception, result should still be a vector
            @test isa(result, Vector{String})
        catch ex
            # If exception occurs, it should be a sensible error type
            @test isa(ex, Union{KeyError,ArgumentError,BoundsError})
        end
    end

    @testset "Output Consistency" begin
        # Test that multiple runs produce consistent results

        # Run target detection multiple times
        target1 = @suppress get_detailed_target_info()
        target2 = @suppress get_detailed_target_info()
        @test target1 == target2

        # Run header discovery multiple times
        include_path = @suppress get_wasmtime_include_path()
        headers1 = @suppress find_wasmtime_headers(include_path)
        headers2 = @suppress find_wasmtime_headers(include_path)
        @test headers1 == headers2

        # Run argument building multiple times
        args1 = @suppress build_clang_args(target1, include_path)
        args2 = @suppress build_clang_args(target2, include_path)
        @test args1 == args2
    end

    @testset "Resource Management" begin
        # Test that functions don't leak resources or leave artifacts

        original_files = Set(readdir(joinpath(@__DIR__, "../gen")))

        # Run various functions
        @suppress setup_enhanced_logging()
        @suppress get_detailed_target_info()
        @suppress get_wasmtime_include_path()

        # Check for new files (except expected log files)
        current_files = Set(readdir(joinpath(@__DIR__, "../gen")))
        new_files = setdiff(current_files, original_files)

        # Only generator_debug.log should be created
        expected_new_files = ["generator_debug.log"]
        @test issubset(new_files, expected_new_files)
    end

    @testset "Performance Characteristics" begin
        # Test that functions complete in reasonable time

        # Target detection should be fast
        @test (@elapsed @suppress(get_detailed_target_info())) < 1.0

        # Include path resolution should be reasonable
        @test (@elapsed @suppress(get_wasmtime_include_path())) < 5.0

        # Header discovery should complete in reasonable time
        include_path = @suppress get_wasmtime_include_path()
        @test (@elapsed @suppress find_wasmtime_headers(include_path)) < 10.0

        # Argument building should be fast
        target_info = @suppress get_detailed_target_info()
        @test (@elapsed @suppress(build_clang_args(target_info, include_path))) < 1.0
    end
end
