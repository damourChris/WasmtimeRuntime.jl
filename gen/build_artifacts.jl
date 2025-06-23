"""
    Wasmtime Binary Artifact Builder

Automated system for downloading and managing Wasmtime binary releases across multiple platforms.

# Overview

This script provides a comprehensive artifact management system that:
- Fetches Wasmtime releases from GitHub automatically
- Downloads platform-specific binary packages
- Creates Julia artifact bindings for seamless integration
- Supports multiple architectures and operating systems

# Architecture

The artifact building process involves several key components:

## Release Management
- GitHub API integration for release discovery
- Version-specific or latest release selection
- Authentication handling for API rate limits

## Platform Support
- Cross-platform binary compatibility
- Architecture-specific package selection
- Operating system variant handling

## Artifact Integration
- Julia Artifacts.toml generation
- Binary hash verification
- Download caching and validation

# Supported Platforms

- **Linux x86_64**: GNU/Linux 64-bit Intel/AMD
- **Linux aarch64**: GNU/Linux 64-bit ARM
- **macOS x86_64**: Intel-based Mac systems
- **macOS aarch64**: Apple Silicon Mac systems
- **Windows x86_64**: Windows 64-bit Intel/AMD

# Dependencies

- `Downloads`: HTTP(S) download functionality
- `GitHub.jl`: GitHub API integration
- `Pkg.Artifacts`: Julia artifact system
- `Base.BinaryPlatforms`: Platform detection and specification
- `Tar`: Archive extraction utilities
- `SHA`: Cryptographic hash verification

# Environment Variables

- `GITHUB_AUTH`: GitHub personal access token (recommended to avoid rate limits)
- `WASMTIME_RELEASE_VERSION`: Specific version to download (optional, defaults to latest)

# Examples

```julia
# Download latest release for all platforms
include("build_artifacts.jl")

# Download specific version
ENV["WASMTIME_RELEASE_VERSION"] = "v24.0.0"
include("build_artifacts.jl")

# Use with authentication to avoid rate limits
ENV["GITHUB_AUTH"] = "your_github_token"
include("build_artifacts.jl")
```

# See Also

- [`generator.jl`](@ref): Uses artifacts created by this script
- [`get_wasmtime_include_path`](@ref): Accesses artifacts for header discovery
- [Julia Artifacts Documentation](https://pkgdocs.julialang.org/v1/artifacts/)
"""

import Downloads
using GitHub
using Pkg.Artifacts
using Base.BinaryPlatforms
using Tar
using SHA

"""
    GitHub Authentication Configuration

Sets up GitHub API authentication using environment variables.

Uses `GITHUB_AUTH` environment variable if available, otherwise falls back to
anonymous authentication with rate limiting warnings.
"""
const gh_auth = if haskey(ENV, "GITHUB_AUTH")
    GitHub.authenticate(ENV["GITHUB_AUTH"])
else
    @warn "GITHUB_AUTH not set, using anonymous authentication. This may lead to rate limiting."
    GitHub.AnonymousAuth()
end

"""
    version(release::Release) -> VersionNumber

Extract and parse version number from a GitHub release tag.

# Returns
- `VersionNumber`: Parsed version, or v"0.0.0" if parsing fails
"""
version(release::Release) =
    try
        VersionNumber(release.tag_name)
    catch
        v"0.0.0"
    end

latest_release(repo; auth) =
    reduce(releases(repo; auth)[1]) do releaseA, releaseB
        version(releaseA) > version(releaseB) ? releaseA : releaseB
    end

# Find all releases for a given repository
function specific_release(repo, version; auth)
    findfirst(r -> r.tag_name == string(version), releases(repo; auth)[1])
end

"""
    make_artifacts(dir; release_version=nothing) -> Nothing

Download and create artifacts for Wasmtime binaries across all supported platforms.

# Description

This is the main function that orchestrates the complete artifact creation process.
It handles release selection, platform-specific downloads, archive extraction,
and artifact binding generation.

# Arguments

- `dir::String`: Temporary directory for download operations
- `release_version`: Specific version to download, or `nothing` for latest

# Supported Platforms

The function creates artifacts for:
- `aarch64-linux-gnu`: ARM64 Linux
- `x86_64-linux-gnu`: Intel/AMD 64-bit Linux
- `x86_64-apple-darwin`: Intel Mac
- `aarch64-apple-darwin`: Apple Silicon Mac
- `x86_64-w64-mingw32`: Windows 64-bit

# Examples

```julia
# Create artifacts for latest release
make_artifacts(mktempdir())

# Create artifacts for specific version
make_artifacts(mktempdir(); release_version = v"24.0.0")

# Use with environment variable control
ENV["WASMTIME_RELEASE_VERSION"] = "v23.0.1"
make_artifacts(mktempdir(); release_version =
    get(ENV, "WASMTIME_RELEASE_VERSION", nothing))
```

# Asset Naming Convention

Wasmtime releases follow the pattern:
`wasmtime-v<version>-<platform>-c-api.tar.xz`

Platform mappings:
- `x86_64-linux` → `x86_64-linux-c-api.tar.xz`
- `aarch64-linux` → `aarch64-linux-c-api.tar.xz`
- `x86_64-macos` → `x86_64-macos-c-api.tar.xz`
- `aarch64-macos` → `aarch64-macos-c-api.tar.xz`
- `x86_64-windows` → `x86_64-windows-c-api.tar.xz`

# Output

Creates or updates `../Artifacts.toml` with `libwasmtime` artifact definitions
for all supported platforms, including download URLs and SHA256 hashes.

# See Also

- [`get_wasmtime_include_path`](@ref): Uses artifacts created by this function
- [Julia Artifacts Guide](https://pkgdocs.julialang.org/v1/artifacts/)
"""
function make_artifacts(dir; release_version = nothing)
    if release_version !== nothing
        # Find specific release by version
        all_releases = releases("bytecodealliance/wasmtime"; auth = gh_auth)[1]
        release = findfirst(r -> r.tag_name == string(release_version), all_releases)
        if release === nothing
            error("Release version $release_version not found")
        end
        release = all_releases[release]
        release_version = VersionNumber(release.tag_name)
        @info "Using specified release version: $release_version"
    else
        # Use latest release
        release = latest_release("bytecodealliance/wasmtime"; auth = gh_auth)
        release_version = VersionNumber(release.tag_name)
        @info "Using latest release version: $release_version"
    end

    platforms = [
        Platform("aarch64", "linux"; libc = "glibc"),
        Platform("x86_64", "linux"; libc = "glibc"),
        Platform("x86_64", "macos"),
        Platform("aarch64", "macos"),
        Platform("x86_64", "windows"),
    ]

    tripletnolibc(platform) = replace(triplet(platform), "-gnu" => "")
    function wasmtime_asset_name(platform)
        replace(
            "wasmtime-v$release_version-$(tripletnolibc(platform))-c-api.tar.xz",
            "apple-darwin" => "macos",
        )
    end

    asset_names = wasmtime_asset_name.(platforms)
    assets = filter(asset -> asset["name"] ∈ asset_names, release.assets)
    artifacts_toml = joinpath(@__DIR__, "..", "Artifacts.toml")

    for (platform, asset) in zip(platforms, assets)
        @info "Downloading $(asset["browser_download_url"]) for $platform"
        archive_location = joinpath(dir, asset["name"])
        download_url = asset["browser_download_url"]
        Downloads.download(
            download_url,
            archive_location;
            progress = (t, n) -> print("$(floor(100*n/t))%\r"),
        )
        println()

        artifact_hash = create_artifact() do artifact_dir
            run(`tar -xvf $archive_location -C $artifact_dir`)
        end

        download_hash = open(archive_location, "r") do f
            bytes2hex(sha256(f))
        end
        bind_artifact!(
            artifacts_toml,
            "libwasmtime",
            artifact_hash;
            platform,
            force = true,
            download_info = [(download_url, download_hash)],
        )
        @info "done $platform"
    end
end

make_artifacts(mktempdir(), release_version = get(ENV, "WASMTIME_RELEASE_VERSION", nothing))
