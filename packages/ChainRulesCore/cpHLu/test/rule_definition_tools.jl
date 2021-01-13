"""
Along same lines as  `@test_throws` but to test if a macro throw an exception when it is
expanded.
"""
macro test_macro_throws(err_expr, expr)
    quote
        err = nothing
        try
            @macroexpand($(esc(expr)))
        catch load_err
            # all errors thrown at macro expansion time are LoadErrors, we need to unwrap
            @assert load_err isa LoadError
            err = load_err.error
        end
        # Reuse `@test_throws` logic
        if err!==nothing
            @test_throws $(esc(err_expr)) ($(Meta.quot(expr)); throw(err))
        else
            @test_throws $(esc(err_expr)) $(Meta.quot(expr))
        end
    end
end

# struct need to be defined outside of tests for julia 1.0 compat
struct NonDiffExample
    x
end

struct NonDiffCounterExample
    x
end

@testset "rule_definition_tools.jl" begin
    @testset "@non_differentiable" begin
        @testset "two input one output function" begin
            nondiff_2_1(x, y) = fill(7.5, 100)[x + y]
            @non_differentiable nondiff_2_1(::Any, ::Any)
            @test frule((Zero(), 1.2, 2.3), nondiff_2_1, 3, 2) == (7.5, DoesNotExist())
            res, pullback = rrule(nondiff_2_1, 3, 2)
            @test res == 7.5
            @test pullback(4.5) == (NO_FIELDS, DoesNotExist(), DoesNotExist())
        end

        @testset "one input, 2-tuple output function" begin
            nondiff_1_2(x) = (5.0, 3.0)
            @non_differentiable nondiff_1_2(::Any)
            @test frule((Zero(), 1.2), nondiff_1_2, 3.1) == ((5.0, 3.0), DoesNotExist())
            res, pullback = rrule(nondiff_1_2, 3.1)
            @test res == (5.0, 3.0)
            @test isequal(
                pullback(Composite{Tuple{Float64, Float64}}(1.2, 3.2)),
                (NO_FIELDS, DoesNotExist()),
            )
        end

        @testset "constrained signature" begin
            nonembed_identity(x) = x
            @non_differentiable nonembed_identity(::Integer)

            @test frule((Zero(), 1.2), nonembed_identity, 2) == (2, DoesNotExist())
            @test frule((Zero(), 1.2), nonembed_identity, 2.0) == nothing

            res, pullback = rrule(nonembed_identity, 2)
            @test res == 2
            @test pullback(1.2) == (NO_FIELDS, DoesNotExist())

            @test rrule(nonembed_identity, 2.0) == nothing
        end

        @testset "Pointy UnionAll constraints" begin
            pointy_identity(x) = x
            @non_differentiable pointy_identity(::Vector{<:AbstractString})

            @test frule((Zero(), 1.2), pointy_identity, ["2"]) == (["2"], DoesNotExist())
            @test frule((Zero(), 1.2), pointy_identity, 2.0) == nothing

            res, pullback = rrule(pointy_identity, ["2"])
            @test res == ["2"]
            @test pullback(1.2) == (NO_FIELDS, DoesNotExist())

            @test rrule(pointy_identity, 2.0) == nothing
        end

        @testset "kwargs" begin
            kw_demo(x; kw=2.0) = x + kw
            @non_differentiable kw_demo(::Any)

            @testset "not setting kw" begin
                @assert kw_demo(1.5) == 3.5

                res, pullback = rrule(kw_demo, 1.5)
                @test res == 3.5
                @test pullback(4.1) == (NO_FIELDS, DoesNotExist())

                @test frule((Zero(), 11.1), kw_demo, 1.5) == (3.5, DoesNotExist())
            end

            @testset "setting kw" begin
                @assert kw_demo(1.5; kw=3.0) == 4.5

                res, pullback = rrule(kw_demo, 1.5; kw=3.0)
                @test res == 4.5
                @test pullback(1.1) == (NO_FIELDS, DoesNotExist())

                @test frule((Zero(), 11.1), kw_demo, 1.5; kw=3.0) == (4.5, DoesNotExist())
            end
        end

        @testset "Constructors" begin
            @non_differentiable NonDiffExample(::Any)

            @test isequal(
                frule((Zero(), 1.2), NonDiffExample, 2.0),
                (NonDiffExample(2.0), DoesNotExist())
            )

            res, pullback = rrule(NonDiffExample, 2.0)
            @test res == NonDiffExample(2.0)
            @test pullback(1.2) == (NO_FIELDS, DoesNotExist())

            # https://github.com/JuliaDiff/ChainRulesCore.jl/issues/213
            # problem was that `@nondiff Foo(x)` was also defining rules for other types.
            # make sure that isn't happenning
            @test frule((Zero(), 1.2), NonDiffCounterExample, 2.0) === nothing
            @test rrule(NonDiffCounterExample, 2.0) === nothing
        end

        @testset "Varargs" begin
            fvarargs(a, xs...) = sum((a, xs...))
            @testset "xs::Float64..." begin
                @non_differentiable fvarargs(a, xs::Float64...)

                y, pb = rrule(fvarargs, 1)
                @test y == fvarargs(1)
                @test pb(1) == (Zero(), DoesNotExist())

                y, pb = rrule(fvarargs, 1, 2.0, 3.0)
                @test y == fvarargs(1, 2.0, 3.0)
                @test pb(1) == (Zero(), DoesNotExist(), DoesNotExist(), DoesNotExist())

                @test frule((1, 1), fvarargs, 1, 2.0) == (fvarargs(1, 2.0), DoesNotExist())

                @test frule((1, 1), fvarargs, 1, 2) == nothing
                    @test rrule(fvarargs, 1, 2) == nothing
            end

            @testset "::Float64..." begin
                @non_differentiable fvarargs(a, ::Float64...)

                y, pb = rrule(fvarargs, 1, 2.0, 3.0)
                @test y == fvarargs(1, 2.0, 3.0)
                @test pb(1) == (Zero(), DoesNotExist(), DoesNotExist(), DoesNotExist())

                @test frule((1, 1), fvarargs, 1, 2.0) == (fvarargs(1, 2.0), DoesNotExist())
            end

            @testset "::Vararg{Float64}" begin
                @non_differentiable fvarargs(a, ::Vararg{Float64})

                y, pb = rrule(fvarargs, 1, 2.0, 3.0)
                @test y == fvarargs(1, 2.0, 3.0)
                @test pb(1) == (Zero(), DoesNotExist(), DoesNotExist(), DoesNotExist())

                @test frule((1, 1), fvarargs, 1, 2.0) == (fvarargs(1, 2.0), DoesNotExist())
            end

            @testset "::Vararg" begin
                @non_differentiable fvarargs(a, ::Vararg)
                @test frule((1, 1), fvarargs, 1, 2) == (fvarargs(1, 2), DoesNotExist())

                y, pb = rrule(fvarargs, 1, 1)
                @test y == fvarargs(1, 1)
                @test pb(1) == (Zero(), DoesNotExist(), DoesNotExist())
            end

            @testset "xs..." begin
                @non_differentiable fvarargs(a, xs...)
                @test frule((1, 1), fvarargs, 1, 2) == (fvarargs(1, 2), DoesNotExist())

                y, pb = rrule(fvarargs, 1, 1)
                @test y == fvarargs(1, 1)
                @test pb(1) == (Zero(), DoesNotExist(), DoesNotExist())
            end
        end

        @testset "Not supported (Yet)" begin
            # Where clauses are not supported.
            @test_macro_throws(
                ErrorException,
                (@non_differentiable where_identity(::Vector{T}) where T<:AbstractString)
            )
        end
    end

    @testset "@scalar_rule" begin
        @testset "@scalar_rule with multiple output" begin
            simo(x) = (x, 2x)
            @scalar_rule(simo(x), 1f0, 2f0)

            y, simo_pb = rrule(simo, π)

            @test simo_pb((10f0, 20f0)) == (NO_FIELDS, 50f0)

            y, ẏ = frule((NO_FIELDS, 50f0), simo, π)
            @test y == (π, 2π)
            @test ẏ == Composite{typeof(y)}(50f0, 100f0)
            # make sure type is exactly as expected:
            @test ẏ isa Composite{Tuple{Irrational{:π}, Float64}, Tuple{Float32, Float32}}
        end
    end
end
