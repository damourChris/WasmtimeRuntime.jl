# Error handling for WasmtimeRuntime

# Error handling types
struct WasmtimeError <: Exception
    message::String
    code::Union{Int,Nothing}

    WasmtimeError(message::String) = new(message, nothing)
    WasmtimeError(message::String, code::Int) = new(message, code)
end

Base.showerror(io::IO, e::WasmtimeError) = print(io, "WasmtimeError: ", e.message)

# Utility function for error handling
function check_error(error_ptr::Ptr{LibWasmtime.wasmtime_error})
    if error_ptr != C_NULL
        # Get error message if available
        msg = "Wasmtime operation failed"
        # TODO: Extract actual error message from wasmtime_error
        LibWasmtime.wasmtime_error_delete(error_ptr)
        throw(WasmtimeError(msg))
    end
end

# Resource management utility macro
# NOTE: this was written with AI, I cannot guarantee it is correct.
macro safe_resource(typename, ctype, new_func, delete_func)
    quote
        mutable struct $(typename) <: WasmtimeResource
            ptr::Ptr{LibWasmtime.$(ctype)}

            function $(typename)(args...)
                ptr = LibWasmtime.$(new_func)(args...)
                if ptr == C_NULL
                    throw(WasmtimeError("Failed to create $($(string(typename)))"))
                end
                obj = new(ptr)
                finalizer(obj) do o
                    if o.ptr != C_NULL
                        LibWasmtime.$(delete_func)(o.ptr)
                        o.ptr = C_NULL
                    end
                end
                return obj
            end
        end

        # Add validity check
        Base.isvalid(obj::$(typename)) = obj.ptr != C_NULL
    end |> esc
end
