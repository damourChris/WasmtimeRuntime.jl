using WasmtimeRuntime
using Test

#=
Don't add your tests to runtests.jl. Instead, create files named

    test-title-for-my-test.jl

The file will be automatically included inside a `@testset` with title "Title For My Test".

If you want to run only a specific test file, you can pass the file name as an argument to the test command.
For example, to run only the test for a module named `test-module.jl`, you can run:
    julia --project -e 'using Pkg; Pkg.test(; test_args=["test-1.jl"])'
    or alternatively
    julia --project test/runtests.jl test-1.jl test-2.jl

Note that the file name must start with `test-` and end with `.jl`.
You can also pass multiple test files as arguments.
If you want to run all tests, just run:
    julia --project test/runtests.jl
=#

if !isempty(ARGS)
    # ARGS might have files in full path or just the file name so we just use the file name (no path)
    test_files = [splitpath(f)[end] for f in ARGS]
    # Filter for test files that start with "test-" and end with ".jl"
    test_files = filter(f -> startswith(f, "test-") && endswith(f, ".jl"), test_files)


    if isempty(test_files)
        @error "No valid test files provided. Please provide test files that start with 'test-' and end with '.jl'."
        exit(1)
    end

else
    test_files =
        filter(f -> startswith(f, "test-") && endswith(f, ".jl"), readdir(@__DIR__))
end

for (root, dirs, files) in walkdir(@__DIR__)
    for file in files
        if isnothing(match(r"^test-.*\.jl$", file))
            continue
        end
        title = titlecase(replace(splitext(file[6:end])[1], "-" => " "))

        file_name = splitpath(file)[end]

        if !(file_name in test_files)
            continue  # Skip this file if it's not in the test_args
        end

        @testset "$title" begin
            include(file)
        end
    end
end
