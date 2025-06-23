@testset "WasmtimeRuntime.jl" begin
    @test WasmtimeRuntime.hello_world() == "Hello, World!"
end
