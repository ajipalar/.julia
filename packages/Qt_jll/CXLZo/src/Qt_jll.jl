# Use baremodule to shave off a few KB from the serialized `.ji` file
baremodule Qt_jll
using Base
using Base: UUID
import JLLWrappers

JLLWrappers.@generate_main_file_header("Qt")
JLLWrappers.@generate_main_file("Qt", UUID("ede63266-ebff-546c-83e0-1c6fb6d0efc8"))
end  # module Qt_jll
