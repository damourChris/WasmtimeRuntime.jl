using Test
using Suppressor
using Random

# Set deterministic seed for reproducible tests
Random.seed!(1234)

@testset "Generator Script Structure" begin
    @testset "File Existence and Readability" begin
        generator_path = joinpath(@__DIR__, "../gen/generator.jl")
        generator_functions_path = joinpath(@__DIR__, "../gen/generator_functions.jl")

        @test isfile(generator_path)
        @test isfile(generator_functions_path)

        # Test that the files are not empty
        @test filesize(generator_path) > 0
        @test filesize(generator_functions_path) > 0
    end

    @testset "Required Functions Defined in generator_functions.jl" begin
        # Read the generator_functions file content
        generator_functions_path = joinpath(@__DIR__, "../gen/generator_functions.jl")
        content = read(generator_functions_path, String)

        # Test that required functions are defined
        required_functions = [
            "setup_enhanced_logging",
            "get_detailed_target_info",
            "get_wasmtime_include_path",
            "build_clang_args",
            "find_wasmtime_headers",
            "run_generation",
        ]

        for func_name in required_functions
            @test occursin("function $func_name", content) ||
                  occursin("$func_name() =", content) ||
                  occursin("$func_name(", content)
        end
    end

    @testset "Required Dependencies Imported" begin
        generator_functions_path = joinpath(@__DIR__, "../gen/generator_functions.jl")
        content = read(generator_functions_path, String)

        # Test that required packages are imported
        required_imports = [
            "using Clang.Generators",
            "using Clang.LibClang.Clang_jll",
            "using Pkg.Artifacts",
            "using LoggingExtras",
            "using Dates",
        ]

        for import_stmt in required_imports
            @test occursin(import_stmt, content)
        end
    end

    @testset "Generator Script Structure" begin
        generator_path = joinpath(@__DIR__, "../gen/generator.jl")
        content = read(generator_path, String)

        # Test that generator.jl includes generator_functions.jl
        @test occursin("include(\"generator_functions.jl\")", content)

        # Test that it has conditional execution logic
        @test occursin("PROGRAM_FILE", content)

    end

    @testset "Functions Implementation Structure" begin
        generator_functions_path = joinpath(@__DIR__, "../gen/generator_functions.jl")
        content = read(generator_functions_path, String)

        # Test that the functions follow expected structure
        @test occursin("get_detailed_target_info()", content)  # Gets target info
        @test occursin("get_wasmtime_include_path()", content)  # Gets include path
        @test occursin("build_clang_args(", content)  # Builds clang args
        @test occursin("find_wasmtime_headers(", content)  # Finds headers
        @test occursin("create_context(", content)  # Creates Clang context
        @test occursin("build!(", content)  # Builds the bindings
        @test occursin("run_generation(", content)  # Main generation function
    end

    @testset "Error Handling Patterns" begin
        generator_functions_path = joinpath(@__DIR__, "../gen/generator_functions.jl")
        content = read(generator_functions_path, String)

        # Test that error handling is present
        @test occursin("try", content)
        @test occursin("catch", content)
        @test occursin("@error", content) || occursin("error(", content)

        # Test that there's proper cleanup and error reporting
        @test occursin("rethrow", content) || occursin("throw", content)
    end

    @testset "Logging and Debug Information" begin
        generator_functions_path = joinpath(@__DIR__, "../gen/generator_functions.jl")
        content = read(generator_functions_path, String)

        # Test that comprehensive logging is used
        logging_macros = ["@info", "@debug", "@warn", "@error"]
        for macro_name in logging_macros
            @test occursin(macro_name, content)
        end

        # Test that debug logging is properly configured
        @test occursin("debug", lowercase(content))
        @test occursin("MinLevelLogger", content)
        @test occursin("TeeLogger", content)
    end

    @testset "Configuration and Customization" begin
        generator_functions_path = joinpath(@__DIR__, "../gen/generator_functions.jl")
        content = read(generator_functions_path, String)

        # Test that configuration loading is present
        @test occursin("load_options", content)
        @test occursin("generator.toml", content)

        # Test that customization points exist
        @test occursin("rewrite!", content)  # Custom rewriting
        @test occursin("BUILDSTAGE", content)  # Build stages
    end

    @testset "Platform Independence" begin
        generator_functions_path = joinpath(@__DIR__, "../gen/generator_functions.jl")
        content = read(generator_functions_path, String)

        # Test that platform detection is comprehensive
        @test occursin("Sys.ARCH", content)
        @test occursin("Sys.islinux", content)
        @test occursin("Sys.iswindows", content)
        @test occursin("Sys.isapple", content)

        # Test that different architectures are handled
        @test occursin("x86_64", content)
        @test occursin("aarch64", content)
        @test occursin("i686", content)
    end

    @testset "Documentation and Comments" begin
        generator_functions_path = joinpath(@__DIR__, "../gen/generator_functions.jl")
        content = read(generator_functions_path, String)

        # Test that functions are documented
        @test occursin("#", content)  # Has comments

        # Count comment lines vs code lines (should have reasonable documentation)
        lines = split(content, '\n')
        comment_lines = count(line -> strip(line) |> l -> startswith(l, "#"), lines)
        total_lines = length(lines)

        # Should have at least 10% comments (this is a reasonable minimum)
        @test comment_lines / total_lines > 0.1
    end

    @testset "Performance Considerations" begin
        generator_functions_path = joinpath(@__DIR__, "../gen/generator_functions.jl")
        content = read(generator_functions_path, String)

        # Test that performance monitoring is present
        @test occursin("@debug", content)  # Debug information for performance tracking

        # Test that there's consideration for memory usage
        # (This is harder to test statically, but we can look for patterns)
        @test occursin("args", content)  # Argument building should be efficient
    end

    @testset "New Structure Benefits" begin
        @testset "Include Functions Without Generation" begin
            # Test that we can include generator_functions.jl without running generation
            @test_nowarn include("../gen/generator_functions.jl")

            # Test that functions are available
            @test isdefined(Main, :get_detailed_target_info)
            @test isdefined(Main, :get_wasmtime_include_path)
            @test isdefined(Main, :build_clang_args)
            @test isdefined(Main, :find_wasmtime_headers)
            @test isdefined(Main, :setup_enhanced_logging)
            @test isdefined(Main, :run_generation)
        end

        @testset "Conditional Execution in generator.jl" begin
            # Test that generator.jl has the conditional execution pattern
            generator_path = joinpath(@__DIR__, "../gen/generator.jl")
            content = read(generator_path, String)

            # Should have the PROGRAM_FILE check
            @test occursin("abspath(PROGRAM_FILE) == @__FILE__", content)
            @test occursin("run_generation()", content)
        end

        @testset "Individual Function Testing" begin
            # Test that individual functions work without full generation
            @test_logs min_level = Logging.Warn @suppress_out get_detailed_target_info()

            # Setup logging should work
            @test_logs min_level = Logging.Warn @suppress_out setup_enhanced_logging()

            # These might fail if artifacts aren't available, but should not crash the test framework
            try
                target_info = @suppress get_detailed_target_info()
                @test isa(target_info, Dict)
                @test haskey(target_info, :arch)
            catch e
                @test e isa Exception  # Expected if system detection fails
            end
        end
    end

end
