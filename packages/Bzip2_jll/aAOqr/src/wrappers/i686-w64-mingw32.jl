# Autogenerated wrapper script for Bzip2_jll for i686-w64-mingw32
export libbzip2

JLLWrappers.@generate_wrapper_header("Bzip2")
JLLWrappers.@declare_library_product(libbzip2, "libbz2-1.dll")
function __init__()
    JLLWrappers.@generate_init_header()
    JLLWrappers.@init_library_product(
        libbzip2,
        "bin/libbz2-1.dll",
        RTLD_LAZY | RTLD_DEEPBIND,
    )

    JLLWrappers.@generate_init_footer()
end  # __init__()