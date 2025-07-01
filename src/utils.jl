
mutable struct WasmLimits
    min::Int
    max::Int

    function WasmLimits(min::Int, max::Int)
        if min < 0 || (max != 0 && max < min)
            throw(
                ArgumentError(
                    "Invalid table limits: min must be non-negative and max must be greater than or equal to min",
                ),
            )
        end

        limits = new(min, max)
        return limits
    end
end

Base.show(io::IO, limits::WasmLimits) =
    print(io, "WasmTableLimits(min=$(limits.ptr.min), max=$(limits.ptr.max))")
Base.isvalid(limits::WasmLimits) =
    limits.min >= 0 && (limits.max == 0 || limits.max >= limits.min)
