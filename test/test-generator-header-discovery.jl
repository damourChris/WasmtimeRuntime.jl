using Test
using Pkg.Artifacts
using Suppressor

# Include the generator functions for testing
include("../gen/generator_functions.jl")

@testset "Header File Discovery" begin
    @testset "Fake Header Discovery Function" begin
        # Create a temporary directory structure for testing
        temp_dir = mktempdir()

        try
            # Create some test header files
            mkdir(joinpath(temp_dir, "subdir"))

            # Create various file types
            touch(joinpath(temp_dir, "test1.h"))
            touch(joinpath(temp_dir, "test2.h"))
            touch(joinpath(temp_dir, "subdir", "test3.h"))
            touch(joinpath(temp_dir, "not_header.txt"))
            touch(joinpath(temp_dir, "another_file.c"))

            # Test header discovery
            headers = @suppress find_wasmtime_headers(temp_dir)

            # Should find all .h files
            @test length(headers) == 3
            @test all(h -> endswith(h, ".h"), headers)
            @test all(h -> isfile(h), headers)

            # Should include subdirectory headers
            @test any(h -> occursin("subdir", h), headers)

            # Should not include non-header files
            @test !any(h -> endswith(h, ".txt"), headers)
            @test !any(h -> endswith(h, ".c"), headers)

            # Headers should be sorted
            @test issorted(headers)

        finally
            rm(temp_dir, recursive = true, force = true)
        end
    end

    @testset "Real Wasmtime Headers Discovery" begin
        # Test with actual wasmtime include directory
        include_path = @suppress get_wasmtime_include_path()
        headers = @suppress find_wasmtime_headers(include_path)

        # Should find some headers
        @test length(headers) > 0

        # All results should be header files
        @test all(h -> endswith(h, ".h"), headers)

        # All should be absolute paths
        @test all(h -> isabspath(h), headers)

        # All should exist
        @test all(h -> isfile(h), headers)

        # Should be sorted
        @test issorted(headers)

        # Should include wasmtime-related headers
        header_names = [basename(h) for h in headers]
        # This is a reasonable expectation for wasmtime headers
        @test any(name -> occursin("wasm", lowercase(name)), header_names)
    end

    @testset "Empty Directory Handling" begin
        temp_dir = mktempdir()

        try
            # Test with empty directory
            headers = @suppress find_wasmtime_headers(temp_dir)
            @test length(headers) == 0
            @test isa(headers, Vector{String})

        finally
            rm(temp_dir, recursive = true, force = true)
        end
    end

    @testset "Nested Directory Structure" begin
        temp_dir = mktempdir()

        try
            # Create nested directory structure
            mkdir(joinpath(temp_dir, "level1"))
            mkdir(joinpath(temp_dir, "level1", "level2"))
            mkdir(joinpath(temp_dir, "level1", "level2", "level3"))

            # Create headers at different levels
            touch(joinpath(temp_dir, "root.h"))
            touch(joinpath(temp_dir, "level1", "level1.h"))
            touch(joinpath(temp_dir, "level1", "level2", "level2.h"))
            touch(joinpath(temp_dir, "level1", "level2", "level3", "level3.h"))

            headers = @suppress find_wasmtime_headers(temp_dir)

            # Should find all headers regardless of nesting level
            @test length(headers) == 4

            # Should include headers from all levels
            @test any(h -> basename(h) == "root.h", headers)
            @test any(h -> basename(h) == "level1.h", headers)
            @test any(h -> basename(h) == "level2.h", headers)
            @test any(h -> basename(h) == "level3.h", headers)

        finally
            rm(temp_dir, recursive = true, force = true)
        end
    end

    @testset "Error Handling" begin
        # Test with non-existent directory - should return empty array
        result = @suppress find_wasmtime_headers("/nonexistent/directory")
        @test result == String[]
        @test isempty(result)

        # Test with file instead of directory - should return empty array
        temp_file = tempname()
        touch(temp_file)

        try
            result = @suppress find_wasmtime_headers(temp_file)
            @test result == String[]
            @test isempty(result)
        finally
            rm(temp_file, force = true)
        end
    end
end
