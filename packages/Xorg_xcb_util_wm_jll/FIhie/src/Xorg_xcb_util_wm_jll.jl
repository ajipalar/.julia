# Use baremodule to shave off a few KB from the serialized `.ji` file
baremodule Xorg_xcb_util_wm_jll
using Base
using Base: UUID
import JLLWrappers

JLLWrappers.@generate_main_file_header("Xorg_xcb_util_wm")
JLLWrappers.@generate_main_file("Xorg_xcb_util_wm", UUID("c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"))
end  # module Xorg_xcb_util_wm_jll
