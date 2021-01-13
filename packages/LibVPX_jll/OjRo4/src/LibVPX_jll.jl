# Use baremodule to shave off a few KB from the serialized `.ji` file
baremodule LibVPX_jll
using Base
using Base: UUID
import JLLWrappers

JLLWrappers.@generate_main_file_header("LibVPX")
JLLWrappers.@generate_main_file("LibVPX", UUID("dd192d2f-8180-539f-9fb4-cc70b1dcf69a"))
end  # module LibVPX_jll
