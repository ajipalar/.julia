# Autogenerated wrapper script for LZO_jll for powerpc64le-linux-gnu
export liblzo2

JLLWrappers.@generate_wrapper_header("LZO")
JLLWrappers.@declare_library_product(liblzo2, "liblzo2.so.2")
function __init__()
    JLLWrappers.@generate_init_header()
    JLLWrappers.@init_library_product(
        liblzo2,
        "lib/liblzo2.so",
        RTLD_LAZY | RTLD_DEEPBIND,
    )

    JLLWrappers.@generate_init_footer()
end  # __init__()
