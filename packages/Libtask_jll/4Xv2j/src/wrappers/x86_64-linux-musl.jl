# Autogenerated wrapper script for Libtask_jll for x86_64-linux-musl
export libtask_julia

JLLWrappers.@generate_wrapper_header("Libtask")
JLLWrappers.@declare_library_product(libtask_julia, "libtask_julia.so")
function __init__()
    JLLWrappers.@generate_init_header()
    JLLWrappers.@init_library_product(
        libtask_julia,
        "lib/libtask_julia.so",
        RTLD_LAZY | RTLD_DEEPBIND,
    )

    JLLWrappers.@generate_init_footer()
end  # __init__()
