using Turing, TuringBenchmarks.TuringTools
using LinearAlgebra

include("lr_helper.jl")

x, y = readlrdata()

@model hlr_nuts(x, y, θ) = begin

    N,D = size(x)

    σ² ~ Exponential(θ)
    α ~ Normal(0, sqrt(σ²))
    β ~ MvNormal(zeros(D), ones(D)*sqrt(σ²))

    for n = 1:N
        y[n] ~ BinomialLogit(1, dot(x[n,:], β) + α)
    end
end

# Sampling parameter settings
n_samples = 10_000

# Sampling
@tbenchmark chain = sample(hlr_nuts(x, y, 1/0.1), NUTS(0.65), n_samples);
