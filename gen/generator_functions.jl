# Include guard to prevent multiple inclusions
if !@isdefined(WASMTIME_GENERATOR_FUNCTIONS_LOADED)
    const WASMTIME_GENERATOR_FUNCTIONS_LOADED = true

    using Clang.Generators
    using Clang.LibClang.Clang_jll
    using Pkg.Artifacts
    using LoggingExtras
    using Dates

    # Enhanced logging setup with LoggingExtras
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

    # Enhanced architecture and ABI detection
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

        @debug "Detected base system info" arch = arch os = os word_size = Sys.WORD_SIZE

        # Set CPU target and ABI based on architecture
        if arch == :x86_64
            arch_info[:cpu_target] = "x86_64-$os-gnu"
            arch_info[:abi] = "lp64"  # Long and Pointer are 64-bit
            arch_info[:march] = "x86-64"
            @debug "Configured x86_64 architecture" target = arch_info[:cpu_target] abi =
                arch_info[:abi]
        elseif arch == :aarch64
            arch_info[:cpu_target] = "aarch64-$os-gnu"
            arch_info[:abi] = "lp64"
            arch_info[:march] = "armv8-a"
            @debug "Configured aarch64 architecture" target = arch_info[:cpu_target] abi =
                arch_info[:abi]
        elseif arch == :i686
            arch_info[:cpu_target] = "i686-$os-gnu"
            arch_info[:abi] = "ilp32"  # Int, Long, and Pointer are 32-bit
            arch_info[:march] = "i686"
            @debug "Configured i686 architecture" target = arch_info[:cpu_target] abi =
                arch_info[:abi]
        else
            @warn "Unknown architecture detected, using x86_64 defaults" unknown_arch = arch
            arch_info[:cpu_target] = "x86_64-linux-gnu"
            arch_info[:abi] = "lp64"
            arch_info[:march] = "x86-64"
        end

        @info "🎯 Target configuration completed" cpu_target = arch_info[:cpu_target] abi =
            arch_info[:abi] march = arch_info[:march]
        return arch_info
    end

    # Get the location of the binary wasmtime artifacts
    function get_wasmtime_include_path(;
        artifacts_toml = joinpath(@__DIR__, "Artifacts.toml"),
    )
        @debug "🔍 Locating Wasmtime artifacts and include directory"
        @debug "Looking for artifacts TOML" file = artifacts_toml

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
        @debug "Found Wasmtime artifact path" path = wasmtime_path

        child_folders = readdir(wasmtime_path)
        @debug "Artifact contents" folders = child_folders

        if isempty(child_folders)
            @error "Artifact directory is empty" path = parent_path
            error("Artifact directory is empty: $parent_path")
        end

        child_folder = child_folders[1]

        # The include directory should be under the first child folder
        include_path = joinpath(wasmtime_path, child_folder, "include")
        @debug "Checking include directory" path = include_path

        if !isdir(include_path)
            error("Include directory not found at: $include_path")
        end

        @debug "📁 Wasmtime include directory located" path = include_path
        return include_path
    end

    # Enhanced Clang argument construction
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

        @debug "Starting with default Clang args" default_args = args

        # Include paths
        push!(args, "-I" * include_path)
        @debug "Added include path" include_path

        # Target specification - CRITICAL for correct struct layout
        push!(args, "-target", target_info[:cpu_target])
        @debug "Set target specification" target = target_info[:cpu_target]

        # Architecture-specific flags
        push!(args, "-march=" * target_info[:march])
        @debug "Set architecture flags" march = target_info[:march]

        # Endianness (explicit for clarity)
        if target_info[:endianness] == :little
            push!(args, "-mlittle-endian")
            @debug "Set endianness" endianness = "little"
        else
            push!(args, "-mbig-endian")
            @debug "Set endianness" endianness = "big"
        end

        # ABI specification
        if target_info[:abi] == "lp64"
            push!(args, "-mabi=lp64")
            @debug "Set ABI" abi = "lp64"
        elseif target_info[:abi] == "ilp32"
            push!(args, "-mabi=ilp32")
            @debug "Set ABI" abi = "ilp32"
        end

        # Standard specification for consistency
        push!(args, "-std=c11")
        @debug "Set C standard" standard = "c11"

        # Optimization level (no optimization for precise layout)
        push!(args, "-O0")
        @debug "Set optimization level" level = "O0"

        # System-specific definitions
        if target_info[:os] == "linux"
            push!(args, "-D_GNU_SOURCE")
            push!(args, "-D__linux__")
            @debug "Added Linux-specific definitions"
        elseif target_info[:os] == "windows"
            push!(args, "-D_WIN32")
            push!(args, "-DWIN32")
            @debug "Added Windows-specific definitions"
        elseif target_info[:os] == "darwin"
            push!(args, "-D__APPLE__")
            push!(args, "-D__MACH__")
            @debug "Added macOS-specific definitions"
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
        @debug "Added Wasmtime-specific definitions" definitions = wasmtime_defs

        @info "🏗️ Clang argument construction complete" total_args = length(args)
        @debug "Final Clang arguments" args

        # Log arguments in a readable format for debugging
        for (i, arg) in enumerate(args)
            @debug "Clang arg [$i]" argument = arg
        end

        return args
    end

    # Find the headers to process
    # Automatically discover all header files in the include directory
    function find_wasmtime_headers(include_path)
        @debug "🔍 Discovering header files in include directory" path = include_path

        headers = String[]

        # Walk through the include directory and subdirectories
        for (root, dirs, files) in walkdir(include_path)
            for file in files
                if endswith(file, ".h")
                    header_path = joinpath(root, file)
                    push!(headers, header_path)
                    @debug "Found header file" file = header_path
                end
            end
        end

        # Sort headers for consistent ordering
        sort!(headers)

        @info "📄 Header discovery completed" total_headers = length(headers)

        # Log all discovered headers
        for (i, header) in enumerate(headers)
            @debug "Header [$i]" file = header
        end

        return headers
    end

    # Enhanced rewriter with detailed logging
    function create_rewriter_functions()
        function rewrite!(e::Expr)
            # Empty for now - this is where we'll add custom rewrites
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
            @debug "Rewrite statistics" total_nodes = node_count total_expressions =
                expr_count
        end

        return rewrite!
    end

    # Add a helper function to disable logging for tests
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

    # Main generation function that can be called explicitly
    function run_generation(; setup_logging = true)
        if setup_logging
            # Setup logging first
            setup_enhanced_logging()
        end

        @info "🔍 Enhanced LibWasmtime.jl Generator with Deep Clang.jl Integration"
        @info "="^70

        # Change to the generator directory
        cd(@__DIR__)

        # Load configuration
        @info "📋 Loading generator configuration..."
        wasmtime_include = get_wasmtime_include_path()
        target_info = get_detailed_target_info()

        @debug "Loading generator options from TOML"
        options = load_options(joinpath(@__DIR__, "generator.toml"))
        @debug "Generator options loaded" options

        @info "🎯 Target Information Summary" target_info

        # Build arguments
        @debug "Building Clang arguments"
        args = build_clang_args(target_info, wasmtime_include)

        # Find all headers automatically
        headers = find_wasmtime_headers(wasmtime_include)

        # Alternatively, if you want to be more selective, you can filter for specific patterns:
        # headers = filter(h -> any(pattern -> contains(h, pattern), ["wasm", "wasmtime"]),
        #                 find_wasmtime_headers(wasmtime_include))

        # Create context with enhanced error handling
        @info "🔨 Creating Clang.jl context..."
        @debug "Context creation parameters" headers args options

        try
            @debug "Initializing Clang context with headers and arguments"
            ctx = create_context(headers, args, options)
            @info "✅ Clang.jl context created successfully"

            # Build without printing for custom rewriting
            @info "🔄 Building AST (Stage 1: Parsing)..."
            @debug "Starting AST parsing phase"
            build!(ctx, BUILDSTAGE_NO_PRINTING)
            @info "✅ AST parsing completed"

            # Get rewriter function
            rewrite! = create_rewriter_functions()

            # Apply rewrites
            @debug "Starting custom rewrite phase"
            rewrite!(ctx.dag)

            # Print the final code
            @info "🔄 Building final code (Stage 2: Code Generation)..."
            @debug "Starting code generation phase"
            build!(ctx, BUILDSTAGE_PRINTING_ONLY)
            @info "✅ Code generation completed"

            @info "🎉 Generation process completed successfully!"

            return ctx

        catch e
            @error "❌ Failed to create Clang.jl context" exception = (e, catch_backtrace())
            @debug "Detailed error information" error_type = typeof(e) error_message =
                string(e)
            rethrow(e)
        end
    end

end  # End of include guard
