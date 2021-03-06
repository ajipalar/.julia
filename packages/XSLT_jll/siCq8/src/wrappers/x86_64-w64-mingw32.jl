# Autogenerated wrapper script for XSLT_jll for x86_64-w64-mingw32
export libexslt, libxslt

using Libgcrypt_jll
using XML2_jll
JLLWrappers.@generate_wrapper_header("XSLT")
JLLWrappers.@declare_library_product(libexslt, "libexslt-0.dll")
JLLWrappers.@declare_library_product(libxslt, "libxslt-1.dll")
function __init__()
    JLLWrappers.@generate_init_header(Libgcrypt_jll, XML2_jll)
    JLLWrappers.@init_library_product(
        libexslt,
        "bin\\libexslt-0.dll",
        RTLD_LAZY | RTLD_DEEPBIND,
    )

    JLLWrappers.@init_library_product(
        libxslt,
        "bin\\libxslt-1.dll",
        RTLD_LAZY | RTLD_DEEPBIND,
    )

    JLLWrappers.@generate_init_footer()
end  # __init__()
