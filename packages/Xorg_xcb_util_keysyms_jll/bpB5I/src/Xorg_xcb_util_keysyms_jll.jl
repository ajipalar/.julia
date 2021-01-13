# Use baremodule to shave off a few KB from the serialized `.ji` file
baremodule Xorg_xcb_util_keysyms_jll
using Base
using Base: UUID
import JLLWrappers

JLLWrappers.@generate_main_file_header("Xorg_xcb_util_keysyms")
JLLWrappers.@generate_main_file("Xorg_xcb_util_keysyms", UUID("975044d2-76e6-5fbe-bf08-97ce7c6574c7"))
end  # module Xorg_xcb_util_keysyms_jll
