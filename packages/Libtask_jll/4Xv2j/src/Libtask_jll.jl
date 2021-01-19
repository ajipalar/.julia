# Use baremodule to shave off a few KB from the serialized `.ji` file
baremodule Libtask_jll
using Base
using Base: UUID
import JLLWrappers

JLLWrappers.@generate_main_file_header("Libtask")
JLLWrappers.@generate_main_file("Libtask", UUID("3ae2931a-708c-5973-9c38-ccf7496fb450"))
end  # module Libtask_jll
