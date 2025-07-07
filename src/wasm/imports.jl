mutable struct WasmImportType
    ptr::Ptr{LibWasmtime.wasm_importtype_t}
    module_name::String
    import_name::String
end

function WasmImportType(ptr::Ptr{LibWasmtime.wasm_importtype_t})
    if ptr == C_NULL
        throw(ArgumentError("Cannot create WasmModuleImportType from null pointer"))
    end

    name_vec_ptr = LibWasmtime.wasm_importtype_name(ptr)
    name_vec = unsafe_load(name_vec_ptr)
    import_name = unsafe_string(name_vec.data, name_vec.size)

    module_name_vec_ptr = LibWasmtime.wasm_importtype_module(ptr)
    module_name_vec = unsafe_load(module_name_vec_ptr)
    module_name = unsafe_string(module_name_vec.data, module_name_vec.size)

    return WasmImportType(ptr, module_name, import_name)
end

function WasmImportType(module_name::String, import_name::String, functype::WasmFuncType)
    if import_name == "" || module_name == ""
        throw(ArgumentError("Name and module name cannot be empty"))
    end

    isvalid(functype) || throw(ArgumentError("Function type must be valid"))

    # Copy to own it
    functype_copy = LibWasmtime.wasm_functype_copy(functype)

    extern_type = LibWasmtime.wasm_functype_as_externtype(functype_copy)

    ptr = LibWasmtime.wasm_importtype_new(
        WasmByteVec(codeunits(module_name) |> collect),
        WasmByteVec(codeunits(import_name) |> collect),
        extern_type,
    )

    if ptr == C_NULL
        throw(WasmtimeError("Failed to create WasmModuleImportType"))
    end

    return WasmImportType(ptr, module_name, import_name)
end


Base.unsafe_convert(
    ::Type{Ptr{LibWasmtime.wasm_importtype_t}},
    importtype::WasmImportType,
) = importtype.ptr
Base.isvalid(importtype::WasmImportType) = importtype.ptr != C_NULL
Base.show(io::IO, importtype::WasmImportType) = print(
    io,
    "WasmImportType(module_name=$(importtype.module_name), import_name=$(importtype.import_name))",
)


name(importtype::WasmImportType) = importtype.import_name
