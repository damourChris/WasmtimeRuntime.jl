using WasmtimeRuntime
using Documenter

DocMeta.setdocmeta!(
    WasmtimeRuntime,
    :DocTestSetup,
    :(using WasmtimeRuntime);
    recursive = true,
)

const page_rename = Dict("developer.md" => "Developer docs") # Without the numbers
const numbered_pages = [
    file for file in readdir(joinpath(@__DIR__, "src")) if
    file != "index.md" && splitext(file)[2] == ".md"
]

makedocs(;
    modules = [WasmtimeRuntime],
    authors = "Chris Damour <damourchris0@gmail.com>",
    repo = "https://github.com/damourChris/WasmtimeRuntime.jl/blob/{commit}{path}#{line}",
    sitename = "WasmtimeRuntime.jl",
    format = Documenter.HTML(;
        canonical = "https://damourChris.github.io/WasmtimeRuntime.jl",
    ),
    pages = ["index.md"; numbered_pages],
)

deploydocs(; push_preview = true, repo = "github.com/damourChris/WasmtimeRuntime.jl")
