using Random
using Test
using WasmtimeRuntime

Random.seed!(1234)

@testset "Wat 2 Wasm conversion" begin

    @testset "should convert WAT to Wasm binary" begin
        # Define a simple WAT module
        wat_code = """
        (module
            (func (export "add") (param i32 i32) (result i32)
                local.get 0
                local.get 1
                i32.add)
        )
        """

        # Convert WAT to Wasm binary format
        wasm_binary = wat2wasm(wat_code)

        # Check that the result is a non-empty vector of UInt8
        @test !isempty(wasm_binary)
        @test length(wasm_binary) > 0

        # Check that the Wasm code matches the expected binary format
        @test wasm_binary[1:4] == UInt8[0x00, 0x61, 0x73, 0x6d]  # Magic number for Wasm
    end

    @testset "should handle empty WAT" begin
        # Define an empty WAT module
        empty_wat_code = "(module)"

        # Convert empty WAT to Wasm binary format
        wasm_binary = wat2wasm(empty_wat_code)

        @test !isempty(wasm_binary)
        @test length(wasm_binary) > 0
    end



    @testset "should handle WAT with comments" begin
        # Define a WAT module with comments
        wat_code_with_comments = """
        ;; This is a comment
        (module
            ;; Function to add two numbers
            (func (export "add") (param i32 i32) (result i32)
                local.get 0
                local.get 1
                i32.add)
        )
        """

        # Convert WAT to Wasm binary format
        wasm_binary = wat2wasm(wat_code_with_comments)

        @test !isempty(wasm_binary)
        @test length(wasm_binary) > 0
    end

    @testset "should throw error for invalid WAT" begin
        # Define an invalid WAT module (missing closing parenthesis)
        invalid_wat_code = """
        (module
            (func (export "add") (param i32 i32) (result i32)
                local.get 0
                local.get 1
                i32.add
        """

        # Expect an error when converting invalid WAT to Wasm binary
        @test_throws WasmtimeError wat2wasm(invalid_wat_code)
    end
end

@testset "Wat2wasm macro" begin
    @testset "should convert WAT string to Wasm binary using macro" begin
        # Define a simple WAT module
        wasm_binary = wat"""
        (module
            (func (export "add") (param i32 i32) (result i32)
                local.get 0
                local.get 1
                i32.add)
        )
        """

        # Check that the result is a non-empty vector of UInt8
        @test !isempty(wasm_binary)
        @test length(wasm_binary) > 0

        # Check that the Wasm code matches the expected binary format
        @test wasm_binary[1:4] == UInt8[0x00, 0x61, 0x73, 0x6d]  # Magic number for Wasm
    end

end # testset Wat 2 Wasm conversion
