using ForwardDiff

println("Testing Partials...")
t = @elapsed include("PartialsTest.jl")
println("done (took $t seconds).")

println("Testing Dual...")
t = @elapsed include("DualTest.jl")
println("done (took $t seconds).")

println("Testing derivative functionality...")
t = @elapsed include("DerivativeTest.jl")
println("done (took $t seconds).")

println("Testing gradient functionality...")
t = @elapsed include("GradientTest.jl")
println("done (took $t seconds).")

println("Testing jacobian functionality...")
t = @elapsed include("JacobianTest.jl")
println("done (took $t seconds).")

println("Testing hessian functionality...")
t = @elapsed include("HessianTest.jl")
println("done (took $t seconds).")

println("Testing perturbation confusion functionality...")
t = @elapsed include("ConfusionTest.jl")
println("done (took $t seconds).")

println("Testing miscellaneous functionality...")
t = @elapsed include("MiscTest.jl")
println("done (took $t seconds).")

# These tests need to be run in a process where bounds checking is not explicitly enabled
# (like they are with Pkg.test)
println("Testing SIMD vectorization...")
project = Base.active_project()
simdfile = joinpath(@__DIR__, "SIMDTest.jl")
t = @elapsed run(`$(Base.julia_cmd()) --check-bounds=no --code-coverage=none -O2 --project=$project $simdfile`)
println("done (took $t seconds).")