# Use baremodule to shave off a few KB from the serialized `.ji` file
baremodule Xorg_xcb_util_renderutil_jll
using Base
using Base: UUID
import JLLWrappers

JLLWrappers.@generate_main_file_header("Xorg_xcb_util_renderutil")
JLLWrappers.@generate_main_file("Xorg_xcb_util_renderutil", UUID("0d47668e-0667-5a69-a72c-f761630bfb7e"))
end  # module Xorg_xcb_util_renderutil_jll
