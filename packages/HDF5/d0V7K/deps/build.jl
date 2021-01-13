using Libdl

const depsfile = joinpath(@__DIR__, "deps.jl")

const libpath = get(ENV, "JULIA_HDF5_LIBRARY_PATH", nothing)

if libpath === nothing
    # By default, use HDF5_jll
    open(depsfile, "w") do io
        print(io,
              """
              # This file is automatically generated
              # Do not edit
              using HDF5_jll
              check_deps() = nothing
              """
             )
    end
else
    libhdf5 = find_library("libhdf5", [libpath])
    libhdf5_hl = find_library("libhdf5_hl", [libpath])

    isempty(libhdf5) && error("libhdf5 not found in $libpath")
    isempty(libhdf5_hl) && error("libhdf5_hl not found in $libpath")

    libhdf5_size = filesize(dlpath(libhdf5))

    open(depsfile, "w") do io
        println(io,
                """
                # This file is automatically generated
                # Do not edit

                function check_deps()
                    if libhdf5_size != filesize(Libdl.dlpath(libhdf5))
                        error("HDF5 library has changed, re-run Pkg.build(\\\"HDF5\\\")")
                    end
                    if libversion < v"1.12"
                        error("HDF5.jl requires ≥ v1.12 of the HDF5 library.")
                    end
                end
                """
               )
        println(io, :(const libhdf5 = $libhdf5))
        println(io, :(const libhdf5_hl = $libhdf5_hl))
        println(io, :(const libhdf5_size = $libhdf5_size))
    end
end
