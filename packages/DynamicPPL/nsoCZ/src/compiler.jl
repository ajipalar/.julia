"""
    struct ModelGen{Targs, F, Tdefaults} <: Function
        f::F
        defaults::Tdefaults
    end

A `Model` generator. This is the output of the `@model` macro. `Targs` is the tuple 
of the symbols of the model's arguments. `defaults` is the `NamedTuple` of default values
of the arguments, if any. Every `ModelGen` is callable with the arguments `Targs`, 
returning an instance of `Model`.
"""
struct ModelGen{Targs, F, Tdefaults} <: Function
    f::F
    defaults::Tdefaults
end
ModelGen{Targs}(args...) where {Targs} = ModelGen{Targs, typeof.(args)...}(args...)
(m::ModelGen)(args...; kwargs...) = m.f(args...; kwargs...)
function Base.getproperty(m::ModelGen{Targs}, f::Symbol) where {Targs}
    f === :args && return Targs
    return Base.getfield(m, f)
end

macro varinfo()
    :(throw(_error_msg()))
end
macro logpdf()
    :(throw(_error_msg()))
end
macro sampler()
    :(throw(_error_msg()))
end
function _error_msg()
    return "This macro is only for use in the `@model` macro and not for external use."
end

"""
    @varname(var)

A macro that returns an instance of `VarName` given the symbol or expression of a Julia variable, e.g. `@varname x[1,2][1+5][45][3]` returns `VarName{:x}("[1,2][6][45][3]")`.
"""
macro varname(expr::Union{Expr, Symbol})
    expr |> varname |> esc
end
function varname(expr)
    ex = deepcopy(expr)
    (ex isa Symbol) && return quote
        DynamicPPL.VarName{$(QuoteNode(ex))}("")
    end
    (ex.head == :ref) || throw("VarName: Mis-formed variable name $(expr)!")
    inds = :(())
    while ex.head == :ref
        if length(ex.args) >= 2
            strs = map(x -> :($x === (:) ? "Colon()" : string($x)), ex.args[2:end])
            pushfirst!(inds.args, :("[" * join($(Expr(:vect, strs...)), ",") * "]"))
        end
        ex = ex.args[1]
        isa(ex, Symbol) && return quote
            DynamicPPL.VarName{$(QuoteNode(ex))}(foldl(*, $inds, init = ""))
        end
    end
    throw("VarName: Mis-formed variable name $(expr)!")
end

macro vsym(expr::Union{Expr, Symbol})
    expr |> vsym
end

"""
    vsym(expr::Union{Expr, Symbol})

Returns the variable symbol given the input variable expression `expr`. For example, if the input `expr = :(x[1])`, the output is `:x`.
"""
function vsym(expr::Union{Expr, Symbol})
    ex = deepcopy(expr)
    (ex isa Symbol) && return QuoteNode(ex)
    (ex.head == :ref) || throw("VarName: Mis-formed variable name $(expr)!")
    while ex.head == :ref
        ex = ex.args[1]
        isa(ex, Symbol) && return QuoteNode(ex)
    end
    throw("VarName: Mis-formed variable name $(expr)!")
end

"""
    @vinds(expr)

Returns a tuple of tuples of the indices in `expr`. For example, `@vinds x[1,:][2]` returns 
`((1, Colon()), (2,))`.
"""
macro vinds(expr::Union{Expr, Symbol})
    expr |> vinds |> esc
end
function vinds(expr::Union{Expr, Symbol})
    ex = deepcopy(expr)
    inds = Expr(:tuple)
    (ex isa Symbol) && return inds
    (ex.head == :ref) || throw("VarName: Mis-formed variable name $(expr)!")
    while ex.head == :ref
        pushfirst!(inds.args, Expr(:tuple, ex.args[2:end]...))
        ex = ex.args[1]
        isa(ex, Symbol) && return inds
    end
    throw("VarName: Mis-formed variable name $(expr)!")
end

"""
    split_var_str(var_str, inds_as = Vector)

This function splits a variable string, e.g. `"x[1:3,1:2][3,2]"` to the variable's symbol `"x"` and the indexing `"[1:3,1:2][3,2]"`. If `inds_as = String`, the indices are returned as a string, e.g. `"[1:3,1:2][3,2]"`. If `inds_as = Vector`, the indices are returned as a vector of vectors of strings, e.g. `[["1:3", "1:2"], ["3", "2"]]`.
"""
function split_var_str(var_str, inds_as = Vector)
    ind = findfirst(c -> c == '[', var_str)
    if inds_as === String
        if ind === nothing
            return var_str, ""
        else
            return var_str[1:ind-1], var_str[ind:end]
        end
    end
    @assert inds_as === Vector
    inds = Vector{String}[]
    if ind === nothing
        return var_str, inds
    end
    sym = var_str[1:ind-1]
    ind = length(sym)
    while ind < length(var_str)
        ind += 1
        @assert var_str[ind] == '['
        push!(inds, String[])
        while var_str[ind] != ']'
            ind += 1
            if var_str[ind] == '['
                ind2 = findnext(c -> c == ']', var_str, ind)
                push!(inds[end], strip(var_str[ind:ind2]))
                ind = ind2+1
            else
                ind2 = findnext(c -> c == ',' || c == ']', var_str, ind)
                push!(inds[end], strip(var_str[ind:ind2-1]))
                ind = ind2
            end
        end
    end
    return sym, inds
end

# Check if the right-hand side is a distribution.
function assert_dist(dist; msg)
    isa(dist, Distribution) || throw(ArgumentError(msg))
end
function assert_dist(dist::AbstractVector; msg)
    all(d -> isa(d, Distribution), dist) || throw(ArgumentError(msg))
end

function wrong_dist_errormsg(l)
    return "Right-hand side of a ~ must be subtype of Distribution or a vector of " *
        "Distributions on line $(l)."
end

"""
    @preprocess(data_vars, missing_vars, ex)

Let `ex` be `x[1]`. This macro returns `@varname x[1]` in any of the following cases:
    1. `x` was not among the input data to the model,
    2. `x` was among the input data to the model but with a value `missing`, or
    3. `x` was among the input data to the model with a value other than missing, 
    but `x[1] === missing`.
Otherwise, the value of `x[1]` is returned.
"""
macro preprocess(data_vars, missing_vars, ex)
    ex
end
macro preprocess(data_vars, missing_vars, ex::Union{Symbol, Expr})
    sym = gensym(:sym)
    lhs = gensym(:lhs)
    return esc(quote
        # Extract symbol
        $sym = Val($(vsym(ex)))
        # This branch should compile nicely in all cases except for partial missing data
        # For example, when `ex` is `x[i]` and `x isa Vector{Union{Missing, Float64}}`
        if !DynamicPPL.inparams($sym, $data_vars) || DynamicPPL.inparams($sym, $missing_vars)
            $(varname(ex)), $(vinds(ex))
        else
            if DynamicPPL.inparams($sym, $data_vars)
                # Evaluate the lhs
                $lhs = $ex
                if $lhs === missing
                    $(varname(ex)), $(vinds(ex))
                else
                    $lhs
                end
            else
                throw("This point should not be reached. Please report this error.")
            end
        end
    end)
end
@generated function inparams(::Val{s}, ::Val{t}) where {s, t}
    return (s in t) ? :(true) : :(false)
end

#################
# Main Compiler #
#################

"""
    @model(body)

Macro to specify a probabilistic model.

Example:

Model definition:

```julia
@model model_generator(x = default_x, y) = begin
    ...
end
```

To generate a `Model`, call `model_generator(x_value)`.
"""
macro model(input_expr)
    build_model_info(input_expr) |> replace_tilde! |> replace_vi! |> 
        replace_logpdf! |> replace_sampler! |> build_output
end

"""
    build_model_info(input_expr)

Builds the `model_info` dictionary from the model's expression.
"""
function build_model_info(input_expr)
    # Extract model name (:name), arguments (:args), (:kwargs) and definition (:body)
    modeldef = MacroTools.splitdef(input_expr)
    # Function body of the model is empty
    warn_empty(modeldef[:body])
    # Construct model_info dictionary

    # Extracting the argument symbols from the model definition
    arg_syms = map(modeldef[:args]) do arg
        # @model demo(x)
        if (arg isa Symbol)
            arg
        # @model demo(::Type{T}) where {T}
        elseif MacroTools.@capture(arg, ::Type{T_} = Tval_)
            T
        # @model demo(x::T = 1)
        elseif MacroTools.@capture(arg, x_::T_ = val_)
            x
        # @model demo(x = 1)
        elseif MacroTools.@capture(arg, x_ = val_)
            x
        else
            throw(ArgumentError("Unsupported argument $arg to the `@model` macro."))
        end
    end
    if length(arg_syms) == 0
        args_nt = :(NamedTuple())
    else
        nt_type = Expr(:curly, :NamedTuple, 
            Expr(:tuple, QuoteNode.(arg_syms)...), 
            Expr(:curly, :Tuple, [:(DynamicPPL.get_type($x)) for x in arg_syms]...)
        )
        args_nt = Expr(:call, :(DynamicPPL.namedtuple), nt_type, Expr(:tuple, arg_syms...))
    end
    args = map(modeldef[:args]) do arg
        if (arg isa Symbol)
            arg
        elseif MacroTools.@capture(arg, ::Type{T_} = Tval_)
            if in(T, modeldef[:whereparams])
                S = :Any
            else
                ind = findfirst(modeldef[:whereparams]) do x
                    MacroTools.@capture(x, T1_ <: S_) && T1 == T
                end
                ind !== nothing || throw(ArgumentError("Please make sure type parameters are properly used. Every `Type{T}` argument need to have `T` in the a `where` clause"))
            end
            Expr(:kw, :($T::Type{<:$S}), Tval)
        else
            arg
        end
    end
    args_nt = to_namedtuple_expr(arg_syms)

    default_syms = []
    default_vals = [] 
    foreach(modeldef[:args]) do arg
        # @model demo(::Type{T}) where {T}
        if MacroTools.@capture(arg, ::Type{T_} = Tval_)
            push!(default_syms, T)
            push!(default_vals, Tval)
        # @model demo(x::T = 1)
        elseif MacroTools.@capture(arg, x_::T_ = val_)
            push!(default_syms, x)
            push!(default_vals, val)
        # @model demo(x = 1)
        elseif MacroTools.@capture(arg, x_ = val_)
            push!(default_syms, x)
            push!(default_vals, val)
        end
    end
    defaults_nt = to_namedtuple_expr(default_syms, default_vals)

    model_info = Dict(
        :name => modeldef[:name],
        :main_body => modeldef[:body],
        :arg_syms => arg_syms,
        :args_nt => args_nt,
        :defaults_nt => defaults_nt,
        :args => args,
        :whereparams => modeldef[:whereparams],
        :main_body_names => Dict(
            :ctx => gensym(:ctx),
            :vi => gensym(:vi),
            :sampler => gensym(:sampler),
            :model => gensym(:model),
            :inner_function => gensym(:inner_function),
            :defaults => gensym(:defaults)
        )
    )

    return model_info
end

function to_namedtuple_expr(syms::Vector, vals = syms)
    if length(syms) == 0
        nt = :(NamedTuple())
    else
        nt_type = Expr(:curly, :NamedTuple, 
            Expr(:tuple, QuoteNode.(syms)...), 
            Expr(:curly, :Tuple, [:(DynamicPPL.get_type($x)) for x in vals]...)
        )
        nt = Expr(:call, :(DynamicPPL.namedtuple), nt_type, Expr(:tuple, vals...))
    end
    return nt
end

"""
    replace_vi!(model_info)

Replaces `@varinfo()` expressions with a handle to the `VarInfo` struct.
"""
function replace_vi!(model_info)
    ex = model_info[:main_body]
    vi = model_info[:main_body_names][:vi]
    ex = MacroTools.postwalk(ex) do x
        if @capture(x, @varinfo())
            vi
        else
            x
        end
    end
    model_info[:main_body] = ex
    return model_info
end

"""
    replace_logpdf!(model_info)

Replaces `@logpdf()` expressions with the value of the accumulated `logpdf` in the `VarInfo` struct.
"""
function replace_logpdf!(model_info)
    ex = model_info[:main_body]
    vi = model_info[:main_body_names][:vi]
    ex = MacroTools.postwalk(ex) do x
        if @capture(x, @logpdf())
            :($vi.logp)
        else
            x
        end
    end
    model_info[:main_body] = ex
    return model_info
end

"""
    replace_sampler!(model_info)

Replaces `@sampler()` expressions with a handle to the sampler struct.
"""
function replace_sampler!(model_info)
    ex = model_info[:main_body]
    spl = model_info[:main_body_names][:sampler]
    ex = MacroTools.postwalk(ex) do x
        if @capture(x, @sampler())
            spl
        else
            x
        end
    end
    model_info[:main_body] = ex
    return model_info
end

# The next function is defined that way because .~ gives a parsing error in Julia 1.0
"""
\"""
    replace_tilde!(model_info)

Replaces `~` expressions with observation or assumption expressions, updating `model_info`.
\"""
function replace_tilde!(model_info)
    ex = model_info[:main_body]
    ex = MacroTools.postwalk(ex) do x 
        if @capture(x, @M_ L_ ~ R_) && M == Symbol("@__dot__")
            dot_tilde(L, R, model_info)
        else
            x
        end
    end
    $(VERSION >= v"1.1" ? "ex = MacroTools.postwalk(ex) do x
        if @capture(x, L_ .~ R_)
            dot_tilde(L, R, model_info)
        else
            x
        end
    end" : "")
    ex = MacroTools.postwalk(ex) do x
        if @capture(x, L_ ~ R_)
            tilde(L, R, model_info)
        else
            x
        end
    end
    model_info[:main_body] = ex
    return model_info
end
""" |> Meta.parse |> eval

"""
    tilde(left, right, model_info)

The `tilde` function generates `observe` expression for data variables and `assume` 
expressions for parameter variables, updating `model_info` in the process.
"""
function tilde(left, right, model_info)
    arg_syms = Val((model_info[:arg_syms]...,))
    model = model_info[:main_body_names][:model]
    vi = model_info[:main_body_names][:vi]
    ctx = model_info[:main_body_names][:ctx]
    sampler = model_info[:main_body_names][:sampler]
    temp_right = gensym(:temp_right)
    out = gensym(:out)
    lp = gensym(:lp)
    vn = gensym(:vn)
    inds = gensym(:inds)
    preprocessed = gensym(:preprocessed)
    assert_ex = :(DynamicPPL.assert_dist($temp_right, msg = $(wrong_dist_errormsg(@__LINE__))))
    if left isa Symbol || left isa Expr
        ex = quote
            $temp_right = $right
            $assert_ex
            $preprocessed = DynamicPPL.@preprocess($arg_syms, DynamicPPL.getmissing($model), $left)
            if $preprocessed isa Tuple
                $vn, $inds = $preprocessed
                $out = DynamicPPL.tilde($ctx, $sampler, $temp_right, $vn, $inds, $vi)
                $left = $out[1]
                $vi.logp += $out[2]
            else
                $vi.logp += DynamicPPL.tilde($ctx, $sampler, $temp_right, $preprocessed, $vi)
            end
        end
    else
        ex = quote
            $temp_right = $right
            $assert_ex
            $vi.logp += DynamicPPL.tilde($ctx, $sampler, $temp_right, $left, $vi)
        end
    end
    return ex
end

"""
    dot_tilde(left, right, model_info)

This function returns the expression that replaces `left .~ right` in the model body. If `preprocessed isa VarName`, then a `dot_assume` block will be run. Otherwise, a `dot_observe` block will be run.
"""
function dot_tilde(left, right, model_info)
    arg_syms = Val((model_info[:arg_syms]...,))
    model = model_info[:main_body_names][:model]
    vi = model_info[:main_body_names][:vi]
    ctx = model_info[:main_body_names][:ctx]
    sampler = model_info[:main_body_names][:sampler]
    out = gensym(:out)
    temp_left = gensym(:temp_left)
    temp_right = gensym(:temp_right)
    preprocessed = gensym(:preprocessed)
    lp = gensym(:lp)
    vn = gensym(:vn)
    inds = gensym(:inds)
    assert_ex = :(DynamicPPL.assert_dist($temp_right, msg = $(wrong_dist_errormsg(@__LINE__))))
    if left isa Symbol || left isa Expr
        ex = quote
            $temp_right = $right
            $assert_ex
            $preprocessed = DynamicPPL.@preprocess($arg_syms, DynamicPPL.getmissing($model), $left)
            if $preprocessed isa Tuple
                $vn, $inds = $preprocessed
                $temp_left = $left
                $out = DynamicPPL.dot_tilde($ctx, $sampler, $temp_right, $temp_left, $vn, $inds, $vi)
                $left .= $out[1]
                $vi.logp += $out[2]
            else
                $temp_left = $preprocessed
                $vi.logp += DynamicPPL.dot_tilde($ctx, $sampler, $temp_right, $temp_left, $vi)
            end
        end
    else
        ex = quote
            $temp_left = $left
            $temp_right = $right
            $assert_ex
            $vi.logp += DynamicPPL.dot_tilde($ctx, $sampler, $temp_right, $temp_left, $vi)
        end
    end
    return ex
end

const FloatOrArrayType = Type{<:Union{AbstractFloat, AbstractArray}}
hasmissing(T::Type{<:AbstractArray{TA}}) where {TA <: AbstractArray} = hasmissing(TA)
hasmissing(T::Type{<:AbstractArray{>:Missing}}) = true
hasmissing(T::Type) = false

"""
    build_output(model_info)

Builds the output expression.
"""
function build_output(model_info)
    # Construct user-facing function
    main_body_names = model_info[:main_body_names]
    ctx = main_body_names[:ctx]
    vi = main_body_names[:vi]
    model = main_body_names[:model]
    sampler = main_body_names[:sampler]
    inner_function = main_body_names[:inner_function]

    # Arguments with default values
    args = model_info[:args]
    # Argument symbols without default values
    arg_syms = model_info[:arg_syms]
    # Arguments namedtuple
    args_nt = model_info[:args_nt]
    # Default values of the arguments
    # Arguments namedtuple
    defaults_nt = model_info[:defaults_nt]
    # Where parameters
    whereparams = model_info[:whereparams]
    # Model generator name
    model_gen = model_info[:name]
    # Outer function name
    outer_function = gensym(model_info[:name])
    # Main body of the model
    main_body = model_info[:main_body]
    model_gen_constructor = quote
        DynamicPPL.ModelGen{$(Tuple(arg_syms))}(
            $outer_function, 
            $defaults_nt,
        )
    end
    unwrap_data_expr = Expr(:block)
    for var in arg_syms
        temp_var = gensym(:temp_var)
        varT = gensym(:varT)
        push!(unwrap_data_expr.args, quote
            local $var
            $temp_var = $model.args.$var
            $varT = typeof($temp_var)
            if $temp_var isa DynamicPPL.FloatOrArrayType
                $var = DynamicPPL.get_matching_type($sampler, $vi, $temp_var)
            elseif DynamicPPL.hasmissing($varT)
                $var = DynamicPPL.get_matching_type($sampler, $vi, $varT)($temp_var)
            else
                $var = $temp_var
            end
        end)
    end
    return esc(quote
        # Allows passing arguments as kwargs
        $outer_function(;$(args...)) = $outer_function($(arg_syms...))
        function $outer_function($(args...))
            function $inner_function(
                $vi::DynamicPPL.VarInfo,
                $sampler::DynamicPPL.AbstractSampler,
                $ctx::DynamicPPL.AbstractContext,
                $model
            )
                $unwrap_data_expr
                $vi.logp = 0
                $main_body
            end
            return DynamicPPL.Model($inner_function, $args_nt, $model_gen_constructor)
        end
        $model_gen = $model_gen_constructor
    end)
end

# A hack for NamedTuple type specialization
# (T = Int,) has type NamedTuple{(:T,), Tuple{DataType}} by default
# With this function, we can make it NamedTuple{(:T,), Tuple{Type{Int}}}
# Both are correct, but the latter is what we want for type stability
get_type(::Type{T}) where {T} = Type{T}
get_type(t) = typeof(t)

function warn_empty(body)
    if all(l -> isa(l, LineNumberNode), body.args)
        @warn("Model definition seems empty, still continue.")
    end
    return
end

"""
    get_matching_type(spl, vi, ::Type{T}) where {T}
Get the specialized version of type `T` for sampler `spl`. For example,
if `T === Float64` and `spl::Hamiltonian`, the matching type is `eltype(vi[spl])`.
"""
function get_matching_type end