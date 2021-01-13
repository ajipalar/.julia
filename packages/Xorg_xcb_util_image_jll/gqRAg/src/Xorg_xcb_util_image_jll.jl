# Use baremodule to shave off a few KB from the serialized `.ji` file
baremodule Xorg_xcb_util_image_jll
using Base
using Base: UUID
import JLLWrappers

JLLWrappers.@generate_main_file_header("Xorg_xcb_util_image")
JLLWrappers.@generate_main_file("Xorg_xcb_util_image", UUID("12413925-8142-5f55-bb0e-6d7ca50bb09b"))
end  # module Xorg_xcb_util_image_jll
