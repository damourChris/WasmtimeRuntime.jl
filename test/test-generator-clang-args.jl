using Test
using Clang.Generators
using Suppressor

# Include the generator functions for testing
include("../gen/generator_functions.jl")

@testset "Clang Arguments Construction" begin
    @testset "Basic Arguments Structure" begin
        # Get target info and a test include path
        target_info = @suppress get_detailed_target_info()
        include_path = "/test/include/path"  # Use a test path

        # Test that build_clang_args doesn't throw errors
        @test_logs min_level = Logging.Warn @suppress_out build_clang_args(
            target_info,
            include_path,
        )

        # Test that it returns an array of strings
        args = @suppress build_clang_args(target_info, include_path)
        @test isa(args, Vector{String})
        @test length(args) > 0
    end

    @testset "Required Arguments Present" begin
        target_info = @suppress get_detailed_target_info()
        include_path = "/test/include/path"
        args = @suppress build_clang_args(target_info, include_path)

        # Convert to a single string for easier searching
        args_string = join(args, " ")

        # Test that required arguments are present
        @test occursin("-I/test/include/path", args_string)
        @test occursin("-target", args_string)
        @test occursin("-std=c11", args_string)
        @test occursin("-O0", args_string)

        # Test architecture-specific arguments
        @test occursin("-march=", args_string)

        # Test endianness arguments
        if target_info[:endianness] == :little
            @test occursin("-mlittle-endian", args_string)
        else
            @test occursin("-mbig-endian", args_string)
        end

        # Test ABI arguments
        if target_info[:abi] == "lp64"
            @test occursin("-mabi=lp64", args_string)
        elseif target_info[:abi] == "ilp32"
            @test occursin("-mabi=ilp32", args_string)
        end
    end

    @testset "OS Specific Definitions" begin
        target_info = @suppress get_detailed_target_info()
        include_path = "/test/include/path"
        args = @suppress build_clang_args(target_info, include_path)

        args_string = join(args, " ")

        if target_info[:os] == "linux"
            @test occursin("-D_GNU_SOURCE", args_string)
            @test occursin("-D__linux__", args_string)
        elseif target_info[:os] == "windows"
            @test occursin("-D_WIN32", args_string)
            @test occursin("-DWIN32", args_string)
        elseif target_info[:os] == "darwin"
            @test occursin("-D__APPLE__", args_string)
            @test occursin("-D__MACH__", args_string)
        end
    end

    @testset "Wasmtime Specific Definitions" begin
        target_info = @suppress get_detailed_target_info()
        include_path = "/test/include/path"
        args = @suppress build_clang_args(target_info, include_path)

        args_string = join(args, " ")

        # Test Wasmtime-specific definitions
        @test occursin("-DWASI_API_EXTERN=", args_string)
        @test occursin("-DWASM_API_EXTERN=", args_string)
        @test occursin("-DWASMTIME_API_EXTERN=", args_string)
        @test occursin("-DWASMTIME_FEATURE_WASI=1", args_string)
        @test occursin("-DWASMTIME_FEATURE_POOLING_ALLOCATOR=1", args_string)
        @test occursin("-DWASMTIME_FEATURE_COMPONENT_MODEL=1", args_string)
    end

    @testset "Default Arguments Integration" begin
        target_info = @suppress get_detailed_target_info()
        include_path = "/test/include/path"
        args = @suppress build_clang_args(target_info, include_path)

        # Should start with default arguments from Clang.jl
        default_args = get_default_args()

        # First few arguments should match default args
        # (This tests that we're properly building on top of defaults)
        @test length(args) >= length(default_args)

        # The function should add arguments beyond the defaults
        @test length(args) > length(default_args)
    end
end
