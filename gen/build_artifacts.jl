import Downloads
using GitHub
using Pkg.Artifacts
using Base.BinaryPlatforms
using Tar
using SHA

const gh_auth = if haskey(ENV, "GITHUB_AUTH")
    GitHub.authenticate(ENV["GITHUB_AUTH"])
else
    @warn "GITHUB_AUTH not set, using anonymous authentication. This may lead to rate limiting."
    GitHub.AnonymousAuth()
end

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

function specific_release(repo, version; auth)
    findfirst(r -> r.tag_name == string(version), releases(repo; auth)[1])
end

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
    artifacts_toml = joinpath(@__DIR__, "Artifacts.toml")

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
