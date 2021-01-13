
# ---------------------------------------------------------------------------
# density

@recipe function f(::Type{Val{:density}}, x, y, z; trim=false)
    newx, newy = violin_coords(y, trim=trim, wts = plotattributes[:weights])
    if Plots.isvertical(plotattributes)
        newx, newy = newy, newx
    end
    x := newx
    y := newy
    seriestype := :path
    ()
end
Plots.@deps density path


# ---------------------------------------------------------------------------
# cumulative density

@recipe function f(::Type{Val{:cdensity}}, x, y, z; trim=false,
                   npoints = 200)
    newx, newy = violin_coords(y, trim=trim, wts = plotattributes[:weights])

    if Plots.isvertical(plotattributes)
        newx, newy = newy, newx
    end

    newy = [sum(newy[1:i]) for i = 1:length(newy)] / sum(newy)

    x := newx
    y := newy
    seriestype := :path
    ()
end
Plots.@deps cdensity path

ea_binnumber(y, bin::AbstractVector) = error("You cannot specify edge locations for equal area histogram")
ea_binnumber(y, bin::Real) = (floor(bin) == bin || error("Only integer or symbol values accepted by bins"); Int(bin))
ea_binnumber(y, bin::Int) = bin
ea_binnumber(y, bin::Symbol) = Plots._auto_binning_nbins((y,), 1, mode = bin)

@recipe function f(::Type{Val{:ea_histogram}}, x, y, z)
    bin = ea_binnumber(y, plotattributes[:bins])
    bins := quantile(y, range(0, stop = 1, length = bin+1))
    normalize := :density
    seriestype := :barhist
    ()
end
Plots.@deps histogram barhist

push!(Plots._histogram_like, :ea_histogram)

@shorthands ea_histogram


@recipe function f(::Type{Val{:testhist}}, x, y, z)
    markercolor --> :red
    seriestype := :scatter
    ()
end
@shorthands testhist
# ---------------------------------------------------------------------------
# Compute binsizes using Wand (1997)'s criterion
# Ported from R code located here https://github.com/cran/KernSmooth/tree/master/R

"Returns optimal histogram edge positions in accordance to Wand (1995)'s criterion'"
Plots.wand_edges(x::AbstractVector, args...) = (binwidth = wand_bins(x, args...); minimum(x)-binwidth:binwidth:maximum(x)+binwidth)

"Returns optimal histogram bin widths in accordance to Wand (1995)'s criterion'"
function wand_bins(x, scalest = :minim, gridsize = 401, range_x = extrema(x), trun = true)

    n = length(x)
    minx, maxx = range_x
    gpoints = range(minx, stop = maxx, length = gridsize)
    gcounts = linbin(x, gpoints, trun = trun)

    scalest = if scalest == :stdev
        sqrt(var(x))
    elseif scalest == :iqr
        (quantile(x, 3//4) - quantile(x, 1//4))/1.349
    elseif scalest == :minim
        min((quantile(x, 3//4) - quantile(x, 1//4))/1.349, sqrt(var(x)))
    else
        error("scalest must be one of :stdev, :iqr or :minim (default)")
    end

    scalest == 0 && error("scale estimate is zero for input data")
    sx = (x .- mean(x))./scalest
    sa = (minx - mean(x))/scalest
    sb = (maxx - mean(x))/scalest

    gpoints = range(sa, stop = sb, length = gridsize)
    gcounts = linbin(sx, gpoints, trun = trun)

    hpi = begin
        alpha = ((2/(11 * n))^(1/13)) * sqrt(2)
        psi10hat = bkfe(gcounts, 10, alpha, [sa, sb])
        alpha = (-105 * sqrt(2/pi)/(psi10hat * n))^(1//11)
        psi8hat = bkfe(gcounts, 8, alpha, [sa, sb])
        alpha = (15 * sqrt(2/pi)/(psi8hat * n))^(1/9)
        psi6hat = bkfe(gcounts, 6, alpha, [sa, sb])
        alpha = (-3 * sqrt(2/pi)/(psi6hat * n))^(1/7)
        psi4hat = bkfe(gcounts, 4, alpha, [sa, sb])
        alpha = (sqrt(2/pi)/(psi4hat * n))^(1/5)
        psi2hat = bkfe(gcounts, 2, alpha, [sa, sb])
        (6/(-psi2hat * n))^(1/3)
    end

    scalest * hpi
end


function linbin(X, gpoints; trun = true)
    n, M = length(X), length(gpoints)

    a, b = gpoints[1], gpoints[M]
    gcnts = zeros(M)
    delta = (b-a)/(M-1)

    for i in 1:n
        lxi = ((X[i]-a)/delta) + 1
        li = floor(Int, lxi)
        rem = lxi - li

        if 1 <= li < M
            gcnts[li] += 1-rem
            gcnts[li+1] += rem
        end

        if !trun
            if lt < 1
                gcnts[1] += 1
            end

            if li >= M
                gcnts[M] += 1
            end
        end
    end
    gcnts
end

"binned kernel function estimator"
function bkfe(gcounts, drv, bandwidth, range_x)
    bandwidth <= 0 && error("'bandwidth' must be strictly positive")

    a, b = range_x
    h = bandwidth
    M = length(gcounts)
    gpoints = range(a, stop = b, length = M)

    ## Set the sample size and bin width

    n = sum(gcounts)
    delta = (b-a)/(M-1)

    ## Obtain kernel weights

    tau = 4 + drv
    L = min(floor(tau*h/delta), M)

    lvec = 0:L
    arg = lvec .* delta/h

    kappam = pdf(Normal(),arg)/(h^(drv+1))
    hmold0, hmnew = ones(length(arg)), ones(length(arg))
    hmold1 = arg

    if drv >= 2
        for i in (2:drv)
            hmnew = arg .* hmold1 .- (i-1) .* hmold0
            hmold0 = hmold1       # Compute mth degree Hermite polynomial
            hmold1 = hmnew        # by recurrence.
        end
    end
    kappam = hmnew .* kappam

    ## Now combine weights and counts to obtain estimate
    ## we need P >= 2L+1L, M: L <= M.
    P = 2^(ceil(log(M+L+1)/log(2)))
    kappam = [kappam; zeros(P-2*L-1); reverse(kappam[2:end])]
    Gcounts = [gcounts; zeros(P-M)]
    kappam = fft(kappam)
    Gcounts = fft(Gcounts)

    sum(gcounts .* (real(ifft(kappam .* Gcounts)))[1:M] )/(n^2)
end
