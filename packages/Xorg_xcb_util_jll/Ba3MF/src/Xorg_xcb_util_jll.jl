# Use baremodule to shave off a few KB from the serialized `.ji` file
baremodule Xorg_xcb_util_jll
using Base
using Base: UUID
import JLLWrappers

JLLWrappers.@generate_main_file_header("Xorg_xcb_util")
JLLWrappers.@generate_main_file("Xorg_xcb_util", UUID("2def613f-5ad1-5310-b15b-b15d46f528f5"))
end  # module Xorg_xcb_util_jll
