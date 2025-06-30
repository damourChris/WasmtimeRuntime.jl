"""
    WasmtimeRuntime.jl Code Generation Functions

Generates Julia bindings from Wasmtime's C API headers using Clang.jl.

# Main Functions
- `run_generation()`: Generate bindings
- `get_detailed_target_info()`: Detect system architecture
- `get_wasmtime_include_path()`: Locate header files
- `build_clang_args()`: Configure Clang compilation

# Usage
```julia
run_generation()  # Generate with default settings
```
"""

# Include guard to prevent multiple inclusions
if !@isdefined(WASMTIME_GENERATOR_FUNCTIONS_LOADED)
    const WASMTIME_GENERATOR_FUNCTIONS_LOADED = true

    using Clang.Generators
    using Clang.LibClang.Clang_jll
    using Pkg.Artifacts
    using LoggingExtras
    using Dates

    """
        setup_enhanced_logging() -> Logger

    Configure logging system with console output and debug file logging.
    Creates `generator_debug.log` for detailed debug information.
    """
    function setup_enhanced_logging()
        # Create different loggers for different purposes
        console_logger = ConsoleLogger(stdout, Logging.Info)

        # File logger for detailed debug information
        debug_file_logger = FileLogger(joinpath(@__DIR__, "generator_debug.log"))
        debug_logger = MinLevelLogger(debug_file_logger, Logging.Debug)

        # Progress logger with timestamps for tracking major steps
        timestamp_logger = TransformerLogger(console_logger) do log
            timestamp = Dates.format(now(), "HH:MM:SS.sss")
            if log.level >= Logging.Info
                merge(log, (message = "[$timestamp] $(log.message)",))
            else
                log
            end
        end

        # Main logger that routes to both console (with timestamps) and debug file
        main_logger = TeeLogger(
            MinLevelLogger(timestamp_logger, Logging.Info),  # Console with timestamps
            debug_logger,  # File with all debug info
        )

        # Set as global logger
        global_logger(main_logger)

        @info "🔧 Enhanced logging system initialized" debug_file = "generator_debug.log"
        return main_logger
    end

    """
        get_detailed_target_info() -> Dict{Symbol,Any}

    Detect system architecture and ABI information for Clang compilation.

    Returns target triple, ABI specification, and architecture details needed
    for accurate C header parsing and struct layout detection.
    """
    function get_detailed_target_info()
        @debug "🔍 Detecting system architecture and ABI information"

        arch = Sys.ARCH
        os =
            Sys.islinux() ? "linux" :
            Sys.iswindows() ? "windows" : Sys.isapple() ? "darwin" : "unknown"

        # Detailed architecture information
        arch_info = Dict{Symbol,Any}(
            :arch => arch,
            :os => os,
            :word_size => Sys.WORD_SIZE,
            :endianness => Base.ENDIAN_BOM == 0x01020304 ? :big : :little,
            :cpu_target => "",
            :abi => "",
        )

        # Set CPU target and ABI based on architecture
        if arch == :x86_64
            arch_info[:cpu_target] = "x86_64-$os-gnu"
            arch_info[:abi] = "lp64"  # Long and Pointer are 64-bit
            arch_info[:march] = "x86-64"
        elseif arch == :aarch64
            arch_info[:cpu_target] = "aarch64-$os-gnu"
            arch_info[:abi] = "lp64"
            arch_info[:march] = "armv8-a"
        elseif arch == :i686
            arch_info[:cpu_target] = "i686-$os-gnu"
            arch_info[:abi] = "ilp32"  # Int, Long, and Pointer are 32-bit
            arch_info[:march] = "i686"
        else
            @warn "Unknown architecture detected, using x86_64 defaults" unknown_arch = arch
            # Fallback to most common configuration
            arch_info[:cpu_target] = "x86_64-linux-gnu"
            arch_info[:abi] = "lp64"
            arch_info[:march] = "x86-64"
        end

        @info "🎯 Target configuration completed" cpu_target = arch_info[:cpu_target] abi =
            arch_info[:abi] march = arch_info[:march]
        return arch_info
    end

    """
        get_wasmtime_include_path(; artifacts_toml) -> String

    Locate Wasmtime C header files from project artifacts.

    Parses `Artifacts.toml` to find the `libwasmtime` artifact and returns
    the path to its include directory.

    Throws if `Artifacts.toml` is missing or `libwasmtime` artifact not found.
    Run `julia gen/build_artifacts.jl` to create artifacts first.
    """
    function get_wasmtime_include_path(;
        artifacts_toml = joinpath(@__DIR__, "..", "Artifacts.toml"),
    )
        @debug "🔍 Locating Wasmtime artifacts and include directory"

        if !isfile(artifacts_toml)
            error(
                "Artifacts.toml not found. Please run the artifact building script first.",
            )
        end

        # Parse the artifacts to find wasmtime
        meta = artifact_meta("libwasmtime", artifacts_toml)
        if meta === nothing
            error("libwasmtime artifact not found in Artifacts.toml")
        end

        # Get the wasmtime artifact directory
        wasmtime_path = artifact_path(artifact_hash("libwasmtime", artifacts_toml))

        child_folders = readdir(wasmtime_path)

        if isempty(child_folders)
            @error "Artifact directory is empty" path = parent_path
            error("Artifact directory is empty: $parent_path")
        end

        child_folder = child_folders[1]

        # Extract from the versioned subdirectory structure
        include_path = joinpath(wasmtime_path, child_folder, "include")

        if !isdir(include_path)
            error("Include directory not found at: $include_path")
        end

        @debug "📁 Wasmtime include directory located" path = include_path
        return include_path
    end

    """
        build_clang_args(target_info::Dict, include_path::String) -> Vector{String}

    Construct Clang compilation arguments for target architecture.

    Critical for ensuring correct struct layouts and ABI compatibility.
    Configures target specification, architecture flags, and preprocessor
    definitions for accurate C header parsing.
    """
    function build_clang_args(target_info, include_path)
        @debug "🔨 Building comprehensive Clang arguments for target compilation"

        # Start with basic arguments
        args = [
            "-v",  # Verbose for debugging
            "-x",
            "c",  # Treat input as C source
            "-Wall",  # Enable all warnings
            "-Wextra",  # Extra warnings
        ]

        default_args = get_default_args()
        [push!(args, da) for da in default_args]

        # Include paths
        push!(args, "-I" * include_path)

        # Target specification - CRITICAL for correct struct layout
        push!(args, "-target", target_info[:cpu_target])

        # Architecture-specific flags
        push!(args, "-march=" * target_info[:march])

        # Endianness (explicit for clarity)
        if target_info[:endianness] == :little
            push!(args, "-mlittle-endian")
        else
            push!(args, "-mbig-endian")
        end

        # ABI specification - critical for struct layout compatibility
        if target_info[:abi] == "lp64"
            push!(args, "-mabi=lp64")
        elseif target_info[:abi] == "ilp32"
            push!(args, "-mabi=ilp32")
        end

        # Standard specification for consistency
        push!(args, "-std=c11")

        # Optimization level (no optimization for precise layout)
        push!(args, "-O0")

        # System-specific definitions
        if target_info[:os] == "linux"
            push!(args, "-D_GNU_SOURCE")
            push!(args, "-D__linux__")
        elseif target_info[:os] == "windows"
            push!(args, "-D_WIN32")
            push!(args, "-DWIN32")
        elseif target_info[:os] == "darwin"
            push!(args, "-D__APPLE__")
            push!(args, "-D__MACH__")
        end

        # Wasmtime-specific definitions
        wasmtime_defs = [
            "-DWASI_API_EXTERN=",
            "-DWASM_API_EXTERN=",
            "-DWASMTIME_API_EXTERN=",
            "-DWASMTIME_FEATURE_WASI=1",
            "-DWASMTIME_FEATURE_POOLING_ALLOCATOR=1",
            "-DWASMTIME_FEATURE_COMPONENT_MODEL=1",
        ]

        for def in wasmtime_defs
            push!(args, def)
        end

        @info "🏗️ Clang argument construction complete" total_args = length(args)

        return args
    end

    """
        find_wasmtime_headers(include_path::String) -> Vector{String}

    Discover all C header files in the Wasmtime include directory.

    Recursively searches for `.h` files and returns sorted absolute paths
    for consistent processing order.
    """
    function find_wasmtime_headers(include_path)
        @debug "🔍 Discovering header files in include directory" path = include_path

        headers = String[]

        # Walk through the include directory and subdirectories
        for (root, dirs, files) in walkdir(include_path)
            for file in files
                if endswith(file, ".h")
                    header_path = joinpath(root, file)
                    push!(headers, header_path)
                end
            end
        end

        # Sort headers for consistent ordering
        sort!(headers)

        @info "📄 Header discovery completed" total_headers = length(headers)

        return headers
    end

    """
        create_rewriter_functions() -> Function

    Create AST rewriting framework for post-processing generated code.

    Provides extension points for future enhancements. Currently minimal
    to avoid breaking changes.
    """
    function create_rewriter_functions()
        function rewrite!(e::Expr)
            Meta.isexpr(e, :const) || return e

            eq = e.args[1]

            # replace assignments to WASM_EMPTY_VEC to nothing
            if eq.head === :(=) && eq.args[1] === :WASM_EMPTY_VEC
                e.args[1].args[2] = nothing
                # replace assignments to wasm_name and wasm_byte_vec to wasm_byte_vec_t
            elseif eq.head === :(=) &&
                   eq.args[1] === :wasm_name &&
                   eq.args[2] === :wasm_byte_vec
                e.args[1].args[2] = :wasm_byte_vec_t
                # replace assignments to wasm_byte_t to UInt8
            elseif eq.head === :(=) && eq.args[1] === :wasm_byte_t
                e.args[1].args[2] = :UInt8
            end

            return e
        end

        function rewrite!(dag::ExprDAG)
            @info "🔄 Applying custom AST rewrites..."
            node_count = 0
            expr_count = 0

            for node in get_nodes(dag)
                node_count += 1
                for expr in get_exprs(node)
                    expr_count += 1
                    rewrite!(expr)
                end
            end

            @info "✅ AST rewriting completed" nodes_processed = node_count expressions_processed =
                expr_count
        end

        return rewrite!
    end

    """
        with_quiet_logging(f::Function) -> Any

    Execute function with suppressed logging (errors only).

    Useful for testing or reducing output during generation.
    """
    function with_quiet_logging(f)
        original_logger = global_logger()
        try
            # Set a logger that only shows errors
            quiet_logger = ConsoleLogger(stderr, Logging.Error)
            global_logger(quiet_logger)
            return f()
        finally
            global_logger(original_logger)
        end
    end

    """
        run_generation(; setup_logging::Bool = true) -> Context

    Execute the complete Wasmtime Julia binding generation process.

    Orchestrates system detection, Clang configuration, AST processing,
    and code generation to produce `../src/LibWasmtime.jl`.

    # Arguments
    - `setup_logging::Bool = true`: Configure enhanced logging

    # Examples
    ```julia
    ctx = run_generation()                      # Standard generation
    ctx = run_generation(setup_logging = false) # Quiet generation
    ```

    Generated output: `../src/LibWasmtime.jl` with complete C API bindings.
    Debug output: `generator_debug.log` (if logging enabled).
    """
    function run_generation(; setup_logging = true)
        if setup_logging
            # Setup logging first
            setup_enhanced_logging()
        end

        @info "🔍 Enhanced LibWasmtime.jl Generator with Deep Clang.jl Integration"

        # Change to the generator directory
        cd(@__DIR__)

        # Load configuration
        @info "📋 Loading generator configuration..."
        wasmtime_include = get_wasmtime_include_path()
        target_info = get_detailed_target_info()

        options = load_options(joinpath(@__DIR__, "generator.toml"))

        @info "🎯 Target Information Summary" target_info

        # Build arguments
        args = build_clang_args(target_info, wasmtime_include)

        # Find all headers automatically
        headers = find_wasmtime_headers(wasmtime_include)

        # Alternatively, if you want to be more selective, you can filter for specific patterns:
        # headers = filter(h -> any(pattern -> contains(h, pattern), ["wasm", "wasmtime"]),
        #                 find_wasmtime_headers(wasmtime_include))

        # Create context with enhanced error handling
        @info "🔨 Creating Clang.jl context..."

        try
            ctx = create_context(headers, args, options)
            @info "✅ Clang.jl context created successfully"

            # Build without printing for custom rewriting
            @info "🔄 Building AST (Stage 1: Parsing)..."
            build!(ctx, BUILDSTAGE_NO_PRINTING)
            @info "✅ AST parsing completed"

            # Get rewriter function
            rewrite! = create_rewriter_functions()

            # Apply rewrites
            rewrite!(ctx.dag)

            # Print the final code
            @info "🔄 Building final code (Stage 2: Code Generation)..."
            build!(ctx, BUILDSTAGE_PRINTING_ONLY)
            @info "✅ Code generation completed"

            @info "🎉 Generation process completed successfully!"

            return ctx

        catch e
            @error "❌ Failed to create Clang.jl context" exception = (e, catch_backtrace())
            rethrow(e)
        end
    end

end  # End of include guard
