# Autogenerated wrapper script for XSLT_jll for i686-linux-musl
export libexslt, libxslt

using Libgcrypt_jll
using XML2_jll
JLLWrappers.@generate_wrapper_header("XSLT")
JLLWrappers.@declare_library_product(libexslt, "libexslt.so.0")
JLLWrappers.@declare_library_product(libxslt, "libxslt.so.1")
function __init__()
    JLLWrappers.@generate_init_header(Libgcrypt_jll, XML2_jll)
    JLLWrappers.@init_library_product(
        libexslt,
        "lib/libexslt.so",
        RTLD_LAZY | RTLD_DEEPBIND,
    )

    JLLWrappers.@init_library_product(
        libxslt,
        "lib/libxslt.so",
        RTLD_LAZY | RTLD_DEEPBIND,
    )

    JLLWrappers.@generate_init_footer()
end  # __init__()
