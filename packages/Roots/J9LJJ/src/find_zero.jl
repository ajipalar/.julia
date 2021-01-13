## Framework for setting up an iterative problem for finding a zero
## TODO
## * a graphic of trace when verbose=true?


#
# In McNamee & Pan (DOI:10.1016/j.camwa.2011.11.015 there are a number of
# results on efficiencies of a solution, (1/d) log_10(q)
# Those implemented here are:
# quadratic cut (Muller) .265 (in a42)
# Newton() newton = .1505   or 1/2log(2)
# Order1() secant method .20 (1/1 * log(1.6)
# FalsePostion(12) Anderson-Bjork [.226, .233]
# FalsePostion(3) (King?) .264
# A42() 0.191 but convergence guaranteed
# Order8() 8th order 4 steps: .225 (log10(8)/4
# Order16() 16th order 5 steps .240
# Order5(): 5th order, 4 steps. 0.1747



# A zero is found by specifying:
# the method to use <: AbstractUnivariateZeroMethod
# the function(s) <: CallableFunction
# the initial state through a value for x either x, [a,b], or (a,b) <: AbstractUnivariateZeroState
# the options (e.g., tolerances) <: UnivariateZeroOptions

# The minimal amount needed to add a method, is to define a Method and an update_state method.

### Methods
abstract type AbstractUnivariateZeroMethod end
abstract type AbstractBracketing <: AbstractUnivariateZeroMethod end
abstract type AbstractNonBracketing <: AbstractUnivariateZeroMethod end
abstract type AbstractSecant <: AbstractNonBracketing end


### States
abstract type  AbstractUnivariateZeroState end
mutable struct UnivariateZeroState{T,S} <: AbstractUnivariateZeroState where {T,S}
    xn1::T
    xn0::T
    m::Vector{T}
    fxn1::S
    fxn0::S
    fm::Vector{S}
    steps::Int
    fnevals::Int
    stopped::Bool             # stopped, butmay not have converged
    x_converged::Bool         # converged via |x_n - x_{n-1}| < ϵ
    f_converged::Bool         # converged via |f(x_n)| < ϵ
    convergence_failed::Bool
    message::String
end

incfn(o::AbstractUnivariateZeroState, k=1)    = o.fnevals += k
incsteps(o::AbstractUnivariateZeroState, k=1) = o.steps += k

# initialize state for most methods
function init_state(method::Any, fs, x)

    x1 = float(x)
    fx1 = fs(x1); fnevals = 1
    T, S = eltype(x1), eltype(fx1)

    state = UnivariateZeroState(x1, oneunit(x1) * (0*x1)/(0*x1), T[],
                                fx1, oneunit(fx1) * (0*fx1)/(0*fx1), S[],
                                0, fnevals,
                                false, false, false, false,
                                "")
    state
end

## This function is used to reset the state to an initial value
## As initializing a state is somewhat costly, this can be useful when many
## function calls would be used.
## An example usage, might be:
# M = Order1()
# state = Roots.init_state(M, f1, 0.9)
# options = Roots.init_options(M, state)
# out = zeros(Float64, n)
# for (i,x0) in enumerate(linspace(0.9, 1.0, n))
#    Roots.init_state!(state, M, f1, x0)
#    out[i] = find_zero(M, f1, options, state)
# end
# init_state has a method call variant
function init_state!(state::UnivariateZeroState{T,S}, x1::T, x0::T, m::Vector{T}, y1::S, y0::S, fm::Vector{S}) where {T,S}
    state.xn1 = x1
    state.xn0 = x0
    empty!(state.m); append!(state.m,  m)
    state.m = m
    state.fxn1 = y1
    state.fxn0 = y0
    empty!(state.fm); append!(state.fm,fm)
    state.steps = 0
    state.fnevals = 2
    state.stopped = false
    state.x_converged = false
    state.f_converged = false
    state.convergence_failed = false
    state.message = ""

    nothing
end

function init_state!(state::UnivariateZeroState{T,S}, ::AbstractUnivariateZeroMethod, fs, x) where {T, S}
    x1 = float(x)
    fx1 = fs(x1)

    init_state!(state, x1, oneunit(x1) * (0*x1)/(0*x1), T[],
                fx1, oneunit(fx1) * (0*fx1)/(0*fx1), S[])
end


function Base.copy(state::UnivariateZeroState{T,S}) where {T, S}
    UnivariateZeroState(state.xn1, state.xn0, copy(state.m),
                        state.fxn1, state.fxn0, copy(state.fm),
                        state.steps, state.fnevals,
                        state.stopped, state.x_converged,
                        state.f_converged, state.convergence_failed,
                        state.message)
end

function Base.copy!(dst::UnivariateZeroState{T,S}, src::UnivariateZeroState{T,S}) where {T,S}
    dst.xn1 = src.xn1
    dst.xn0 = src.xn0
    empty!(dst.m); append!(dst.m, src.m)
    dst.fxn1 = src.fxn1
    dst.fxn0 = src.fxn0
    empty!(dst.fm); append!(dst.fm, src.fm)
    dst.steps = src.steps
    dst.fnevals = src.fnevals
    dst.stopped = src.stopped
    dst.x_converged = src.x_converged
    dst.f_converged = src.f_converged
    dst.convergence_failed = src.convergence_failed
    dst.message = src.message
    nothing
end

### Options
mutable struct UnivariateZeroOptions{Q,R,S,T}
    xabstol::Q
    xreltol::R
    abstol::S
    reltol::T
    maxevals::Int
    maxfnevals::Int
    strict::Bool
end

"""
    default_tolerances(Method, [T], [S])

The default tolerances for most methods are `xatol=eps(T)`,
`xrtol=eps(T)`, `atol=4eps(S)`, and `rtol=4eps(S)`, with the proper
units (absolute tolerances have the units of `x` and `f(x)`; relative
tolerances are unitless). For `Complex{T}` values, `T` is used.

The number of iterations is limited by `maxevals=40`, the number of
function evaluations is not capped, due to `maxfnevals=typemax(Int)`,
and `strict=false`.

"""
default_tolerances(M::AbstractUnivariateZeroMethod) = default_tolerances(M, Float64, Float64)
function default_tolerances(::AbstractUnivariateZeroMethod, ::Type{T}, ::Type{S}) where {T, S}
    xatol = eps(real(T)) * oneunit(real(T))
    xrtol = eps(real(T))  # unitless
    atol = 4.0 * eps(real(float(S))) * oneunit(real(S))
    rtol = 4.0 * eps(real(float(S))) * one(real(S))
    maxevals = 40
    maxfnevals = typemax(Int)
    strict = false
    (xatol, xrtol, atol, rtol, maxevals, maxfnevals, strict)
end

function init_options(M::AbstractUnivariateZeroMethod,
                      state::UnivariateZeroState{T,S};
                      kwargs...
                      ) where {T, S}

    d = kwargs

    defs = default_tolerances(M, T, S)
    options = UnivariateZeroOptions(get(d, :xatol, get(d, :xabstol, defs[1])),
                                    get(d, :xrtol, get(d, :xreltol, defs[2])),
                                    get(d, :atol,  get(d, :abstol,  defs[3])),
                                    get(d, :rtol,  get(d, :reltol,  defs[4])),
                                    get(d, :maxevals,   get(d, :maxsteps, defs[5])),
                                    get(d, :maxfnevals, defs[6]),
                                    get(d, :strict,     defs[7]))
    options
end

# reset options to default values
function init_options!(options::UnivariateZeroOptions{Q,R,S,T}, M::AbstractUnivariateZeroMethod) where {Q, R, S, T}

    defs = default_tolerances(M, Q, S)
    options.xabstol = defs[1]
    options.xreltol = defs[2]
    options.abstol = defs[3]
    options.reltol = defs[4]
    options.maxevals = defs[5]
    options.maxfnevals = defs[6]
    options.strict = defs[7]

    nothing
end


## Tracks (for logging actual steps)
## when no logging this should get optimized out to avoid a branch
abstract type AbstractTracks end
struct NullTracks <: AbstractTracks end
# api
log_step(s::NullTracks, M, x, init=false) = nothing

mutable struct Tracks{T,S} <: AbstractTracks
xs::Vector{T}
fs::Vector{S}
end
Tracks(s::UnivariateZeroState{T,S}) where {T, S} = Tracks(T[],S[])

log_step(s::Tracks, M::Any, o, ::Any) = log_step(s, M, o)

function log_step(s::Tracks, M::Any, o)
    push!(s.xs, o.xn1)
    push!(s.fs, o.fxn1)
    nothing
end
function show_tracks(s::Tracks, M::AbstractUnivariateZeroMethod)
    for (i, (xi, fxi)) in enumerate(zip(s.xs, s.fs))
        println(@sprintf("%s = % 18.16f,\t %s = % 18.16f", "x_$(i-1)", float(xi), "fx_$(i-1)", float(fxi)))
    end
    println("")
end



### Functions
abstract type CallableFunction end

struct FnWrapper <: CallableFunction
   f
end

struct DerivativeFree{F} <: CallableFunction
    f::F
end

struct FirstDerivative{F,FP} <: CallableFunction
    f::F
    fp::FP
end

struct SecondDerivative{F,FP,FPP} <: CallableFunction
    f::F
    fp::FP
    fpp::FPP
end

(F::FnWrapper)(x::Number) = first(F.f(x))
(F::DerivativeFree)(x::Number) = first(F.f(x))
(F::FirstDerivative)(x::Number) = first(F.f(x))
(F::SecondDerivative)(x::Number) = first(F.f(x))

## Return f, f/f'
function fΔx(F::DerivativeFree, x)
    F.f(x)
end

function fΔx(F::Union{FirstDerivative, SecondDerivative},x)
    fx, fpx = F.f(x), F.fp(x)
    fx, fx/fpx
end
function fΔx(F, x)
    F(x)
end

# return f, f/f', f'/f'' (types T, S, S)
fΔxΔΔx(F::DerivativeFree, x) = F.f(x)
fΔxΔΔx(F::FirstDerivative, x) = error("no second derivative defined")
function fΔxΔΔx(F::SecondDerivative, x)
    fx, fp, fpp = F.f(x), F.fp(x), F.fpp(x)
    (fx, fx/fp, fp/fpp)
end
fΔxΔΔx(F, x) = F(x)


# allows override for function, if desired
# the default for this specializes on the function passed
# in. When specialization occurs there is overhead due to compilation
# costs which can be amortized over subsequent calls to `find_zero`.
# However, if a function is only used once, then using `fzero` will be
# faster. (The difference is clear between `@time` and `@btime` to measure
# execution time)
#                 first call    subsequent calls  default for
# specialize       slower         faster          find_zero
# no specialize    faster         slower          fzero
#
callable_function(fs::Any) = _callable_function(fs)
function _callable_function(fs)
    if isa(fs, Tuple)
        length(fs)==1 && return DerivativeFree(fs[1])
        length(fs)==2 && return FirstDerivative(fs[1],fs[2])
        return SecondDerivative(fs[1],fs[2],fs[3])
    end
    DerivativeFree(fs)
end


## Assess convergence
@inline function _is_f_approx_0(fa, a, atol, rtol, relaxed::Any)
    aa, afa = abs(a), abs(fa)
    tol = max(_unitless(atol), _unitless(aa) * rtol)
    tol = abs(_unitless(tol))^(1/3)  # relax test
    afa < tol * oneunit(afa)
end
@inline function _is_f_approx_0(fa, a, atol, rtol)
    aa, afa = abs(a), abs(fa)
    tol = max(_unitless(atol), _unitless(aa) * rtol)
    afa < tol * oneunit(afa)
end

"""
   Roots.assess_convergence(method, state, options)

Assess if algorithm has converged.

If alogrithm hasn't converged returns `false`.

If algorithm has stopped or converged, return `true` and sets one of `state.stopped`, `state.x_converged`,  `state.f_converged`, or `state.convergence_failed`; as well, a message may be set.

* `state.x_converged = true` if `abs(xn1 - xn0) < max(xatol, max(abs(xn1), abs(xn0)) * xrtol)`

* `state.f_converged = true` if  `|f(xn1)| < max(atol, |xn1|*rtol)`

* `state.convergence_failed = true` if xn1 or fxn1 is `NaN` or an infinity

* `state.stopped = true` if the number of steps exceed `maxevals` or the number of function calls exceeds `maxfnevals`.

In `find_zero`, stopped values (and x_converged) are checked for convergence with a relaxed tolerance.


"""
function assess_convergence(method::Any, state::UnivariateZeroState{T,S}, options) where {T,S}

    xn0, xn1 = state.xn0, state.xn1
    fxn1 = state.fxn1

    if (state.x_converged || state.f_converged || state.stopped)
        return true
    end

    if isnan(xn1) || isnan(fxn1)
        state.convergence_failed = true
        state.message *= "NaN produced by algorithm. "
        return true
    end

    if isinf(xn1) || isinf(fxn1)
        state.convergence_failed = true
        state.message *= "Inf produced by algorithm. "
        return true
    end

    # f(xstar) ≈ xstar * f'(xstar)*eps(), so we pass in lambda
    if _is_f_approx_0(fxn1, xn1, options.abstol, options.reltol)
        state.f_converged = true
        return true
    end

    # stop when xn1 ~ xn.
    # in find_zeros there is a check that f could be a zero with a relaxed tolerance
    if abs(xn1 - xn0) < max(options.xabstol, max(abs(xn1), abs(xn0)) * options.xreltol)
        state.message *= "x_n ≈ x_{n-1}. "
        state.x_converged = true
        return true
    end


    if state.steps > options.maxevals
        state.stopped = true
        state.message *= "Too many steps taken. "
        return true
    end

    if state.fnevals > options.maxfnevals
        state.stopped = true
        state.message *= "Too many function evaluations taken. "
        return true
    end

    return false
end

function show_trace(method, N, state, tracks)
    converged = state.x_converged || state.f_converged
    println("Results of univariate zero finding:\n")
    if converged
        println("* Converged to: $(state.xn1)")
        if N == nothing || isa(method, AbstractBracketing)
            println("* Algorithm: $(method)")
        else
            println("* Algorithm: $(method), with possible bracketing with $N")
        end
        println("* iterations: $(state.steps)")
        println("* function evaluations: $(state.fnevals)")
        state.x_converged && println("* stopped as x_n ≈ x_{n-1} using atol=xatol, rtol=xrtol")
        state.f_converged && state.message == "" && println("* stopped as |f(x_n)| ≤ max(δ, max(1,|x|)⋅ϵ) using δ = atol, ϵ = rtol")
        state.message != "" && println("* Note: $(state.message)")
    else
        println("* Convergence failed: $(state.message)")
        println("* Algorithm $(method)")
    end
    println("")
    println("Trace:")
    show_tracks(tracks, method)
end


"""

    find_zero(fs, x0, method; kwargs...)

Interface to one of several methods for find zeros of a univariate function.

# Initial starting value

For most methods, `x0` is a scalar value indicating the initial value
in the iterative procedure. (Secant methods can have a tuple specify
their initial values.) Values must be a subtype of `Number` and have
methods for `float`, `real`, and `oneunit` defined.

For bracketing intervals, `x0` is specified as a tuple or a vector. A bracketing interval, (a,b), is one where f(a) and f(b) have different signs.

# Specifying a method

A method is specified to indicate which algorithm to employ:

* There are methods for bisection where a bracket is specified: `Bisection`, `Roots.A42`, `FalsePosition`

* There are several derivative-free methods: cf. `Order0`, `Order1` (secant method), `Order2` (Steffensen), `Order5`, `Order8`, and `Order16`, where the number indicates the order of the convergence. Methods `Roots.Order1B` and `Roots.Order2B` implement methods useful when the desired zero has a multiplicity.

* There are some classical methods where derivatives are required: `Roots.Newton`, `Roots.Halley`, `Roots.Schroder`. (The are not exported.)

For more detail, see the help page for each method (e.g., `?Order1`).

If no method is specified, the default method depends on `x0`:

* If `x0` is a scalar, the default is the slower, but more robust `Order0` method.

* If `x0` is a tuple or vector indicating a *bracketing* interval, the `Bisection` method is used. (The exact algorithm depends on the number type, the tolerances, and `verbose`.)

# Specifying the function

The function(s) are passed as the first argument.

For the few methods that use a derivative (`Newton`, `Halley`, `Shroder`, and
optionally `Order5`) a tuple of functions is used.

# Optional arguments (tolerances, limit evaluations, tracing)

* `xatol` - absolute tolerance for `x` values. Passed to `isapprox(x_n, x_{n-1})`
* `xrtol` - relative tolerance for `x` values. Passed to `isapprox(x_n, x_{n-1})`
* `atol`  - absolute tolerance for `f(x)` values.
* `rtol`  - relative tolerance for `f(x)` values.
* `maxevals`   - limit on maximum number of iterations
* `maxfnevals` - limit on maximum number of function evaluations
* `strict` - if `false` (the default), when the algorithm stops, possible zeros are checked with a relaxed tolerance
* `verbose` - if `true` a trace of the algorithm will be shown on successful completion.

See the help string for `Roots.assess_convergence` for details on
convergence. See the help page for `Roots.default_tolerances(method)`
for details on the default tolerances.

In general, with floating point numbers, convergence must be
understood as not an absolute statement. Even if mathematically x is
an answer and xstar the floating point realization, it may be that
f(xstar) - f(x) = f(xstar) ≈ f'(x) ⋅ eps(x), so tolerances must be
appreciated, and at times specified.

For the `Bisection` methods, convergence is guaranteed, so the tolerances are set to be 0 by default.

If a bracketing method is passed in after the method specification, if a bracket is found, the bracketing method will used to identify the zero. This is what `Order0` does by default, with a secant step initially.

Note: The order of the method is hinted at in the naming scheme. A
scheme is order `q` if, with `e_n = x_n - alpha`, `e_{n+1} = C
e_n^q`. If the error `e_n` is small enough, then essentially the error
will gain `q` times as many leading zeros each step. However, if the
error is not small, this will not be the case. Without good initial
guesses, a high order method may still converge slowly, if at all. The
`OrderN` methods have some heuristics employed to ensure a wider range
for convergence at the cost of not faithfully implementing the method,
though those are available through unexported methods.

# Examples:

```
# default methods
find_zero(sin, 3)  # use Order0()
find_zero(sin, (3,4)) # use Bisection()

# specifying a method
find_zero(sin, (3,4), Order1())            # can specify two starting points for secant method
find_zero(sin, 3.0, Order2())              # Use Steffensen method
find_zero(sin, big(3.0), Order16())        # rapid convergence
find_zero(sin, (3, 4), Roots.A42()())      # fewer function calls than Bisection(), in this case
find_zero(sin, (3, 4), FalsePosition(8))   # 1 of 12 possible algorithms for false position
find_zero((sin,cos), 3.0, Roots.Newton())  # use Newton's method
find_zero((sin, cos, x->-sin(x)), 3.0, Roots.Halley())  # use Halley's method

# changing tolerances
fn, x0, xstar = (x -> (2x*cos(x) + x^2 - 3)^10/(x^2 + 1), 3.0,  2.9806452794385368)
find_zero(fn, x0, Order2()) - xstar        # 0.014079847201995843
find_zero(fn, x0, Order2(), atol=0.0, rtol=0.0) # error: x_n ≉ x_{n-1}; just f(x_n) ≈ 0
fn, x0, xstar = (x -> (sin(x)*cos(x) - x^3 + 1)^9,        1.0,  1.117078770687451)
find_zero(fn, x0, Order2())                # 1.1122461983100858
find_zero(fn, x0, Order2(), maxevals=3)    # Roots.ConvergenceFailed: 26 iterations needed

# tracing output
find_zero(x->sin(x), 3.0, Order2(), verbose=true)   # 3 iterations
find_zero(x->sin(x)^5, 3.0, Order2(), verbose=true) # 22 iterations
find_zero(x->sin(x)^5, 3.0, Roots.Order2B(), verbose=true) # 2 iterations
```
"""
function find_zero(fs, x0, method::AbstractUnivariateZeroMethod,
                   N::Union{Nothing, AbstractBracketing}=nothing;
                   tracks::AbstractTracks=NullTracks(),
                   verbose=false,
                   kwargs...)

    F = callable_function(fs)
    state = init_state(method, F, x0)
    options = init_options(method, state; kwargs...)

    l = (verbose && isa(tracks, NullTracks)) ? Tracks(eltype(state.xn1)[], eltype(state.fxn1)[]) : tracks

    if N == nothing  || isa(method, AbstractBracketing)
        xstar = find_zero(method, F, options, state, l)
    else
        xstar = find_zero(method, N, F, options, state, l)
    end

    if verbose
        show_trace(method, N, state, l)
    end

    if isnan(xstar)
        throw(ConvergenceFailed("Stopped at: xn = $(state.xn1)"))
    else
        return xstar
    end

end

find_zero(f, x0::T; kwargs...)  where {T <: Number}= find_zero(f, x0, Order0(); kwargs...)
find_zero(f, x0::Vector; kwargs...) = find_zero(f, x0, Bisection(); kwargs...)
find_zero(f, x0::Tuple; kwargs...) = find_zero(f, x0, Bisection(); kwargs...)

# Main method
# return a zero or NaN.
## Updates state, could be `find_zero!(state, M, F, options, l)...
function find_zero(M::AbstractUnivariateZeroMethod,
                   F,
                   options::UnivariateZeroOptions,
                   state::AbstractUnivariateZeroState,
                   l::AbstractTracks=NullTracks()
                   )  #where {T<:Number, S<:Number}

    log_step(l, M, state, :init)

    while true
        val = assess_convergence(M, state, options)
        val && break
        update_state(M, F, state, options)
        log_step(l, M, state)
        incsteps(state)
    end

    return decide_convergence(M, F, state, options)
end

# state has stopped, this identifies if it has converged
function decide_convergence(M::AbstractUnivariateZeroMethod,  F, state::UnivariateZeroState{T,S}, options) where {T,S}
    xn1 = state.xn1
    fxn1 = state.fxn1

    if (state.stopped || state.x_converged) && !(state.f_converged)
        ## stopped is a heuristic, x_converged can mask issues
        ## if strict == false, this will also check f(xn) ~ - with a relaxed
        ## tolerance

        ## are we at a crossing values?
        ## seems worth a check for 2 fn evals.
        if T <: Real && S <: Real
            for u in (prevfloat(xn1), nextfloat(xn1))
                fu = first(F(u))
                if iszero(fu) || _unitless(fu * fxn1) < 0
                    state.message *= "Change of sign at xn identified. "
                    state.f_converged = true
                end
            end
        end

        if options.strict
            if state.x_converged
                state.f_converged = true
            else
                state.convergence_failed = true
            end
        else
            xstar, fxstar = state.xn1, state.fxn1
            if _is_f_approx_0(fxstar, xstar, options.abstol, options.reltol, :relaxed)
                msg = "Algorithm stopped early, but |f(xn)| < ϵ^(1/3), where ϵ depends on xn, rtol, and atol. "
                state.message = state.message == "" ? msg : state.message * "\n\t" * msg
                state.f_converged = true
            else
                state.convergence_failed = true
            end
        end
    end

    if state.f_converged
        return state.xn1
    end

    nan = NaN * state.xn1
    if state.convergence_failed
        return nan
    end
    return nan

end


# Switch to bracketing method
#M = Bisection()  # exact for floating point
#M = AlefeldPotraShi() # *usually* exact
#M = Brent()          # a bit faster, but not always convergent, as implemented (cf. RootTesting)
run_bisection(f, xs, state, options) = run_bisection(AlefeldPotraShi(), f, xs, state, options)
function run_bisection(N::AbstractBracketing, f, xs, state, options)
    steps, fnevals = state.steps, state.fnevals
    init_state!(state, N, f, xs)
    state.steps += steps
    state.fnevals += fnevals # could avoid 2 fn calls, with fxs
    init_options!(options, N)
    find_zero(N, f, options, state)
    a, b = xs
    u,v = a > b ? (b, a) : (a, b)
    state.message *= "Bracketing used over ($u, $v), those steps not shown. "
    return nothing
end


# Robust version using some tricks: idea from algorithm described in
# [The SOLVE button from the
# HP-34]C(http://www.hpl.hp.com/hpjournal/pdfs/IssuePDFs/1979-12.pdf).
# * use bracketing method if one identifed
# * limit steps so as not too far or too near the previous one
# * if not decreasing, use a quad step upto 4 times to bounce out of trap, if possible
# First uses M, then N if bracket is identified
function find_zero(M::AbstractUnivariateZeroMethod,
                   N::AbstractBracketing,
                   F,
                   options::UnivariateZeroOptions,
                   state::AbstractUnivariateZeroState,
                   l::AbstractTracks=NullTracks()
                   )


    log_step(l, M, state, :init)
    state0 = copy(state)
    quad_ctr = 0

    while true

        if assess_convergence(M, state, options)
            break
        end

        copy!(state0, state)
        update_state(M, F, state0, options) # state0 is proposed step

        adj = false
        ## did we find a zero or a bracketing interval?
        if iszero(state0.fxn1)
            copy!(state, state0)
            state.f_converged = true
            break
        elseif sign(state0.fxn0) * sign(state0.fxn1) < 0
            copy!(state, state0)
            a, b = state0.xn0, state0.xn1 # could save some fn calls here
            run_bisection(N, F, (a, b), state, options)
            break
        end


        ## did we move too far?
        r, a, b = state0.xn1, state.xn0, state.xn1
        Δr = abs(r - b)
        Δx = abs(b - a)
        ts,TB = 1e-3, 1e2 # too small, too big
        if  Δr >= TB * Δx
            adj = true
            r = b + sign(r-b) * TB * Δx  ## too big
            state0.xn1 = r
            state0.fxn1 = F(r)
            incfn(state)
        elseif Δr  <= ts *  Δx
            adj = true
            r = b + sign(r - b) * ts * Δx
            fr = F(r)
            incfn(state)
            state0.xn1 = r
            state0.fxn1 = fr
        end

        # a sign change after shortening?
        if sign(state.fxn1) * sign(state0.fxn1) < 0
            state.xn0, state.fxn0 = state.xn1, state.fxn1
            state.xn1, state.fxn1 = state0.xn1, state0.fxn1
            a, b = state.xn0, state.xn1
            run_bisection(N, F, (a, b), state, options)
            break
        end


        ## did we improve?
        if adj || abs(state0.fxn1) < abs(state.fxn1)
            if isnan(state0.xn1) || isnan(state0.fxn1) || isinf(state0.xn1) || isinf(state0.fxn1)
                break
            end
            copy!(state, state0)
            log_step(l, M, state)
            incsteps(state)
            quad_ctr = 0
            continue
        end

        ## try quad_vertex, unless that has gotten old
        if quad_ctr > 4
            copy!(state, state0)
            state.stopped = true
            break
        else
            quad_ctr += 1
            r = quad_vertex(state0.xn1, state0.fxn1, state.xn1, state.fxn1, state.xn0, state.fxn0)

            if isnan(r) || isinf(r)
                copy!(state, state0)
            else

                fr = F(r)
                incfn(state)

                state0.xn1 = r
                state0.fxn1 = fr
                incfn(state)
                copy!(state, state0)
            end
        end

        log_step(l, M, state)
        incsteps(state)
    end

    decide_convergence(M, F, state, options)
end
