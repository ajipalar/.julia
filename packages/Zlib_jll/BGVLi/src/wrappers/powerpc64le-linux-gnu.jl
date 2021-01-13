# Autogenerated wrapper script for Zlib_jll for powerpc64le-linux-gnu
export libz

JLLWrappers.@generate_wrapper_header("Zlib")
JLLWrappers.@declare_library_product(libz, "libz.so.1")
function __init__()
    JLLWrappers.@generate_init_header()
    JLLWrappers.@init_library_product(
        libz,
        "lib/libz.so",
        RTLD_LAZY | RTLD_DEEPBIND,
    )

    JLLWrappers.@generate_init_footer()
end  # __init__()