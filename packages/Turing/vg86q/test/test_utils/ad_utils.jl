using Turing: gradient_logp_forward, gradient_logp_reverse
using Test

"""
    test_reverse_mode_ad(forward, f, ȳ, x...; rtol=1e-6, atol=1e-6)

Check that the reverse-mode sensitivities produced by an AD library are correct for `f`
at `x...`, given sensitivity `ȳ` w.r.t. `y = f(x...)` up to `rtol` and `atol`.
`forward` should be either `Tracker.forward` or `Zygote.pullback`.
"""
function test_reverse_mode_ad(forward, f, ȳ, x...; rtol=1e-6, atol=1e-6)

    # Perform a regular forwards-pass.
    y = f(x...)

    # Use tracker to compute reverse-mode sensitivities.
    y_tracker, back = forward(f, x...)
    x̄s_tracker = back(ȳ)

    # Use finite differencing to compute reverse-mode sensitivities.
    x̄s_fdm = FDM.j′vp(central_fdm(5, 1), f, ȳ, x...)

    # Check that forwards-pass produces the correct answer.
    @test isapprox(y, Tracker.data(y_tracker), atol=atol, rtol=rtol)

    # Check that reverse-mode sensitivities are correct.
    @test all(zip(x̄s_tracker, x̄s_fdm)) do (x̄_tracker, x̄_fdm)
        isapprox(Tracker.data(x̄_tracker), x̄_fdm; atol=atol, rtol=rtol)
    end
end

# See `test_reverse_mode_ad` for details.
function test_tracker_ad(f, ȳ, x...; rtol=1e-6, atol=1e-6)
    return test_reverse_mode_ad(Tracker.forward, f, ȳ, x...; rtol=rtol, atol=atol)
end

function test_model_ad(model, f, syms::Vector{Symbol})
    # Set up VI.
    vi = Turing.VarInfo(model)

    # Collect symbols.
    vnms = Vector(undef, length(syms))
    vnvals = Vector{Float64}()
    for i in 1:length(syms)
        s = syms[i]
        vnms[i] = getfield(vi.metadata, s).vns[1]

        vals = getval(vi, vnms[i])
        for i in eachindex(vals)
            push!(vnvals, vals[i])
        end
    end

    spl = SampleFromPrior()
    _, ∇E = gradient_logp_forward(vi[spl], vi, model)
    grad_Turing = sort(∇E)

    # Call ForwardDiff's AD
    grad_FWAD = sort(ForwardDiff.gradient(f, vec(vnvals)))

    # Compare result
    @test grad_Turing ≈ grad_FWAD atol=1e-9
end
