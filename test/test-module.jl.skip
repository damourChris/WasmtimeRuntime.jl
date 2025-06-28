using Random
using Test
using WasmtimeRuntime

# Set deterministic seed for reproducible tests
Random.seed!(1234)

@testset "Module - WebAssembly Module Management" begin
    @testset "Module Type Hierarchy" begin
        @testset "Module inherits from AbstractModule" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            # Create a minimal valid WASM module (empty module)
            # This is a valid empty WASM module in binary format
            empty_wasm = UInt8[
                0x00,
                0x61,
                0x73,
                0x6d,  # WASM magic number
                0x01,
                0x00,
                0x00,
                0x00,   # Version 1
            ]

            module_obj = WasmModule(store, empty_wasm)

            @test module_obj isa WasmModule
            @test module_obj isa AbstractModule
            @test module_obj isa WasmtimeResource
            @test module_obj isa WasmtimeObject
        end
    end

    @testset "Module Creation and Basic Properties" begin
        @testset "should create module successfully with valid engine and WASM bytes" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            # Valid empty WASM module
            empty_wasm = UInt8[
                0x00,
                0x61,
                0x73,
                0x6d,  # WASM magic number
                0x01,
                0x00,
                0x00,
                0x00,   # Version 1
            ]

            module_obj = WasmModule(store, empty_wasm)

            @test module_obj isa WasmModule
            @test isvalid(module_obj)
            @test module_obj.ptr != C_NULL

        end

        @testset "should throw WasmtimeError when WASM bytes are invalid" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            # Invalid WASM bytes
            invalid_wasm = UInt8[0x00, 0x00, 0x00, 0x00]

            @test_throws WasmtimeError WasmModule(store, invalid_wasm)
        end

        @testset "should throw WasmtimeError when WASM bytes are empty" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            empty_bytes = UInt8[]

            @test_throws WasmtimeError WasmModule(store, empty_bytes)
        end
    end

    @testset "Module Creation from File Path" begin
        @testset "Module creation from valid file path" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            # Create a temporary WASM file
            mktempdir() do temp_dir
                wasm_file = joinpath(temp_dir, "test.wasm")

                # Write valid empty WASM module to file
                empty_wasm = UInt8[0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]
                write(wasm_file, empty_wasm)

                module_obj = WasmModule(store, wasm_file)

                @test module_obj isa WasmModule
                @test isvalid(module_obj)

            end
        end

        @testset "Module creation from non-existent file should fail" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            non_existent_file = "non_existent_file.wasm"

            @test_throws SystemError WasmModule(store, non_existent_file)
        end

        @testset "Module creation from invalid WASM file should fail" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            mktempdir() do temp_dir
                invalid_file = joinpath(temp_dir, "invalid.wasm")
                write(invalid_file, "invalid content")

                @test_throws WasmtimeError WasmModule(store, invalid_file)
            end
        end
    end

    @testset "Module Creation from WAT (WebAssembly Text)" begin
        @testset "WAT to WASM conversion not yet implemented" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            wat_content = "(module)"

            # Should throw error since WAT conversion is not implemented
            # @test_broken WasmtimeError WasmModule(store, wat_content, Val(:wat))
        end
    end

    @testset "Module Validation Functions" begin
        @testset "Validation with valid WASM bytes" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            empty_wasm = UInt8[0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]

            @test validate(store, empty_wasm) == true
        end

        @testset "Validation with invalid WASM bytes" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            invalid_wasm = UInt8[0x00]

            # This is broken Somehow this is a valid WASM module on macos but not on linux
            # @test validate(store, invalid_wasm) == false
        end

        @testset "Validation with empty bytes" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            empty_bytes = UInt8[]

            @test validate(store, empty_bytes) == false
        end

        @testset "Validation with invalid store should return false" begin
            engine = WasmEngine()
            store = WasmStore(engine)
            store.ptr = C_NULL  # Make engine invalid

            empty_wasm = UInt8[0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]

            @test validate(store, empty_wasm) == false
        end
    end

    @testset "Module Introspection Functions" begin
        @testset "Exports function with valid module" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            empty_wasm = UInt8[0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]

            module_obj = WasmModule(store, empty_wasm)
            exports_result = exports(module_obj)

            @test exports_result isa Dict{String,Any}
            @test isempty(exports_result)  # Empty module has no exports
        end

        @testset "Exports function with invalid module should fail" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            # Create a minimal valid WASM module (empty module)
            empty_wasm = UInt8[0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]

            module_obj = WasmModule(store, empty_wasm)
            module_obj.ptr = C_NULL  # Make module invalid

            @test_throws WasmtimeError exports(module_obj)
        end

        @testset "Imports function with valid module" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            # Create a minimal valid WASM module (empty module)
            empty_wasm = UInt8[0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]

            module_obj = WasmModule(store, empty_wasm)
            imports_result = imports(module_obj)

            @test imports_result isa Dict{String,Any}
            @test isempty(imports_result)  # Empty module has no imports
        end

        @testset "Imports function with invalid module should fail" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            # Create a minimal valid WASM module (empty module)
            empty_wasm = UInt8[0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]

            module_obj = WasmModule(store, empty_wasm)
            module_obj.ptr = C_NULL  # Make module invalid

            @test_throws WasmtimeError imports(module_obj)
        end
    end

    @testset "Module Resource Management" begin
        @testset "Module validity checks" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            # Create a minimal valid WASM module (empty module)
            empty_wasm = UInt8[0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]

            module_obj = WasmModule(store, empty_wasm)

            @test isvalid(module_obj) == true
            @test module_obj.ptr != C_NULL
        end

        @testset "Module becomes invalid after ptr is nullified" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            # Create a minimal valid WASM module (empty module)
            empty_wasm = UInt8[0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]

            module_obj = WasmModule(store, empty_wasm)
            module_obj.ptr = C_NULL

            @test isvalid(module_obj) == false
        end

        @testset "Module finalizer behavior" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            # Create a minimal valid WASM module (empty module)
            empty_wasm = UInt8[0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]

            module_obj = WasmModule(store, empty_wasm)
            original_ptr = module_obj.ptr

            # Trigger finalizer manually to simulate garbage collection
            finalize(module_obj)

            # After finalization, ptr should be cleaned up
            @test module_obj.ptr == C_NULL
            @test !isvalid(module_obj)
        end
    end

    @testset "Module Edge Cases and Error Handling" begin
        @testset "Multiple module creation with same engine" begin
            engine = WasmEngine()
            store = WasmStore(engine)

            # Create a minimal valid WASM module (empty module)
            empty_wasm = UInt8[0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]

            module1 = WasmModule(store, empty_wasm)
            module2 = WasmModule(store, empty_wasm)

            @test module1.ptr != module2.ptr  # Different module instances
            @test isvalid(module1)
            @test isvalid(module2)
        end

        @testset "Module operations on consumed engine should work" begin
            # Engine remains valid for module creation even after use
            engine = WasmEngine()
            store = WasmStore(engine)

            # Create a minimal valid WASM module (empty module)
            empty_wasm = UInt8[0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]

            # Create first module
            module1 = WasmModule(store, empty_wasm)
            @test isvalid(module1)

            # Engine should still be usable for creating another module
            module2 = WasmModule(store, empty_wasm)
            @test isvalid(module2)
        end
    end

    # @testset "Module WAT to WASM Conversion Placeholder" begin
    #     @testset "wat_to_wasm function throws not implemented error" begin
    #         wat_content = "(module)"

    #         @test_throws WasmtimeError WasmtimeRuntime.wat_to_wasm(wat_content)
    #     end

    #     @testset "wat_to_wasm error message verification" begin
    #         wat_content = "(module)"

    #         try
    #             WasmtimeRuntime.wat_to_wasm(wat_content)
    #             @test false  # Should not reach here
    #         catch e
    #             @test e isa WasmtimeError
    #             @test occursin("not yet implemented", e.message)
    #         end
    #     end
    # end

    @testset "Module Integration with Engine Types" begin
        @testset "Module works with default engine" begin
            engine = WasmEngine()
            store = WasmStore(engine)  # Default engine

            # Create a minimal valid WASM module (empty module)
            empty_wasm = UInt8[0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]

            module_obj = WasmModule(store, empty_wasm)
            @test isvalid(module_obj)

        end

        # DEPENDS_ON: Config, Engine and debug_info! functions
        @testset "Module works with configured engine" begin
            config = WasmConfig()
            debug_info!(config, true)
            engine = WasmEngine(config)
            store = WasmStore(engine)

            # Create a minimal valid WASM module (empty module)
            empty_wasm = UInt8[0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]

            module_obj = WasmModule(store, empty_wasm)
            @test isvalid(module_obj)
        end
    end
end
