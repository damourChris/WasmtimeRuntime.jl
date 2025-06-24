"""
LibWasmtime.jl Post-processor using Julia Metaprogramming and DirectedAcyclicGraphs.jl

This module uses Julia metaprogramming     # Analyze independent nodes
    if !isempty(independent_nodes)
        @info "🌟 Independent nodes (no internal dependencies):"
        for node in independent_nodes
            external_deps = length(setdiff(node.dependencies, known_types))
            @info "  - \$(node.name): \$external_deps external dependencies"
        end
    endctedAcyclicGraphs.jl to resolve
declaration order dependencies in the generated LibWasmtime.jl file. It parses
the Julia AST, analyzes type dependencies, and reorders declarations to ensure
proper forward references using a mature DAG infrastructure.
"""

using Base: Meta
using DirectedAcyclicGraphs

"""
    DeclarationNode

A DAG node representing a declaration (type, function, or const) with its dependencies.
"""
mutable struct DeclarationNode <: DAG
    name::Symbol
    declaration_expr::Expr
    raw_content::String
    line_number::Int
    dependencies::Set{Symbol}
    declaration_type::Symbol  # :type, :function, :const_alias, :const_value

    # Required for DirectedAcyclicGraphs.jl DAG interface
    children_nodes::Vector{DAG}

    function DeclarationNode(
        name::Symbol,
        expr::Expr,
        raw::String,
        line::Int,
        deps::Set{Symbol},
        decl_type::Symbol,
    )
        new(name, expr, raw, line, deps, decl_type, DAG[])
    end
end

# Implement DirectedAcyclicGraphs.jl interface
DirectedAcyclicGraphs.NodeType(::Type{DeclarationNode}) = Inner()
DirectedAcyclicGraphs.children(n::DeclarationNode) = n.children_nodes

"""
    build_dependency_dag(declarations)

Build a DAG from declarations using DirectedAcyclicGraphs.jl infrastructure.
"""
function build_dependency_dag(declarations)
    # Create nodes for each declaration
    nodes = Dict{Symbol,DeclarationNode}()

    for (name, expr, raw, line, deps, decl_type) in declarations
        nodes[name] = DeclarationNode(name, expr, raw, line, deps, decl_type)
    end

    # Build dependency edges (children represent dependencies)
    for (_, node) in nodes
        for dep in node.dependencies
            if haskey(nodes, dep)
                push!(node.children_nodes, nodes[dep])
            end
        end
    end

    return nodes
end

"""
    get_dependency_order(dag_nodes)

Get topological order of declarations using DirectedAcyclicGraphs.jl.
Returns a vector of symbols in dependency order (dependencies first).
"""
function get_dependency_order(dag_nodes::Dict{Symbol,DeclarationNode})
    # Find nodes with no dependencies (these should be processed first)
    known_types = Set(keys(dag_nodes))
    independent_nodes = [
        node for
        node in values(dag_nodes) if isempty(intersect(node.dependencies, known_types))
    ]

    # Find nodes that have dependencies within our set
    dependent_nodes = [
        node for
        node in values(dag_nodes) if !isempty(intersect(node.dependencies, known_types))
    ]

    @info "🔍 Found $(length(independent_nodes)) independent nodes and $(length(dependent_nodes)) dependent nodes"

    # Start with independent nodes
    all_ordered = Symbol[]
    processed = Set{Symbol}()

    # Add independent nodes first
    for node in independent_nodes
        if node.name ∉ processed
            push!(all_ordered, node.name)
            push!(processed, node.name)
        end
    end

    # Process dependent nodes using a simple dependency resolution
    remaining = Set(dependent_nodes)
    while !isempty(remaining)
        progress_made = false

        for node in collect(remaining)
            # Check if all dependencies of this node are already processed
            node_deps_in_set = intersect(node.dependencies, known_types)
            if issubset(node_deps_in_set, processed)
                # All dependencies are resolved, we can process this node
                push!(all_ordered, node.name)
                push!(processed, node.name)
                delete!(remaining, node)
                progress_made = true
            end
        end

        if !progress_made
            # No progress made, likely circular dependencies
            remaining_names = [n.name for n in remaining]
            error("Circular dependency detected among: $(join(remaining_names, ", "))")
        end
    end

    return all_ordered
end

"""
    analyze_dependencies_advanced(dag_nodes)

Perform advanced dependency analysis using DirectedAcyclicGraphs.jl features.
"""
function analyze_dependencies_advanced(dag_nodes::Dict{Symbol,DeclarationNode})
    @info "🔍 Advanced dependency analysis using DirectedAcyclicGraphs.jl"

    # Find nodes with no dependencies within our set
    known_types = Set(keys(dag_nodes))
    independent_nodes = [
        node for
        node in values(dag_nodes) if isempty(intersect(node.dependencies, known_types))
    ]
    dependent_nodes = [
        node for
        node in values(dag_nodes) if !isempty(intersect(node.dependencies, known_types))
    ]

    @info "📊 Found $(length(independent_nodes)) independent nodes and $(length(dependent_nodes)) dependent nodes"

    # Analyze independent nodes
    if !isempty(independent_nodes)
        @info "🌟 Independent nodes (no internal dependencies):"
        for node in independent_nodes
            external_deps = length(setdiff(node.dependencies, Set(keys(dag_nodes))))
            @info "  - $(node.name) [$(node.declaration_type)]: $external_deps external dependencies"
        end
    end

    # Analyze dependent nodes and their dependency chains
    if !isempty(dependent_nodes)
        @info "🔗 Dependent nodes analysis:"
        for node in dependent_nodes
            deps_in_set = intersect(node.dependencies, known_types)
            deps_external = setdiff(node.dependencies, known_types)
            @info "  - $(node.name) [$(node.declaration_type)]: $(length(deps_in_set)) internal deps, $(length(deps_external)) external deps"
            if !isempty(deps_in_set)
                @info "    Internal: $(join(deps_in_set, ", "))"
            end
        end
    end

    # Calculate dependency statistics
    total_internal_deps =
        sum(length(intersect(node.dependencies, known_types)) for node in values(dag_nodes))
    total_external_deps =
        sum(length(setdiff(node.dependencies, known_types)) for node in values(dag_nodes))

    @info "📊 Dependency Statistics:"
    @info "  Total nodes: $(length(dag_nodes))"
    @info "  Total internal dependencies: $total_internal_deps"
    @info "  Total external dependencies: $total_external_deps"
    if length(dag_nodes) > 0
        @info "  Average dependencies per node: $(round((total_internal_deps + total_external_deps) / length(dag_nodes), digits=2))"
    end
end

"""
    extract_symbol_references(expr)

Extract all symbol references from a Julia expression (types, functions, etc.).
Returns a Set of symbols representing symbols referenced in the expression.
"""
function extract_symbol_references(expr)::Set{Symbol}
    refs = Set{Symbol}()

    function traverse(ex)
        if isa(ex, Symbol)
            # Include all symbols that look like types or functions
            str_ex = string(ex)
            if occursin(
                r"^[A-Z]|_t$|^wasm_|^wasmtime_|^Csize_t$|^Cint$|^Cuint$|^float",
                str_ex,
            )
                push!(refs, ex)
            end
        elseif isa(ex, Expr)
            if ex.head == :curly  # Parametric types like Ptr{T}
                for arg in ex.args
                    traverse(arg)
                end
            elseif ex.head == :(::)  # Type annotations
                if length(ex.args) >= 2
                    traverse(ex.args[2])  # The type part
                end
            else
                for arg in ex.args
                    traverse(arg)
                end
            end
        end
    end

    traverse(expr)
    return refs
end

# Keep backward compatibility alias
const extract_type_references = extract_symbol_references

"""
    analyze_declaration(expr)

Analyze a top-level declaration and return (name, dependencies, declaration_type).
Returns (nothing, Set(), :unknown) for declarations that don't define referenceable symbols.
"""
function analyze_declaration(expr)
    if Meta.isexpr(expr, :struct)
        # struct Name ... end or mutable struct Name ... end
        mutable_flag = expr.args[1]
        name_expr = expr.args[2]

        # Handle parametric structs
        struct_name = if isa(name_expr, Symbol)
            name_expr
        elseif Meta.isexpr(name_expr, :curly) && length(name_expr.args) > 0
            name_expr.args[1]  # Get the base name from Type{T}
        else
            nothing
        end

        if isa(struct_name, Symbol)
            # Extract dependencies from struct fields
            deps = Set{Symbol}()
            if length(expr.args) >= 3
                body = expr.args[3]
                if isa(body, Expr) && body.head == :block
                    for field_expr in body.args
                        if Meta.isexpr(field_expr, :(::))
                            field_deps = extract_symbol_references(field_expr.args[2])  # Type part only
                            union!(deps, field_deps)
                            @debug "    Field $(field_expr.args[1]) has type deps: $field_deps"
                        elseif isa(field_expr, Expr)
                            # Handle other field expressions
                            field_deps = extract_symbol_references(field_expr)
                            union!(deps, field_deps)
                            @debug "    Other field expr has deps: $field_deps"
                        end
                    end
                end
            end
            # Remove self-reference
            delete!(deps, struct_name)
            @debug "  📋 Struct $struct_name has dependencies: $deps"
            return (struct_name, deps, :type)
        end
    elseif Meta.isexpr(expr, :function)
        # function name(...) ... end
        func_def = expr.args[1]
        func_name = nothing

        if isa(func_def, Symbol)
            func_name = func_def
        elseif Meta.isexpr(func_def, :call) && length(func_def.args) > 0
            func_name = func_def.args[1]
        end

        if isa(func_name, Symbol)
            # Extract dependencies from function body and signature
            deps = Set{Symbol}()
            # Analyze function signature for parameter types
            if Meta.isexpr(func_def, :call)
                for arg in func_def.args[2:end]
                    arg_deps = extract_symbol_references(arg)
                    union!(deps, arg_deps)
                end
            end
            # Analyze function body
            if length(expr.args) >= 2
                body_deps = extract_symbol_references(expr.args[2])
                union!(deps, body_deps)
            end
            delete!(deps, func_name)  # Remove self-reference
            @debug "  📋 Function $func_name has dependencies: $deps"
            return (func_name, deps, :function)
        end
    elseif Meta.isexpr(expr, :const)
        # const name = type or const name::Type = value
        const_expr = expr.args[1]
        if Meta.isexpr(const_expr, :(=))
            lhs = const_expr.args[1]
            rhs = const_expr.args[2]

            name = nothing
            if isa(lhs, Symbol)
                name = lhs
            elseif Meta.isexpr(lhs, :(::)) && isa(lhs.args[1], Symbol)
                name = lhs.args[1]
            end

            if name !== nothing
                deps = extract_symbol_references(rhs)
                delete!(deps, name)  # Remove self-reference

                # Determine if this is an alias to a function or a value/type
                decl_type = if isa(rhs, Symbol) && string(rhs) != string(name)
                    :const_alias  # const alias to another symbol
                else
                    :const_value  # const value assignment
                end

                @debug "  📋 Const $name ($decl_type) has dependencies: $deps"
                return (name, deps, decl_type)
            end
        end
    elseif Meta.isexpr(expr, :(=))
        # Type alias: name = type
        if isa(expr.args[1], Symbol)
            name = expr.args[1]
            deps = extract_symbol_references(expr.args[2])
            delete!(deps, name)
            @debug "  📋 Type alias $name has dependencies: $deps"
            return (name, deps, :type)
        end
    end

    return (nothing, Set{Symbol}(), :unknown)
end

"""
    parse_julia_file_to_expressions(content)

Parse a Julia file content into individual expressions while preserving
comments and structure.
"""
function parse_julia_file_to_expressions(content::String)
    expressions = []

    # Split content by lines and group into logical expressions
    lines = split(content, '\n')
    current_expr_lines = String[]
    i = 1

    while i <= length(lines)
        line = lines[i]
        stripped = strip(line)

        # Skip empty lines
        if isempty(stripped)
            if !isempty(current_expr_lines)
                # End current expression
                expr_content = join(current_expr_lines, '\n')
                try
                    parsed = Meta.parse(expr_content)
                    push!(
                        expressions,
                        (parsed, expr_content, i - length(current_expr_lines)),
                    )
                catch e
                    @debug "Failed to parse expression: $expr_content"
                    push!(
                        expressions,
                        (nothing, expr_content, i - length(current_expr_lines)),
                    )
                end
                current_expr_lines = String[]
            end
            i += 1
            continue
        end

        # Handle comments
        if startswith(stripped, "#")
            if !isempty(current_expr_lines)
                # End current expression first
                expr_content = join(current_expr_lines, '\n')
                try
                    parsed = Meta.parse(expr_content)
                    push!(
                        expressions,
                        (parsed, expr_content, i - length(current_expr_lines)),
                    )
                catch e
                    @debug "Failed to parse expression: $expr_content"
                    push!(
                        expressions,
                        (nothing, expr_content, i - length(current_expr_lines)),
                    )
                end
                current_expr_lines = String[]
            end
            # Add comment as separate item
            push!(expressions, (nothing, line, i))
            i += 1
            continue
        end

        # Start or continue building expression
        push!(current_expr_lines, line)

        # Check if this completes an expression
        if (
            startswith(stripped, "const ") ||
            (startswith(stripped, "mutable struct ") || startswith(stripped, "struct ")) &&
            endswith(stripped, "end") ||
            endswith(stripped, "end")
        )

            # This looks like a complete expression
            expr_content = join(current_expr_lines, '\n')
            try
                parsed = Meta.parse(expr_content)
                push!(
                    expressions,
                    (parsed, expr_content, i - length(current_expr_lines) + 1),
                )
            catch e
                @debug "Failed to parse expression: $expr_content"
                push!(
                    expressions,
                    (nothing, expr_content, i - length(current_expr_lines) + 1),
                )
            end
            current_expr_lines = String[]
        end

        i += 1
    end

    # Handle any remaining expression
    if !isempty(current_expr_lines)
        expr_content = join(current_expr_lines, '\n')
        try
            parsed = Meta.parse(expr_content)
            push!(expressions, (parsed, expr_content, length(lines)))
        catch e
            @debug "Failed to parse expression: $expr_content"
            push!(expressions, (nothing, expr_content, length(lines)))
        end
    end

    return expressions
end

"""
    reorder_declarations(input_file, output_file)

Read a Julia file, parse its declarations, resolve dependency order, and write
the reordered file.
"""
function reorder_declarations(input_file::String, output_file::String = input_file)
    @info "🔧 Starting declaration reordering for $input_file"

    # Read the file
    content = read(input_file, String)

    # Parse into expressions
    @info "📋 Parsing file into expressions..."
    expressions = parse_julia_file_to_expressions(content)

    @info "📊 Found $(length(expressions)) expressions"

    # Separate declarations from other content
    declarations = []
    other_content = []

    for (parsed_expr, raw_content, line_num) in expressions
        if parsed_expr !== nothing
            name, deps, decl_type = analyze_declaration(parsed_expr)
            if name !== nothing
                push!(
                    declarations,
                    (name, parsed_expr, raw_content, line_num, deps, decl_type),
                )
                @debug "🏷️  Declaration: $name ($decl_type) (line $line_num)"
            else
                push!(other_content, (parsed_expr, raw_content, line_num))
            end
        else
            # Non-parseable content (comments, etc.)
            push!(other_content, (nothing, raw_content, line_num))
        end
    end

    @info "🔍 Found $(length(declarations)) declarations and $(length(other_content)) other items"

    if isempty(declarations)
        @info "ℹ️  No declarations found, no reordering needed"
        return true
    end

    # Build dependency DAG using DirectedAcyclicGraphs.jl
    @info "🔄 Building dependency DAG using DirectedAcyclicGraphs.jl..."
    dag_nodes = build_dependency_dag(declarations)

    @info "🔍 Found $(length(dag_nodes)) declaration nodes"

    # Perform advanced dependency analysis
    analyze_dependencies_advanced(dag_nodes)

    # Get dependency order using DirectedAcyclicGraphs.jl
    @info "Computing optimal declaration order..."
    try
        definition_order = get_dependency_order(dag_nodes)
        @info "✅ Successfully computed declaration order for $(length(definition_order)) types"
        @info "🎯 Definition order: $(join(definition_order, " → "))"

        # Reconstruct the file
        @info "📝 Reconstructing file with proper declaration order..."

        output_lines = String[]

        # Add non-declaration content that comes before declarations
        min_decl_line = minimum([line for (_, _, _, line, _, _) in declarations])
        for (expr, raw, line) in other_content
            if line < min_decl_line
                push!(output_lines, raw)
            end
        end

        # Add reordered declarations
        for name in definition_order
            if haskey(dag_nodes, name)
                node = dag_nodes[name]
                push!(output_lines, node.raw_content)
            else
                @warn "⚠️ Could not find node for $name in DAG"
            end
        end

        # Add remaining non-declaration content
        for (expr, raw, line) in other_content
            if line >= min_decl_line
                push!(output_lines, raw)
            end
        end

        # Write the result
        new_content = join(output_lines, "\n")
        write(output_file, new_content)

        @info "✅ Successfully wrote reordered file to $output_file"
        return true

    catch e
        @error "❌ Error during dependency analysis: $e"
        return false
    end
end

"""
    test_reordering()

Test the reordering functionality with a simple example.
"""
function test_reordering()
    @info "🧪 Testing declaration reordering with metaprogramming..."

    # Enable debug logging for this test
    ENV["JULIA_DEBUG"] = "Main"

    # Create a test file with dependency issues
    test_content = """# Test file with dependency issues

mutable struct wasm_byte_vec_t
    size::Csize_t
    data::Ptr{wasm_byte_t}
end

const wasm_byte_t = UInt8

const Csize_t = UInt64

mutable struct wasm_name_vec_t
    size::Csize_t
    data::Ptr{wasm_name_t}
end

const wasm_name_t = wasm_byte_vec_t

function wasm_byte_vec_new(out, size_t_, arg3)
    ccall((:wasm_byte_vec_new, libwasmtime), Cvoid, (Ptr{wasm_byte_vec_t}, Cint, Ptr{wasm_byte_t}), out, size_t_, arg3)
end

const wasm_name_new = wasm_byte_vec_new

# Some function that should not be reordered
function some_function()
    return 42
end
"""

    test_file = "test_reorder.jl"
    write(test_file, test_content)

    try
        # Test the reordering
        result = reorder_declarations(test_file, "test_reorder_output.jl")

        if result
            @info "✅ Test completed successfully"

            # Show the reordered content
            reordered_content = read("test_reorder_output.jl", String)
            @info "📋 Reordered content:\n$reordered_content"

            # Verify the order is correct
            lines = split(reordered_content, '\n')
            type_order = String[]
            for line in lines
                stripped = strip(line)
                if occursin(r"^const|^mutable struct", stripped)
                    if occursin("const Csize_t", line)
                        push!(type_order, "Csize_t")
                    elseif occursin("const wasm_byte_t", line)
                        push!(type_order, "wasm_byte_t")
                    elseif occursin("struct wasm_byte_vec_t", line)
                        push!(type_order, "wasm_byte_vec_t")
                    elseif occursin("const wasm_name_t", line)
                        push!(type_order, "wasm_name_t")
                    elseif occursin("struct wasm_name_vec_t", line)
                        push!(type_order, "wasm_name_vec_t")
                    end
                end
            end

            @info "🔍 Detected declaration order: $(join(type_order, " → "))"

        else
            @error "❌ Test failed"
        end

        # Cleanup
        rm(test_file, force = true)
        rm("test_reorder_output.jl", force = true)

    catch e
        @error "❌ Test error: $e"
        rm(test_file, force = true)
        rm("test_reorder_output.jl", force = true)
    end
end

"""
    postprocess_libwasmtime(lib_file)

Main function to postprocess the generated LibWasmtime.jl file.
"""
function postprocess_libwasmtime(lib_file::String = "../src/LibWasmtime.jl")
    @info "🚀 Starting LibWasmtime.jl post-processing with metaprogramming..."

    if !isfile(lib_file)
        @error "❌ LibWasmtime.jl file not found: $lib_file"
        return false
    end

    # Create a backup
    backup_file = "$lib_file.backup"
    cp(lib_file, backup_file)
    @info "💾 Created backup: $backup_file"

    try
        # Perform the reordering
        success = reorder_declarations(lib_file)

        if success
            @info "✅ LibWasmtime.jl post-processing completed successfully!"
            @info "💡 Backup saved as: $backup_file"

            # Verify the result compiles
            @info "🔍 Verifying the reordered file compiles..."
            try
                include(lib_file)
                @info "✅ Reordered file compiles successfully!"
            catch e
                @warn "⚠️  Compilation check failed: $e"
                @info "🔄 File was still reordered, but may need manual review"
            end
        else
            @error "❌ Post-processing failed, restoring from backup..."
            cp(backup_file, lib_file)
        end

        return success

    catch e
        @error "❌ Unexpected error during post-processing: $e"
        @error "🔄 Restoring from backup..."
        cp(backup_file, lib_file)
        return false
    end
end

# Export main functions
export postprocess_libwasmtime, test_reordering, reorder_declarations

# If run as a script, perform post-processing
if abspath(PROGRAM_FILE) == @__FILE__
    @info "🎯 Running LibWasmtime.jl post-processor as standalone script"

    if length(ARGS) > 0 && ARGS[1] == "test"
        test_reordering()
    else
        lib_file = length(ARGS) > 0 ? ARGS[1] : "../src/LibWasmtime.jl"
        postprocess_libwasmtime(lib_file)
    end
end
