using BinaryProvider # requires BinaryProvider 0.3.0 or later

# Parse some basic command-line arguments
const verbose = "--verbose" in ARGS
const prefix = Prefix(get([a for a in ARGS if a != "--verbose"], 1, joinpath(@__DIR__, "usr")))
products = [
    LibraryProduct(prefix, ["libogg"], :libogg),
]

# Download binaries from hosted location
bin_prefix = "https://github.com/JuliaBinaryWrappers/Ogg_jll.jl/releases/download/Ogg-v1.3.3+0"

# Listing of files generated by BinaryBuilder:
download_info = Dict(
    Linux(:aarch64, libc=:glibc) => ("$bin_prefix/Ogg.v1.3.3.aarch64-linux-gnu.tar.gz", "5f29c47af530f94ba7dfe528c91311daf13a0562c8c044967d1375d182dc3fe6"),
    Linux(:aarch64, libc=:musl) => ("$bin_prefix/Ogg.v1.3.3.aarch64-linux-musl.tar.gz", "7667c2ff87094a7457c05abcc241098ec90b8a1ef802f67a7435b6ff6e1b5fde"),
    Linux(:armv7l, libc=:glibc, call_abi=:eabihf) => ("$bin_prefix/Ogg.v1.3.3.arm-linux-gnueabihf.tar.gz", "2bac147a8d8696571d64558b7fd53d7b65eb953037ef537f89e85e412f801f41"),
    Linux(:armv7l, libc=:musl, call_abi=:eabihf) => ("$bin_prefix/Ogg.v1.3.3.arm-linux-musleabihf.tar.gz", "b3b1f06fa7d834a98557149ad3d021606874f5f208c9c722cfa6984ecbb2a2da"),
    Linux(:i686, libc=:glibc) => ("$bin_prefix/Ogg.v1.3.3.i686-linux-gnu.tar.gz", "4ff7683d35598b5300b833547351dd11e03854f6d25a5dcea13ce51b010943e7"),
    Linux(:i686, libc=:musl) => ("$bin_prefix/Ogg.v1.3.3.i686-linux-musl.tar.gz", "a070eb3745b6f0972bd9032bb2e02898cb24a6b8a99c000eaf3754ab382fbf29"),
    Windows(:i686) => ("$bin_prefix/Ogg.v1.3.3.i686-w64-mingw32.tar.gz", "4ed6cac191586cffbfdb8d2a55a595c9791c615a8dbd4476bc87be02b3f74ace"),
    Linux(:powerpc64le, libc=:glibc) => ("$bin_prefix/Ogg.v1.3.3.powerpc64le-linux-gnu.tar.gz", "102fd9860583b77a865ed8bea3127c4bd74f5aef92ee449798a45c82d8e614eb"),
    MacOS(:x86_64) => ("$bin_prefix/Ogg.v1.3.3.x86_64-apple-darwin14.tar.gz", "fb95b15b0106e942028b77450bbf0329b2d8d58b591cf4c21246b7ad9bb448a2"),
    Linux(:x86_64, libc=:glibc) => ("$bin_prefix/Ogg.v1.3.3.x86_64-linux-gnu.tar.gz", "b28997d2e136be99972beea3419b08811e306d178d4351632ac6f09aec9209b1"),
    Linux(:x86_64, libc=:musl) => ("$bin_prefix/Ogg.v1.3.3.x86_64-linux-musl.tar.gz", "3029c105d4642fce7445101224ed195a53cfc962bb2a7b553e3e6f107990e099"),
    FreeBSD(:x86_64) => ("$bin_prefix/Ogg.v1.3.3.x86_64-unknown-freebsd11.1.tar.gz", "88810b7d55d8a924414ee0572f1b00b8ea3573cd70b6fa1c5b1966d69df6e679"),
    Windows(:x86_64) => ("$bin_prefix/Ogg.v1.3.3.x86_64-w64-mingw32.tar.gz", "16ee0fce0cda9b5452d325a021059c14bb25d0a1578eefa601ae137e2056f39b"),
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