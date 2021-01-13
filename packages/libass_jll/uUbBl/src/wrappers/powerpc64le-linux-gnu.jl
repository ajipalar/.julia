# Autogenerated wrapper script for libass_jll for powerpc64le-linux-gnu
export libass

using FreeType2_jll
using FriBidi_jll
using Bzip2_jll
using Zlib_jll
JLLWrappers.@generate_wrapper_header("libass")
JLLWrappers.@declare_library_product(libass, "libass.so.9")
function __init__()
    JLLWrappers.@generate_init_header(FreeType2_jll, FriBidi_jll, Bzip2_jll, Zlib_jll)
    JLLWrappers.@init_library_product(
        libass,
        "lib/libass.so",
        RTLD_LAZY | RTLD_DEEPBIND,
    )

    JLLWrappers.@generate_init_footer()
end  # __init__()
