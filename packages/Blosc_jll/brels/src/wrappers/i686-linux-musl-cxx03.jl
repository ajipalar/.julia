# Autogenerated wrapper script for Blosc_jll for i686-linux-musl-cxx03
export libblosc

using Zlib_jll
using Zstd_jll
using Lz4_jll
## Global variables
PATH = ""
LIBPATH = ""
LIBPATH_env = "LD_LIBRARY_PATH"

# Relative path to `libblosc`
const libblosc_splitpath = ["lib", "libblosc.so"]

# This will be filled out by __init__() for all products, as it must be done at runtime
libblosc_path = ""

# libblosc-specific global declaration
# This will be filled out by __init__()
libblosc_handle = C_NULL

# This must be `const` so that we can use it with `ccall()`
const libblosc = "libblosc.so.1"


"""
Open all libraries
"""
function __init__()
    global artifact_dir = abspath(artifact"Blosc")

    # Initialize PATH and LIBPATH environment variable listings
    global PATH_list, LIBPATH_list
    # We first need to add to LIBPATH_list the libraries provided by Julia
    append!(LIBPATH_list, [joinpath(Sys.BINDIR, Base.LIBDIR, "julia"), joinpath(Sys.BINDIR, Base.LIBDIR)])
    # From the list of our dependencies, generate a tuple of all the PATH and LIBPATH lists,
    # then append them to our own.
    foreach(p -> append!(PATH_list, p), (Zlib_jll.PATH_list, Zstd_jll.PATH_list, Lz4_jll.PATH_list,))
    foreach(p -> append!(LIBPATH_list, p), (Zlib_jll.LIBPATH_list, Zstd_jll.LIBPATH_list, Lz4_jll.LIBPATH_list,))

    global libblosc_path = normpath(joinpath(artifact_dir, libblosc_splitpath...))

    # Manually `dlopen()` this right now so that future invocations
    # of `ccall` with its `SONAME` will find this path immediately.
    global libblosc_handle = dlopen(libblosc_path)
    push!(LIBPATH_list, dirname(libblosc_path))

    # Filter out duplicate and empty entries in our PATH and LIBPATH entries
    filter!(!isempty, unique!(PATH_list))
    filter!(!isempty, unique!(LIBPATH_list))
    global PATH = join(PATH_list, ':')
    global LIBPATH = join(LIBPATH_list, ':')

    # Add each element of LIBPATH to our DL_LOAD_PATH (necessary on platforms
    # that don't honor our "already opened" trick)
    #for lp in LIBPATH_list
    #    push!(DL_LOAD_PATH, lp)
    #end
end  # __init__()

