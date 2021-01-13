
# pick a nice default x range given a distribution
function default_range(dist::Distribution, alpha = 0.0001)
    minval = isfinite(minimum(dist)) ? minimum(dist) : quantile(dist, alpha)
    maxval = isfinite(maximum(dist)) ? maximum(dist) : quantile(dist, 1-alpha)
    minval, maxval
end

function default_range(m::Distributions.MixtureModel, alpha = 0.0001)
    minval = maxval = 0.0
    for c in m.components
        thismin = isfinite(minimum(c)) ? minimum(c) : quantile(c, alpha)
        thismax = isfinite(maximum(c)) ? maximum(c) : quantile(c, 1-alpha)
        if thismin < minval
            minval = thismin
        end
        if thismax > maxval
            maxval = thismax
        end
    end
    minval, maxval
end

yz_args(dist) = default_range(dist)
yz_args(dist::Distribution{N, T}) where N where T<:Discrete = (UnitRange(default_range(dist)...),)

# this "user recipe" adds a default x vector based on the distribution's μ and σ
@recipe function f(dist::Distribution)
    if dist isa Distribution{Univariate,Discrete}
        seriestype --> :scatterpath
    end
    (dist, yz_args(dist)...)
end

@recipe function f(m::Distributions.MixtureModel; components = true)
    if components
        for c in m.components
            @series begin
                (c, yz_args(c)...)
            end
        end
    else
        (m, yz_args(m)...)
    end
end

@recipe function f(distvec::AbstractArray{<:Distribution}, yz...)
    for di in distvec
        @series begin
            seriesargs = isempty(yz) ? yz_args(di) : yz
            if di isa Distribution{Univariate,Discrete}
                seriestype --> :scatterpath
            end
            (di, seriesargs...)
        end
    end
end

# this "type recipe" replaces any instance of a distribution with a function mapping xi to yi
@recipe function f(::Type{T}, dist::T; func = pdf) where T<:Distribution
    xi -> func(dist, xi)
end

#-----------------------------------------------------------------------------
# qqplots

@recipe function f(h::QQPair; qqline = :identity)
    if qqline in (:fit, :quantile, :identity, :R)
        xs = [extrema(h.qx)...]
        if qqline == :identity
            ys = xs
        elseif qqline == :fit
            itc, slp = hcat(fill!(similar(h.qx), 1), h.qx) \ h.qy
            ys = slp .* xs .+ itc
        else # if qqline == :quantile || qqline == :R
            quantx, quanty = quantile(h.qx, [0.25, 0.75]), quantile(h.qy, [0.25, 0.75])
            slp = diff(quanty) ./ diff(quantx)
            ys = quanty .+ slp .* (xs .- quantx)
        end

        @series begin
            primary := false
            seriestype := :path
            xs, ys
        end
    end

    seriestype --> :scatter
    legend --> false
    h.qx, h.qy
end

loc(D::Type{T}, x) where T<:Distribution = fit(D, x), x
loc(D, x) = D, x

@userplot QQPlot
recipetype(::Val{:qqplot}, args...) = QQPlot(args)
@recipe f(h::QQPlot) = qqbuild(loc(h.args[1], h.args[2])...)

@userplot QQNorm
recipetype(::Val{:qqnorm}, args...) = QQNorm(args)
@recipe f(h::QQNorm) = QQPlot((Normal, h.args[1]))
