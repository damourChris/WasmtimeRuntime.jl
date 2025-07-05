mutable struct WasmFuncType
    ptr::Ptr{LibWasmtime.wasm_functype_t}

    function WasmFuncType(params_types::Vector{DataType}, results_types::Vector{DataType})

        params = WasmPtrVec(params_types)
        results = WasmPtrVec(results_types)

        func_type_ptr = LibWasmtime.wasm_functype_new(params, results)

        @assert func_type_ptr != C_NULL "Failed to create WasmFuncType"

        func_type = new(func_type_ptr)

        finalizer(func_type) do ftype
            if ftype.ptr != C_NULL
                LibWasmtime.wasm_functype_delete(ftype.ptr)
                ftype.ptr = C_NULL
            end
        end

        return func_type
    end
end

Base.unsafe_convert(::Type{Ptr{LibWasmtime.wasm_functype_t}}, func_type::WasmFuncType) =
    func_type.ptr
Base.isvalid(func_type::WasmFuncType) = func_type.ptr != C_NULL
Base.show(io::IO, func_type::WasmFuncType) = print(io, "WasmFuncType()")

params(func_type::WasmFuncType) = LibWasmtime.wasm_functype_params(func_type)
results(func_type::WasmFuncType) = LibWasmtime.wasm_functype_results(func_type)

mutable struct WasmFunc <: Function
    ptr::Ptr{LibWasmtime.wasm_func_t}
    func_type::WasmFuncType
end

function WasmFunc(store::WasmStore, func::Function)

    # Create a function type based on the provided Julia function
    # For now just use the first method signature
    # TODO: support multiple signatures
    func_method = first(Base.methods(func))
    # Extract argument types (skip first parameter which is the function itself)
    arg_types::Vector{DataType} = func_method.sig.parameters[2:end] |> collect

    # Get return type for this specific method signature
    return_types = Base.return_types(func, Tuple{arg_types...})
    rt = isempty(return_types) ? Any : return_types[1]

    function jl_side_host(
        args::Ptr{wasm_val_vec_t},
        results::Ptr{wasm_val_vec_t},
    )::Ptr{wasm_trap_t}
        try
            # Convert wasm_val_vec_t to Julia types
            wasm_args = unsafe_load(args)

            converted_args = Vector{Any}(undef, wasm_args.size)

            for i = 1:wasm_args.size
                wasm_val = unsafe_load(wasm_args.data, i)

                # We transform the value to julia type based on args types
                if i <= length(arg_types)
                    arg_type = arg_types[i]
                    # @show wasm_val
                    # @show "Trying tonverting to type: $(wasm_val.kind) -> $arg_type"
                    converted_args[i] = convert(arg_type, wasm_val)
                else
                    # If there are more wasm values than expected, we can ignore them
                    continue

                end
            end

            # @show converted_args

            # Call the Julia function with converted arguments
            res = func(converted_args...)

            wasm_res = Ref(WasmValue(res))
            data_ptr = unsafe_load(results).data
            wasm_val_copy(data_ptr, wasm_res)

            C_NULL
        catch err
            err_msg = string(err)
            wasmtime_trap_new(err_msg, sizeof(err_msg))
        end
    end

    # Create a pointer to jl_side_host(args, results)
    func_ptr = Base.@cfunction(
        $jl_side_host,
        Ptr{wasm_trap_t},
        (Ptr{wasm_val_vec_t}, Ptr{wasm_val_vec_t})
    )

    functype = WasmFuncType(collect(arg_types), [rt])

    host_func_ptr = LibWasmtime.wasm_func_new(store, functype, func_ptr)

    @assert func_ptr != C_NULL "Failed to create WasmFunc"

    # Add the function pointer to the store's externs
    # This is necessary to ensure the function is not garbage collected
    add_extern_func!(store, func_ptr)


    wasmfunc = WasmFunc(host_func_ptr, functype)

    finalizer(wasmfunc) do f
        if f.ptr != C_NULL
            LibWasmtime.wasm_func_delete(f.ptr)
            f.ptr = C_NULL
        end
    end

    return wasmfunc
end

Base.unsafe_convert(::Type{Ptr{LibWasmtime.wasm_func_t}}, func::WasmFunc) = func.ptr
Base.isvalid(func::WasmFunc) = func.ptr != C_NULL
Base.show(io::IO, func::WasmFunc) = print(io, "WasmFunc()")

function (func::WasmFunc)(args...)

    params_arity = LibWasmtime.wasm_func_param_arity(func)
    result_arity = LibWasmtime.wasm_func_result_arity(func)

    provided_params = length(args)
    if params_arity != provided_params
        throw(
            WasmtimeError(
                "Function expects $params_arity parameters, but got $provided_params",
            ),
        )
    end

    # TODO: Check if the type of the args passed are convertable to the wasm func type


    converted_args = WasmValue.(args) |> collect
    params_vec = WasmValVec(converted_args)

    default_val = LibWasmtime.wasm_val_t(ntuple(x -> UInt8(0), Val(16)))
    results_vec = WasmValVec([default_val for _ = 1:result_arity])

    trap_ptr = LibWasmtime.wasm_func_call(
        func,                       # Function pointer (from proper extraction)
        params_vec,                 # Arguments array pointer
        results_vec,                # Results array pointer
    )

    # Check for trap first
    if trap_ptr != C_NULL
        # Extract trap message and clean up
        msg = WasmByteVec()
        LibWasmtime.wasm_trap_message(trap_ptr, msg)
        msg_str = String(msg)
        LibWasmtime.wasm_trap_delete(trap_ptr)
        throw(WasmtimeError("WebAssembly trap occurred during function call: $msg_str"))
    end

    results = collect(results_vec)

    if length(results) == 1
        return first(results)
    else
        return results
    end

end

function extract_function_types(func::Function)
    result = []



    #    fptr = QuoteNode(:($func))
    #     @show at = :(($arg_types...,))
    #     attr_svec = Expr(:call, GlobalRef(Core, :svec), at.args...)
    #     cfun = Expr(
    #         :cfunction,
    #         Base.CFunction,
    #         fptr,
    #         return_type,
    #         attr_svec,
    #         QuoteNode(:ccall),
    #     )
    #     @show cfun_ptr = eval(cfun)

    #     @show cfun_ptr.ptr


    push!(result, (arg_types = arg_types, return_type = rt))


    return result
end
