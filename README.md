# WasmtimeRuntime.jl

**A Julia wrapper for the Wasmtime WebAssembly runtime, providing high-performance WebAssembly execution with type-safe function calling.**

> **⚠️ Active Development Notice**
> This project is currently in active development. APIs may change, and features are being actively added and refined. We welcome feedback and contributions!

<!-- [![Stable Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://damourChris.github.io/WasmtimeRuntime.jl/stable) -->
[![Development documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://damourChris.github.io/WasmtimeRuntime.jl/dev)
[![Test workflow status](https://github.com/damourChris/WasmtimeRuntime.jl/actions/workflows/Test.yml/badge.svg?branch=main)](https://github.com/damourChris/WasmtimeRuntime.jl/actions/workflows/Test.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/damourChris/WasmtimeRuntime.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/damourChris/WasmtimeRuntime.jl)
[![Lint workflow Status](https://github.com/damourChris/WasmtimeRuntime.jl/actions/workflows/Lint.yml/badge.svg?branch=main)](https://github.com/damourChris/WasmtimeRuntime.jl/actions/workflows/Lint.yml?query=branch%3Amain)
[![Docs workflow Status](https://github.com/damourChris/WasmtimeRuntime.jl/actions/workflows/Docs.yml/badge.svg?branch=main)](https://github.com/damourChris/WasmtimeRuntime.jl/actions/workflows/Docs.yml?query=branch%3Amain)
[![Build Status](https://api.cirrus-ci.com/github/damourChris/WasmtimeRuntime.jl.svg)](https://cirrus-ci.com/github/damourChris/WasmtimeRuntime.jl)
[![DOI](https://zenodo.org/badge/DOI/FIXME)](https://doi.org/FIXME)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](CODE_OF_CONDUCT.md)
[![All Contributors](https://img.shields.io/github/all-contributors/damourChris/WasmtimeRuntime.jl?labelColor=5e1ec7&color=c0ffee&style=flat-square)](#contributors)
[![BestieTemplate](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/JuliaBesties/BestieTemplate.jl/main/docs/src/assets/badge.json)](https://github.com/JuliaBesties/BestieTemplate.jl)

## Quick Start

### Installation

```julia
using Pkg
Pkg.add("WasmtimeRuntime")
```

> !!! The package is not yet registered, so you need to add it directly from the repository:

```julia
using Pkg
Pkg.add(url="https://github.com/damourChris/wasmtimeruntime.jl")
```

### Basic Usage

```julia
using WasmtimeRuntime

# Create engine and store
engine = Engine()
store = Store(engine)

# Load a WebAssembly module from bytes
wasm_bytes = wat2wasm("""
    (module
        (func $add (param $a i32) (param $b i32) (result i32)
            local.get $a
            local.get $b
            i32.add)
        (export "add" (func $add)))
""")
module_obj = WasmModule(engine, wasm_bytes)
instance = WasmInstance(store, module_obj)

# Call exported functions with automatic type conversion
instance_exports = exports(instance)
add_func = instance_exports[:add]
result = add_func(5, 3)
println("Result: $result")  # Output: Result: 8
```

## Features

- [ ] **Type-safe function calling**: Automatic conversion between Julia and WebAssembly types
- [ ] **Full Wasmtime API coverage**: Access to engines, stores, modules, instances, and more
- [X] **WAT support**: Convert WebAssembly Text format to bytecode
- [ ] **Memory management**: Safe resource handling with automatic cleanup
- [ ] **Performance optimized**: Built on the high-performance Wasmtime runtime
- [ ] **Julia native**: Idiomatic Julia interface with proper error handling

## Core API

### Engine and Store Management

```julia
# Create configuration with optimization settings
config = WasmConfig()
set_optimization_level!(config, Speed)
engine = Engine(config)

# Create store for module instances
store = Store(engine)
```

### Module Loading and Instantiation

```julia
# From file
module_obj = WasmModule(engine, "module.wasm")

# From bytes
wasm_bytes = read("module.wasm")
module_obj = WasmModule(engine, wasm_bytes)

# Create instance
instance = WasmInstance(store, module_obj)
```

### Function Calling

```julia
# Get exported function
func = get_export(instance, "function_name")

# Call with automatic type conversion
result = func(args...)

# Type-safe calling (planned feature)
typed_func = TypedFunc{Tuple{Int32, Float32}, Int64}(func)
result = typed_func(store, Int32(42), Float32(3.14))
```

### Memory and Global Access

```julia
# Access exported memory
instance_exports = exports(instance)
memory = instance_exports[:memory]
data = read_memory(memory, store, offset, length)

# Access global variables
global_var = get_export(instance, "global_var")
value = get_global(global_var, store)
```

## Requirements

- **Julia**: 1.10 or later
- **System**: Linux, macOS, or Windows (64-bit)
- **Dependencies**: Automatically handled via Julia's artifact system

!!! Note that Windows is currently not supported due to Artifacts.jl limitations. See #10

## Development Setup

### Prerequisites

- Julia 1.10+
- Git

### Local Development

```bash
# Clone the repository
git clone https://github.com/damourChris/WasmtimeRuntime.jl.git
cd WasmtimeRuntime.jl

# Set up the development environment
julia --project=. -e "using Pkg; Pkg.instantiate()"

# Run tests
julia --project=. test/runtests.jl
# Or use the test task
julia --project=. -e "using Pkg; Pkg.test()"

# Run individual tests
julia --project=. -e "using Pkg; Pkg.test(WasmtimeRuntime; test_args=["test-wasm-exports.jl"])"

```

### Running Examples

```bash
# Run the function calling demo
julia --project=. examples/function_calling_demo.jl

# Run the vector operations demo
julia --project=. examples/vec_demo.jl
```

## Documentation

- **[Development Documentation](https://damourChris.github.io/WasmtimeRuntime.jl/dev)**: Complete API reference and guides
- **[Getting Started Guide](docs/src/01-getting-started.md)**: Step-by-step tutorial
- **[Core Concepts](docs/src/02-core-concepts.md)**: Understanding the WebAssembly runtime model
- **[API Reference](docs/src/94-api-reference.md)**: Detailed function and type documentation

## Current Status

### Implemented Features ✅

- Basic engine and store management
- Module loading from files and bytes
- Instance creation and management
- Function calling with basic type conversion
- Memory and global variable access
- WAT to WASM conversion
- Resource management and cleanup

### In Progress 🚧

- Type-safe function calling with `TypedFunc`
- Enhanced error handling and trap management
- Performance optimizations
- Complete test coverage

### Planned Features 📋

- Advanced configuration options
- Streaming instantiation
- Multi-threading support
- WASI integration
- Custom host function definitions

## Troubleshooting

### Common Issues

#### "Module not found" errors

```julia
# Ensure the path is correct and the file exists
@assert isfile("path/to/module.wasm")
module_obj = WasmModule(engine, "path/to/module.wasm")
```

#### Type conversion errors

```julia
# Use explicit type conversion for function arguments
result = wasm_func(Int32(arg1), Float32(arg2))
```

## Contributing

We welcome contributions! Please see our [Contributing Guide](docs/src/90-contributing.md) for details on:

- Setting up the development environment
- Running tests and benchmarks
- Code style and conventions
- Submitting pull requests

### Quick Contribution Checklist

- [ ] Fork the repository
- [ ] Create a feature branch
- [ ] Add tests for new functionality
- [ ] Ensure all tests pass
- [ ] Update documentation if needed
- [ ] Submit a pull request

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/damourChris/WasmtimeRuntime.jl/issues)
- **Discussions**: [GitHub Discussions](https://github.com/damourChris/WasmtimeRuntime.jl/discussions)
- **Documentation**: [Development Docs](https://damourChris.github.io/WasmtimeRuntime.jl/dev)

## How to Cite

If you use WasmtimeRuntime.jl in your work, please cite using the reference given in [CITATION.cff](https://github.com/damourChris/WasmtimeRuntime.jl/blob/main/CITATION.cff).

---

---

### Contributors

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->
