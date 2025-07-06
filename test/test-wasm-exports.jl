using Test
using WasmtimeRuntime
using WasmtimeRuntime.LibWasmtime

@testset "WebAssembly Exports" begin
    # Test data setup
    engine = WasmEngine()
    store = WasmStore(engine)

    # Create test types for exports


    func_type = WasmFuncType([Int32, Int32], [Int32])
    global_type = WasmGlobalType(WasmValType(Int32), false)  # immutable i32
    memory_type = WasmMemoryType(WasmLimits(1, 10))  # min=1, max=10 pages
    table_type = WasmTableType(WasmLimits(1, 5))


    @testset "WasmModuleExport Creation" begin
        @testset "Function Export" begin
            func_export = WasmModuleExport("add", func_type)

            @test isvalid(func_export)
            @test name(func_export) == "add"
            @test exporttype(func_export) == WasmFunc
            @test func_export isa WasmModuleExport{WasmFunc}

            # Test display
            str_repr = string(func_export)
            @test contains(str_repr, "WasmModuleExport")
            @test contains(str_repr, "add")
        end

        @testset "Global Export" begin
            global_export = WasmModuleExport("counter", global_type)

            @test isvalid(global_export)
            @test name(global_export) == "counter"
            @test exporttype(global_export) == WasmGlobal
            @test global_export isa WasmModuleExport{WasmGlobal}
        end

        @testset "Memory Export" begin

            memory_export = WasmModuleExport("memory", memory_type)

            @test isvalid(memory_export)
            @test name(memory_export) == "memory"
            @test exporttype(memory_export) == WasmMemory
            @test memory_export isa WasmModuleExport{WasmMemory}
        end

        @testset "Table Export" begin

            table_export = WasmModuleExport("table", table_type)

            @test isvalid(table_export)
            @test name(table_export) == "table"
            @test exporttype(table_export) == WasmTable
            @test table_export isa WasmModuleExport{WasmTable}
        end
    end

    # @testset "WasmModuleExport Error Handling" begin
    #     # @testset "Invalid Names" begin
    #     #     @test_throws ArgumentError WasmModuleExport("", func_type)
    #     # end

    #     @testset "Invalid Types" begin
    #         # Test with invalid type objects would require creating invalid types
    #         # This depends on the implementation of isvalid for type objects
    #     end

    #     @testset "Null Pointer Construction" begin
    #         @test_throws ArgumentError WasmModuleExport(
    #             Ptr{LibWasmtime.wasm_exporttype_t}(C_NULL),
    #         )
    #     end
    # end

    @testset "WasmInstanceExport with Real Module" begin
        # Create a simple WebAssembly module with exports
        wasm_bytes = wat2wasm("""
        (module
          (func (export "add") (param i32 i32) (result i32)
            local.get 0
            local.get 1
            i32.add)
          (table (export "table") 1 5 funcref)
          (memory (export "memory") 1 10)
          (global (export "counter") (mut i32) (i32.const 42))
          (table (export "table2") 1 6 funcref)
          (global (export "counter2") (mut i32) (i32.const 43))
          (global (export "counter3") (mut i32) (i32.const 44))
          (global (export "counter4") (mut i32) (i32.const 45))
          (global (export "counter5") (mut i32) (i32.const 46))
        )
        """)

        module_ = WasmModule(store, wasm_bytes)
        instance = WasmInstance(store, module_)

        @testset "Instance Export Access" begin
            # Test accessing exports through instance
            exports_dict = exports(instance)

            @test haskey(exports_dict, :add)
            @test haskey(exports_dict, :counter)
            @test haskey(exports_dict, :memory)
            @test haskey(exports_dict, :table)

            # Test individual exports
            add_export = exports_dict[:add]
            @test name(add_export) == "add"
            @test add_export isa WasmInstanceExport{WasmFunc}

            counter_export = exports_dict[:counter]
            @test name(counter_export) == "counter"
            @test counter_export isa WasmInstanceExport{WasmGlobal}

            memory_export = exports_dict[:memory]
            @test name(memory_export) == "memory"
            @test memory_export isa WasmInstanceExport{WasmMemory}

            table_export = exports_dict[:table]
            @test name(table_export) == "table"
            @test table_export isa WasmInstanceExport{WasmTable}
        end

        @testset "Export Functionality" begin
            exports_dict = exports(instance)

            # Test function export
            add_export = exports_dict[:add]
            add_func = add_export.extern

            # Call the exported function
            result = add_func(Int32(5), Int32(3))
            # Broken until we return converted wasv_val_t to Julia values
            # @test result[1].value == 8

            # Test global export
            counter_export = exports_dict[:counter]
            counter_global = counter_export.extern

            # Read global value
            # Broken until we implement global value reading
            # value = get_global_value(counter_global)
            # @test value.value == 42
        end

        @testset "Display and Conversion" begin
            exports_dict = exports(instance)
            add_export = exports_dict[:add]

            # Test display
            str_repr = string(add_export)
            @test contains(str_repr, "WasmInstanceExport")
            @test contains(str_repr, "add")

            # Test validity
            @test isvalid(add_export)

            # Test unsafe conversion
            ptr = Base.unsafe_convert(Ptr{LibWasmtime.wasm_exporttype_t}, add_export)
            @test ptr != C_NULL
        end
    end

    @testset "WasmInstanceExport Creation from Extern" begin
        # Create a function to wrap in an export
        function simple_add_func(a::Int32, b::Int32)::Int32
            return a + b
        end

        func = WasmFunc(store, simple_add_func)

        extern = WasmExtern(func)
        instance_export = WasmInstanceExport("simple_add_func", extern)

        @test isvalid(instance_export)
        @test name(instance_export) == "simple_add_func"
        @test instance_export isa WasmInstanceExport{WasmFunc}
        @test instance_export.extern == extern
    end

    # @testset "WasmInstanceExport Error Handling" begin
    #     @testset "Invalid Extern" begin
    #         # Create an invalid extern (would need implementation-specific way)
    #         # This test depends on what makes an extern invalid
    #     end

    #     @testset "Null Pointer Construction" begin
    #         @test_throws ArgumentError WasmInstanceExport(Ptr{LibWasmtime.wasm_extern_t}(0))
    #     end
    # end

    @testset "Export Name Conversion" begin
        # Test string to wasm_name_t conversion
        name_str = "test_export"
        name_vec = Base.convert(LibWasmtime.wasm_name_t, name_str)

        @test name_vec isa WasmVec
        @test length(name_vec) == length(codeunits(name_str))
    end

    # @testset "Memory Management" begin
    #     # Test that finalizers are properly set up
    #     func_export = WasmModuleExport("test", func_type)
    #     @test isvalid(func_export)

    #     # Test that export remains valid after use
    #     test_name = name(func_export)
    #     @test test_name == "test"
    #     @test isvalid(func_export)
    # end

    @testset "Edge Cases" begin
        @testset "Long Export Names" begin
            long_name = "a"^1000
            long_export = WasmModuleExport(long_name, func_type)

            @test isvalid(long_export)
            @test name(long_export) == long_name
        end

        @testset "Unicode Export Names" begin
            unicode_name = "test_функция_関数"
            unicode_export = WasmModuleExport(unicode_name, func_type)

            @test isvalid(unicode_export)
            @test name(unicode_export) == unicode_name
        end

        @testset "Special Characters in Names" begin
            special_names = ["test-func", "test_func", "test.func", "test123"]

            for special_name in special_names
                special_export = WasmModuleExport(special_name, func_type)
                @test isvalid(special_export)
                @test name(special_export) == special_name
            end
        end
    end

    @testset "Performance Characteristics" begin
        @testset "Creation Performance" begin
            # Test that export creation is reasonably fast
            n_exports = 100

            time_taken = @elapsed begin
                test_exports =
                    [WasmModuleExport("export_$i", func_type) for i = 1:n_exports]
            end

            @test time_taken < 1.0  # Should create 100 exports in under 1 second
            @test all(isvalid.(test_exports))
        end

        @testset "Memory Usage" begin
            # Test that exports don't leak memory
            initial_memory = Base.gc_live_bytes()

            test_exports = [WasmModuleExport("export_$i", func_type) for i = 1:100]
            @test all(isvalid.(test_exports))

            # Clear references and force GC
            test_exports = nothing
            GC.gc()

            final_memory = Base.gc_live_bytes()

            # Memory should not have grown excessively
            memory_growth = final_memory - initial_memory
            @test memory_growth < 1_000_000  # Less than 1MB growth
        end
    end

    @testset "Integration with Module System" begin
        # Test integration with module loading and instantiation
        wasm_bytes = wat2wasm("""
        (module
          (func (export "double") (param i32) (result i32)
            local.get 0
            i32.const 2
            i32.mul)
          (func (export "triple") (param i32) (result i32)
            local.get 0
            i32.const 3
            i32.mul)
        )
        """)

        module_ = WasmModule(store, wasm_bytes)

        @testset "Module Export Discovery" begin
            # Test getting exports from module before instantiation
            module_exports = exports(module_)

            @test length(module_exports) >= 2

            export_names = [exp[1] for exp in module_exports]
            @test "double" in export_names
            @test "triple" in export_names
        end

        @testset "Instance Export Usage" begin
            instance = WasmInstance(store, module_)
            exports_dict = exports(instance)

            # Test using multiple exports
            double_export = exports_dict[:double]
            triple_export = exports_dict[:triple]

            double_func = double_export.extern
            triple_func = triple_export.extern

            # Test function calls
            result1 = double_func(Int32(5))
            # Broken until we return converted wasv_val_t to Julia values
            # @test result1[1].value == 10

            result2 = triple_func(Int32(5))
            # Broken until we return converted wasv_val_t to Julia values
            # @test result2[1].value == 15
        end
    end
end
