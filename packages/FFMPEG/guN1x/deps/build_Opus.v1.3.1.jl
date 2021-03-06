using BinaryProvider # requires BinaryProvider 0.3.0 or later

# Parse some basic command-line arguments
const verbose = "--verbose" in ARGS
const prefix = Prefix(get([a for a in ARGS if a != "--verbose"], 1, joinpath(@__DIR__, "usr")))
products = [
    LibraryProduct(prefix, ["libopus"], :libopus),
]

# Download binaries from hosted location
bin_prefix = "https://github.com/JuliaBinaryWrappers/Opus_jll.jl/releases/download/Opus-v1.3.1+0"

# Listing of files generated by BinaryBuilder:
download_info = Dict(
    Linux(:aarch64, libc=:glibc) => ("$bin_prefix/Opus.v1.3.1.aarch64-linux-gnu.tar.gz", "8a1cf8a24c3473effc84fb42d479dc1b9b6a6b690cd14eb4ca25af08b3a050fd"),
    Linux(:aarch64, libc=:musl) => ("$bin_prefix/Opus.v1.3.1.aarch64-linux-musl.tar.gz", "c073a5d9f08ca85b5bb63d529c072e23dda4d2db88d99894ef215509e2d6e488"),
    Linux(:armv7l, libc=:glibc, call_abi=:eabihf) => ("$bin_prefix/Opus.v1.3.1.arm-linux-gnueabihf.tar.gz", "a5c8835dc9e6890219c6c6b61af66ce91769032597d85f6d87982749549ffd17"),
    Linux(:armv7l, libc=:musl, call_abi=:eabihf) => ("$bin_prefix/Opus.v1.3.1.arm-linux-musleabihf.tar.gz", "da393b32dbcfe261a34dd972d59cc1a3b2dd5eb4f77b5999c75044691c732c19"),
    Linux(:i686, libc=:glibc) => ("$bin_prefix/Opus.v1.3.1.i686-linux-gnu.tar.gz", "0ac71058e4e32345af6faa732bc9bc8f90adf2084e48afe82f100d683de93e32"),
    Linux(:i686, libc=:musl) => ("$bin_prefix/Opus.v1.3.1.i686-linux-musl.tar.gz", "3d38f4408a1509dd6b3466a42ca27c009b56dde74fa164fc865c338584821ee8"),
    Windows(:i686) => ("$bin_prefix/Opus.v1.3.1.i686-w64-mingw32.tar.gz", "af9ed56fe36e0c40f5d23d3a71985d97dfc20d962a57e1d521fd13a1cbf293ce"),
    Linux(:powerpc64le, libc=:glibc) => ("$bin_prefix/Opus.v1.3.1.powerpc64le-linux-gnu.tar.gz", "0ec6b93cd73f7f0d8c81a7df756bc40b72391499c919ebe68ba3f9a868be9565"),
    MacOS(:x86_64) => ("$bin_prefix/Opus.v1.3.1.x86_64-apple-darwin14.tar.gz", "641d5d4733490325657b2a44d28499a23d8f45b6d4cfbd40c1362f822a43d7c4"),
    Linux(:x86_64, libc=:glibc) => ("$bin_prefix/Opus.v1.3.1.x86_64-linux-gnu.tar.gz", "9b00d2274892da7b3816a13b70b27bb9ef1fcf4703bcb1470f2f4a30d4c80853"),
    Linux(:x86_64, libc=:musl) => ("$bin_prefix/Opus.v1.3.1.x86_64-linux-musl.tar.gz", "cdc5c4fcc6800cededb33aced7460b3dc5f56eeb7f98c05007448aff39853a19"),
    FreeBSD(:x86_64) => ("$bin_prefix/Opus.v1.3.1.x86_64-unknown-freebsd11.1.tar.gz", "9f05a0a0c67901241b61f6d7d0c8e7db77f82b601ddaa9e72a7eeef28a4433c0"),
    Windows(:x86_64) => ("$bin_prefix/Opus.v1.3.1.x86_64-w64-mingw32.tar.gz", "fd239496fa79d0f4c208e98cd130384a5a4c6a76a3b6aa260efc793075bae508"),
)

# Install unsatisfied or updated dependencies:
unsatisfied = any(!satisfied(p; verbose=verbose) for p in products)
dl_info = choose_download(download_info, platform_key_abi())
if dl_info === nothing && unsatisfied
    # If we don't have a compatible .tar.gz to download, complain.
    # Alternatively, you could attempt to install from a separate provider,
    # build from source or something even more ambitious here.
    error("Your platform (\"$(Sys.MACHINE)\", parsed as \"$(triplet(platform_key_abi()))\") is not supported by this package!")
end

# If we have a download, and we are unsatisfied (or the version we're
# trying to install is not itself installed) then load it up!
if unsatisfied || !isinstalled(dl_info...; prefix=prefix)
    # Download and install binaries
    install(dl_info...; prefix=prefix, force=true, verbose=verbose)
end

# Write out a deps.jl file that will contain mappings for our products
write_deps_file(joinpath(@__DIR__, "deps.jl"), products, verbose=verbose)
