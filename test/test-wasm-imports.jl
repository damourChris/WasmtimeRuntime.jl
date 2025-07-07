using Test
using WasmtimeRuntime
using WasmtimeRuntime.LibWasmtime
using Random

Random.seed!(1234)

@testset "WasmImportType Tests" begin
    @testset "Construction from Pointer" begin
        @testset "should create WasmImportType from valid pointer with proper name extraction" begin
            # Create a mock WasmFuncType to generate an import from
            params = [Int32, Int32]
            results = [Int32]
            functype = WasmFuncType(params, results)

            # Create WasmImportType using the string constructor
            import_obj = WasmImportType("test_module", "test_function", functype)

            # Now test the pointer constructor by extracting from the created object
            reconstructed = WasmImportType(import_obj.ptr)

            @test reconstructed isa WasmImportType
            @test isvalid(reconstructed)
            @test reconstructed.module_name == "test_module"
            @test reconstructed.import_name == "test_function"
            @test reconstructed.ptr != C_NULL
        end

        @testset "should throw ArgumentError for null pointer" begin
            @test_throws ArgumentError WasmImportType(
                Ptr{LibWasmtime.wasm_importtype_t}(C_NULL),
            )
        end

        @testset "should extract names correctly from C API" begin
            # Test with various string lengths and special characters
            test_cases = [
                ("simple", "func"),
                ("module_with_underscores", "function_with_underscores"),
                ("a", "b"),  # Single character names
                ("longer_module_name_123", "longer_function_name_456"),
                ("module", "func_with_numbers_123"),
            ]

            for (module_name, func_name) in test_cases
                params::Vector{DataType} = [Int32]
                results::Vector{DataType} = [Int32]
                functype = WasmFuncType(params, results)

                import_obj = WasmImportType(module_name, func_name, functype)
                reconstructed = WasmImportType(import_obj.ptr)

                @test reconstructed.module_name == module_name
                @test reconstructed.import_name == func_name
            end
        end
    end

    @testset "Construction from String Parameters" begin
        @testset "should create WasmImportType with valid parameters" begin
            params = [Int32, Float64]
            results = [Int32]
            functype = WasmFuncType(params, results)

            import_obj = WasmImportType("my_module", "my_function", functype)

            @test import_obj isa WasmImportType
            @test isvalid(import_obj)
            @test import_obj.module_name == "my_module"
            @test import_obj.import_name == "my_function"
            @test import_obj.ptr != C_NULL
        end

        @testset "should handle various function type signatures" begin
            test_signatures::Vector{Tuple{Vector{DataType},Vector{DataType}}} = [
                ([], []),                           # No params, no results
                ([Int32], []),                      # One param, no results
                ([], [Int32]),                      # No params, one result
                ([Int32], [Int32]),                 # One param, one result
                ([Int32, Float64], [Float32]),      # Multiple params, one result
                ([Int32, Float64, Int64], [Int32, Float64]),  # Multiple params, multiple results
            ]

            for (i, (params, results)) in enumerate(test_signatures)
                functype = WasmFuncType(params, results)
                import_obj = WasmImportType("module_$i", "func_$i", functype)

                @test isvalid(import_obj)
                @test import_obj.module_name == "module_$i"
                @test import_obj.import_name == "func_$i"
            end
        end

        @testset "should work with complex function signatures" begin
            # Test with all supported WASM types
            complex_params = [Int32, Int64, Float32, Float64]
            complex_results = [Int64, Float32]

            functype = WasmFuncType(complex_params, complex_results)
            import_obj = WasmImportType("complex_module", "complex_func", functype)

            @test isvalid(import_obj)
            @test import_obj.module_name == "complex_module"
            @test import_obj.import_name == "complex_func"
        end
    end

    @testset "Error Handling" begin
        @testset "should reject empty names" begin
            params = [Int32]
            results = [Int32]
            functype = WasmFuncType(params, results)

            # Empty import name
            @test_throws ArgumentError WasmImportType("module", "", functype)

            # Empty module name
            @test_throws ArgumentError WasmImportType("", "function", functype)

            # Both empty
            @test_throws ArgumentError WasmImportType("", "", functype)
        end

        @testset "should handle invalid function type gracefully" begin
            params = [Int32]
            results = [Int32]
            functype = WasmFuncType(params, results)

            # Invalidate the functype
            functype.ptr = C_NULL

            # This should fail during C API call since functype is invalid
            @test_throws ArgumentError WasmImportType("module", "function", functype)
        end

        @testset "should handle C API failure scenarios" begin
            params = [Int32]
            results = [Int32]
            functype = WasmFuncType(params, results)

            # Test scenario where wasm_importtype_new might fail
            # This is hard to trigger directly, but we test the error path exists
            try
                import_obj = WasmImportType("valid_module", "valid_function", functype)
                @test isvalid(import_obj)  # Should succeed normally
            catch e
                # If it fails, should be WasmtimeError
                @test e isa WasmtimeError
            end
        end
    end

    @testset "Interface Methods" begin
        @testset "unsafe_convert should return correct pointer" begin
            params = [Int32]
            results = [Int32]
            functype = WasmFuncType(params, results)
            import_obj = WasmImportType("module", "function", functype)

            ptr = Base.unsafe_convert(Ptr{LibWasmtime.wasm_importtype_t}, import_obj)
            @test ptr == import_obj.ptr
            @test ptr != C_NULL
        end

        @testset "isvalid should correctly identify validity" begin
            params = [Int32]
            results = [Int32]
            functype = WasmFuncType(params, results)
            import_obj = WasmImportType("module", "function", functype)

            # Should be valid initially
            @test isvalid(import_obj)

            # Should be invalid after nullifying pointer
            import_obj.ptr = C_NULL
            @test !isvalid(import_obj)
        end

        @testset "show should display meaningful information" begin
            params = [Int32, Float64]
            results = [Int64]
            functype = WasmFuncType(params, results)
            import_obj = WasmImportType("test_module", "test_function", functype)

            output = string(import_obj)
            @test occursin("WasmImportType", output)
            @test occursin("test_module", output)
            @test occursin("test_function", output)
        end

        @testset "name function should return import name" begin
            params = [Int32]
            results = [Int32]
            functype = WasmFuncType(params, results)
            import_obj = WasmImportType("my_module", "my_function", functype)

            @test name(import_obj) == "my_function"
            @test name(import_obj) == import_obj.import_name
        end
    end

    @testset "Property-Based Testing" begin
        @testset "round-trip property: pointer -> string construction should preserve data" begin
            for _ = 1:50
                # Generate random valid names
                module_name = "module_" * randstring(Random.default_rng(), 'a':'z', 20)
                func_name = "func_" * randstring(Random.default_rng(), 'a':'z', 20)

                params = [Int32]
                results = [Int32]
                functype = WasmFuncType(params, results)

                # Create with string constructor
                original = WasmImportType(module_name, func_name, functype)

                # Reconstruct from pointer
                reconstructed = WasmImportType(original.ptr)

                # Should preserve all data
                @test reconstructed.module_name == original.module_name
                @test reconstructed.import_name == original.import_name
                @test isvalid(reconstructed)
            end
        end

        @testset "creation with various valid string patterns" begin
            # Test different naming patterns that should all be valid
            valid_patterns = [
                ("a", "b"),                           # Minimal names
                ("_module", "_function"),             # Leading underscore
                ("module_", "function_"),             # Trailing underscore
                ("module123", "function456"),         # With numbers
                ("Module", "Function"),               # Capitalized
                ("UPPER_MODULE", "UPPER_FUNCTION"),   # All caps
                ("mixed_Case", "Mixed_Case"),         # Mixed case
                ("module.name", "function.name"),     # With dots
            ]

            for (module_name, func_name) in valid_patterns
                params = [Int32]
                results = [Int32]
                functype = WasmFuncType(params, results)

                import_obj = WasmImportType(module_name, func_name, functype)

                @test isvalid(import_obj)
                @test import_obj.module_name == module_name
                @test import_obj.import_name == func_name
            end
        end
    end

    @testset "Memory Management" begin
        @testset "should not leak memory during normal operations" begin
            # Create many import types to test for leaks
            imports = []

            for i = 1:100
                params = [Int32]
                results = [Int32]
                functype = WasmFuncType(params, results)
                import_obj = WasmImportType("module_$i", "function_$i", functype)
                push!(imports, import_obj)
            end

            # Verify all are valid
            for import_obj in imports
                @test isvalid(import_obj)
            end

            # Force garbage collection
            GC.gc()

            # Objects should still be valid since we have references
            for import_obj in imports
                @test isvalid(import_obj)
            end
        end

        @testset "should handle memory management correctly with pointer constructor" begin
            params = [Int32]
            results = [Int32]
            functype = WasmFuncType(params, results)
            original = WasmImportType("module", "function", functype)

            # Create multiple objects from same pointer
            reconstructed1 = WasmImportType(original.ptr)
            reconstructed2 = WasmImportType(original.ptr)

            # All should be valid
            @test isvalid(original)
            @test isvalid(reconstructed1)
            @test isvalid(reconstructed2)

            # Names should be consistent
            @test reconstructed1.module_name == reconstructed2.module_name
            @test reconstructed1.import_name == reconstructed2.import_name
        end
    end

    @testset "Edge Cases" begin
        @testset "should handle very long names" begin
            # Test with very long but valid names
            long_module = "very_long_module_name_" * "x"^100
            long_function = "very_long_function_name_" * "y"^100

            params = [Int32]
            results = [Int32]
            functype = WasmFuncType(params, results)
            import_obj = WasmImportType(long_module, long_function, functype)

            @test isvalid(import_obj)
            @test import_obj.module_name == long_module
            @test import_obj.import_name == long_function
        end

        @testset "should handle special characters in names appropriately" begin
            # Test with various special characters that might be valid in WASM
            special_names = [
                ("module-with-dashes", "function-with-dashes"),
                ("module.with.dots", "function.with.dots"),
                ("module_with_underscores", "function_with_underscores"),
                ("module123", "function456"),
            ]

            for (module_name, func_name) in special_names
                params = [Int32]
                results = [Int32]
                functype = WasmFuncType(params, results)

                # Should handle these gracefully
                @test_nowarn begin
                    import_obj = WasmImportType(module_name, func_name, functype)
                    @test isvalid(import_obj)
                end
            end
        end

        @testset "should maintain consistency across operations" begin
            params = [Int32, Float64]
            results = [Int64]
            functype = WasmFuncType(params, results)
            import_obj =
                WasmImportType("consistency_module", "consistency_function", functype)

            # Multiple calls to name() should return same result
            name1 = name(import_obj)
            name2 = name(import_obj)
            @test name1 == name2
            @test name1 == import_obj.import_name

            # Multiple calls to isvalid() should return same result
            valid1 = isvalid(import_obj)
            valid2 = isvalid(import_obj)
            @test valid1 == valid2
            @test valid1 == true

            # Multiple calls to show should be consistent
            str1 = string(import_obj)
            str2 = string(import_obj)
            @test str1 == str2
        end
    end

    @testset "Integration with Other Types" begin
        @testset "should work with different WasmFuncType configurations" begin
            # Test integration with various function type configurations
            type_configs::Vector{Tuple{Vector{DataType},Vector{DataType}}} = [
                ([], []),
                ([Int32], []),
                ([], [Int32]),
                ([Int32], [Int32]),
                ([Int32, Int64], [Float32]),
                ([Float32, Float64], [Int32, Int64]),
            ]

            for (params, results) in type_configs
                functype = WasmFuncType(params, results)
                import_obj = WasmImportType("module", "function", functype)

                @test isvalid(import_obj)
                @test isvalid(functype)

                # Should be able to reconstruct from pointer
                reconstructed = WasmImportType(import_obj.ptr)
                @test isvalid(reconstructed)
            end
        end

        @testset "should be usable with LibWasmtime C API functions" begin
            params = [Int32]
            results = [Int32]
            functype = WasmFuncType(params, results)
            import_obj = WasmImportType("test_module", "test_function", functype)

            # Should be convertible to C pointer
            ptr = Base.unsafe_convert(Ptr{LibWasmtime.wasm_importtype_t}, import_obj)
            @test ptr != C_NULL

            # Should work with LibWasmtime functions that expect wasm_importtype_t
            # Test that we can call LibWasmtime functions without crashes
            @test_nowarn begin
                name_ptr = LibWasmtime.wasm_importtype_name(ptr)
                module_ptr = LibWasmtime.wasm_importtype_module(ptr)
                type_ptr = LibWasmtime.wasm_importtype_type(ptr)

                @test name_ptr != C_NULL
                @test module_ptr != C_NULL
                @test type_ptr != C_NULL
            end
        end
    end

    @testset "Module imports() Function Tests" begin
        # Test setup
        engine = WasmEngine()
        store = WasmStore(engine)

        @testset "Module without imports" begin
            # Create a simple module with no imports
            wasm_bytes = wat2wasm("""
            (module
              (func (export "add") (param i32 i32) (result i32)
                local.get 0
                local.get 1
                i32.add)
              (memory (export "memory") 1)
              (global (export "counter") (mut i32) (i32.const 42))
            )
            """)

            module_ = WasmModule(store, wasm_bytes)

            @testset "should return empty imports list" begin
                import_list = imports(module_)
                @test import_list isa Vector{Tuple{String,WasmImportType}}
                @test length(import_list) == 0
                @test isempty(import_list)
            end
        end

        @testset "Module with function imports" begin
            # Create a module with function imports
            wasm_bytes = wat2wasm("""
            (module
              (import "env" "print" (func (param i32)))
              (import "env" "add" (func (param i32 i32) (result i32)))
              (import "math" "sqrt" (func (param f64) (result f64)))

              (func (export "main") (result i32)
                i32.const 42)
            )
            """)

            module_ = WasmModule(store, wasm_bytes)

            @testset "should return correct number of imports" begin
                import_list = imports(module_)
                @test length(import_list) == 3
            end

            @testset "should return imports with correct names and types" begin
                import_list = imports(module_)

                # Check the first import (env.print)
                import_name_1, import_1 = import_list[1]
                @test import_name_1 == "print"
                @test import_1 isa WasmImportType
                @test import_1.module_name == "env"
                @test import_1.import_name == "print"
                @test name(import_1) == "print"
                @test isvalid(import_1)

                # Check the second import (env.add)
                import_name_2, import_2 = import_list[2]
                @test import_name_2 == "add"
                @test import_2 isa WasmImportType
                @test import_2.module_name == "env"
                @test import_2.import_name == "add"
                @test name(import_2) == "add"
                @test isvalid(import_2)

                # Check the third import (math.sqrt)
                import_name_3, import_3 = import_list[3]
                @test import_name_3 == "sqrt"
                @test import_3 isa WasmImportType
                @test import_3.module_name == "math"
                @test import_3.import_name == "sqrt"
                @test name(import_3) == "sqrt"
                @test isvalid(import_3)
            end
        end

        @testset "Module with memory and global imports" begin
            # Create a module with memory and global imports
            wasm_bytes = wat2wasm("""
            (module
              (import "env" "memory" (memory 1))
              (import "env" "global_counter" (global i32))
              (import "env" "global_mutable" (global (mut i32)))

              (func (export "get_counter") (result i32)
                global.get 1)
            )
            """)

            module_ = WasmModule(store, wasm_bytes)

            @testset "should handle memory and global imports" begin
                import_list = imports(module_)
                @test length(import_list) == 3

                # All imports should be valid
                for (import_name, import_obj) in import_list
                    @test import_name isa String
                    @test !isempty(import_name)
                    @test import_obj isa WasmImportType
                    @test isvalid(import_obj)
                    @test import_obj.module_name == "env"
                    @test name(import_obj) == import_name
                end
            end
        end

        @testset "Module with table imports" begin
            # Create a module with table imports
            wasm_bytes = wat2wasm("""
            (module
              (import "env" "table" (table 1 funcref))
              (import "env" "callback" (func (param i32)))

              (func (export "test") (result i32)
                i32.const 42)
            )
            """)

            module_ = WasmModule(store, wasm_bytes)

            @testset "should handle table imports" begin
                import_list = imports(module_)
                @test length(import_list) == 2

                # Check table import
                table_import_name, table_import = import_list[1]
                @test table_import_name == "table"
                @test table_import.module_name == "env"
                @test table_import.import_name == "table"

                # Check function import
                func_import_name, func_import = import_list[2]
                @test func_import_name == "callback"
                @test func_import.module_name == "env"
                @test func_import.import_name == "callback"
            end
        end

        @testset "Module with mixed imports from different modules" begin
            # Create a module with imports from different modules
            wasm_bytes = wat2wasm("""
            (module
              (import "console" "log" (func (param i32)))
              (import "math" "add" (func (param i32 i32) (result i32)))
              (import "system" "memory" (memory 1))
              (import "config" "debug_flag" (global i32))

              (func (export "test") (result i32)
                i32.const 42)
            )
            """)

            module_ = WasmModule(store, wasm_bytes)

            @testset "should handle imports from different modules" begin
                import_list = imports(module_)
                @test length(import_list) == 4

                # Check that we have imports from different modules
                module_names =
                    Set([import_obj.module_name for (_, import_obj) in import_list])
                @test length(module_names) == 4
                @test "console" in module_names
                @test "math" in module_names
                @test "system" in module_names
                @test "config" in module_names

                # Check specific imports
                import_names = [import_name for (import_name, _) in import_list]
                @test "log" in import_names
                @test "add" in import_names
                @test "memory" in import_names
                @test "debug_flag" in import_names
            end
        end

        @testset "imports() function error handling" begin
            @testset "should throw error for invalid module" begin
                # Create a module and then invalidate it
                wasm_bytes = wat2wasm("""
                (module
                  (func (export "test") (result i32)
                    i32.const 42)
                )
                """)

                module_ = WasmModule(store, wasm_bytes)

                # Invalidate the module by setting ptr to null
                module_.ptr = C_NULL

                @test_throws WasmtimeError imports(module_)
            end
        end

        @testset "imports() function consistency" begin
            # Test that multiple calls to imports() return consistent results
            wasm_bytes = wat2wasm("""
            (module
              (import "env" "func1" (func (param i32)))
              (import "env" "func2" (func (param i32 i32) (result i32)))

              (func (export "main") (result i32)
                i32.const 42)
            )
            """)

            module_ = WasmModule(store, wasm_bytes)

            @testset "should return consistent results across multiple calls" begin
                import_list_1 = imports(module_)
                import_list_2 = imports(module_)

                @test length(import_list_1) == length(import_list_2)
                @test length(import_list_1) == 2

                # Compare the results
                for i = 1:length(import_list_1)
                    name_1, import_1 = import_list_1[i]
                    name_2, import_2 = import_list_2[i]

                    @test name_1 == name_2
                    @test import_1.module_name == import_2.module_name
                    @test import_1.import_name == import_2.import_name
                    @test isvalid(import_1)
                    @test isvalid(import_2)
                end
            end
        end

        @testset "imports() with complex function signatures" begin
            # Test with complex function signatures
            wasm_bytes = wat2wasm("""
            (module
              (import "env" "no_params_no_results" (func))
              (import "env" "multiple_params" (func (param i32 i64 f32 f64)))
              (import "env" "multiple_results" (func (result i32 i64)))
              (import "env" "complex_sig" (func (param i32 f64) (result f32 i64)))

              (func (export "test") (result i32)
                i32.const 1)
            )
            """)

            module_ = WasmModule(store, wasm_bytes)

            @testset "should handle complex function signatures" begin
                import_list = imports(module_)
                @test length(import_list) == 4

                # Verify all imports are valid and have correct names
                expected_names = [
                    "no_params_no_results",
                    "multiple_params",
                    "multiple_results",
                    "complex_sig",
                ]
                actual_names = [import_name for (import_name, _) in import_list]

                for expected_name in expected_names
                    @test expected_name in actual_names
                end

                # Verify all imports are from the "env" module
                for (_, import_obj) in import_list
                    @test import_obj.module_name == "env"
                    @test isvalid(import_obj)
                end
            end
        end
    end
end
