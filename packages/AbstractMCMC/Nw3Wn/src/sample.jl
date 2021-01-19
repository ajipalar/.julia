# Default implementations of `sample`.

function StatsBase.sample(
    model::AbstractModel,
    sampler::AbstractSampler,
    arg;
    kwargs...
)
    return StatsBase.sample(Random.GLOBAL_RNG, model, sampler, arg; kwargs...)
end

function StatsBase.sample(
    rng::Random.AbstractRNG,
    model::AbstractModel,
    sampler::AbstractSampler,
    arg;
    kwargs...
)
    return mcmcsample(rng, model, sampler, arg; kwargs...)
end

function StatsBase.sample(
    model::AbstractModel,
    sampler::AbstractSampler,
    parallel::AbstractMCMCParallel,
    N::Integer,
    nchains::Integer;
    kwargs...
)
    return StatsBase.sample(Random.GLOBAL_RNG, model, sampler, parallel, N, nchains;
                            kwargs...)
end

function StatsBase.sample(
    rng::Random.AbstractRNG,
    model::AbstractModel,
    sampler::AbstractSampler,
    parallel::AbstractMCMCParallel,
    N::Integer,
    nchains::Integer;
    kwargs...
)
    return mcmcsample(rng, model, sampler, parallel, N, nchains; kwargs...)
end

# Default implementations of regular and parallel sampling.

"""
    mcmcsample([rng, ]model, sampler, N; kwargs...)

Return `N` samples from the MCMC `sampler` for the provided `model`.

A callback function `f` with type signature
```julia
f(rng, model, sampler, sample, iteration)
```
may be provided as keyword argument `callback`. It is called after every sampling step.
"""
function mcmcsample(
    rng::Random.AbstractRNG,
    model::AbstractModel,
    sampler::AbstractSampler,
    N::Integer;
    progress = true,
    progressname = "Sampling",
    callback = nothing,
    discard_initial = 0,
    thinning = 1,
    chain_type::Type=Any,
    kwargs...
)
    # Check the number of requested samples.
    N > 0 || error("the number of samples must be ≥ 1")
    Ntotal = thinning * (N - 1) + discard_initial + 1

    @ifwithprogresslogger progress name=progressname begin
        # Obtain the initial sample and state.
        sample, state = step(rng, model, sampler; kwargs...)

        # Discard initial samples.
        for i in 1:(discard_initial - 1)
            # Update the progress bar.
            progress && ProgressLogging.@logprogress i/Ntotal

            # Obtain the next sample and state.
            sample, state = step(rng, model, sampler, state; kwargs...)
        end

        # Run callback.
        callback === nothing || callback(rng, model, sampler, sample, 1)

        # Save the sample.
        samples = AbstractMCMC.samples(sample, model, sampler, N; kwargs...)
        samples = save!!(samples, sample, 1, model, sampler, N; kwargs...)

        # Update the progress bar.
        progress && ProgressLogging.@logprogress (1 + discard_initial) / Ntotal

        # Step through the sampler.
        itotal = 1 + discard_initial
        for i in 2:N
            # Discard thinned samples.
            for _ in 1:(thinning - 1)
                # Obtain the next sample and state.
                sample, state = step(rng, model, sampler, state; kwargs...)
                
                # Update progress bar.
                if progress
                    itotal += 1
                    ProgressLogging.@logprogress itotal / Ntotal
                end
            end

            # Obtain the next sample and state.
            sample, state = step(rng, model, sampler, state; kwargs...)

            # Run callback.
            callback === nothing || callback(rng, model, sampler, sample, i)

            # Save the sample.
            samples = save!!(samples, sample, i, model, sampler, N; kwargs...)

            # Update the progress bar.
            if progress
                itotal += 1
                ProgressLogging.@logprogress itotal / Ntotal
            end
        end
    end

    return bundle_samples(samples, model, sampler, state, chain_type; kwargs...)
end

"""
    mcmcsample([rng, ]model, sampler, isdone; kwargs...)

Continuously draw samples until a convergence criterion `isdone` returns `true`.

The function `isdone` has the signature
```julia
isdone(rng, model, sampler, samples, iteration; kwargs...)
```
and should return `true` when sampling should end, and `false` otherwise.

A callback function `f` with type signature
```julia
f(rng, model, sampler, sample, iteration)
```
may be provided as keyword argument `callback`. It is called after every sampling step.
"""
function mcmcsample(
    rng::Random.AbstractRNG,
    model::AbstractModel,
    sampler::AbstractSampler,
    isdone;
    chain_type::Type=Any,
    progress = true,
    progressname = "Convergence sampling",
    callback = nothing,
    discard_initial = 0,
    thinning = 1,
    kwargs...
)
    @ifwithprogresslogger progress name=progressname begin
        # Obtain the initial sample and state.
        sample, state = step(rng, model, sampler; kwargs...)

        # Discard initial samples.
        for _ in 2:discard_initial
            # Obtain the next sample and state.
            sample, state = step(rng, model, sampler, state; kwargs...)
        end

        # Run callback.
        callback === nothing || callback(rng, model, sampler, sample, 1)

        # Save the sample.
        samples = AbstractMCMC.samples(sample, model, sampler; kwargs...)
        samples = save!!(samples, sample, 1, model, sampler; kwargs...)

        # Step through the sampler until stopping.
        i = 2

        while !isdone(rng, model, sampler, samples, i; progress=progress, kwargs...)
            # Discard thinned samples.
            for _ in 1:(thinning - 1)
                # Obtain the next sample and state.
                sample, state = step(rng, model, sampler, state; kwargs...)
            end

            # Obtain the next sample and state.
            sample, state = step(rng, model, sampler, state; kwargs...)

            # Run callback.
            callback === nothing || callback(rng, model, sampler, sample, i)

            # Save the sample.
            samples = save!!(samples, sample, i, model, sampler; kwargs...)

            # Increment iteration counter.
            i += 1
        end
    end

    # Wrap the samples up.
    return bundle_samples(samples, model, sampler, state, chain_type; kwargs...)
end

"""
    mcmcsample([rng, ]model, sampler, parallel, N, nchains; kwargs...)

Sample `nchains` chains in parallel using the `parallel` algorithm, and combine them into a
single chain.
"""
function mcmcsample(
    rng::Random.AbstractRNG,
    model::AbstractModel,
    sampler::AbstractSampler,
    ::MCMCThreads,
    N::Integer,
    nchains::Integer;
    progress = true,
    progressname = "Sampling ($(min(nchains, Threads.nthreads())) threads)",
    kwargs...
)
    # Check if actually multiple threads are used.
    if Threads.nthreads() == 1
        @warn "Only a single thread available: MCMC chains are not sampled in parallel"
    end

    # Check if the number of chains is larger than the number of samples
    if nchains > N
        @warn "Number of chains ($nchains) is greater than number of samples per chain ($N)"
    end

    # Copy the random number generator, model, and sample for each thread
    # NOTE: As of May 17, 2020, this relies on Julia's thread scheduling functionality
    #       that distributes a for loop into equal-sized blocks and allocates them
    #       to each thread. If this changes, we may need to rethink things here.
    interval = 1:min(nchains, Threads.nthreads())
    rngs = [deepcopy(rng) for _ in interval]
    models = [deepcopy(model) for _ in interval]
    samplers = [deepcopy(sampler) for _ in interval]

    # Create a seed for each chain using the provided random number generator.
    seeds = rand(rng, UInt, nchains)

    # Set up a chains vector.
    chains = Vector{Any}(undef, nchains)

    @ifwithprogresslogger progress name=progressname begin
        # Create a channel for progress logging.
        if progress
            channel = Distributed.RemoteChannel(() -> Channel{Bool}(nchains))
        end

        Distributed.@sync begin
            if progress
                Distributed.@async begin
                    # Update the progress bar.
                    progresschains = 0
                    while take!(channel)
                        progresschains += 1
                        ProgressLogging.@logprogress progresschains/nchains
                    end
                end
            end

            Distributed.@async begin
                try
                    Threads.@threads for i in 1:nchains
                        # Obtain the ID of the current thread.
                        id = Threads.threadid()

                        # Seed the thread-specific random number generator with the pre-made seed.
                        subrng = rngs[id]
                        Random.seed!(subrng, seeds[i])

                        # Sample a chain and save it to the vector.
                        chains[i] = StatsBase.sample(subrng, models[id], samplers[id], N;
                                                     progress = false, kwargs...)

                        # Update the progress bar.
                        progress && put!(channel, true)
                    end
                finally
                    # Stop updating the progress bar.
                    progress && put!(channel, false)
                end
            end
        end
    end

    # Concatenate the chains together.
    return chainsstack(tighten_eltype(chains))
end

function mcmcsample(
    rng::Random.AbstractRNG,
    model::AbstractModel,
    sampler::AbstractSampler,
    ::MCMCDistributed,
    N::Integer,
    nchains::Integer;
    progress = true,
    progressname = "Sampling ($(Distributed.nworkers()) processes)",
    kwargs...
)
    # Check if actually multiple processes are used.
    if Distributed.nworkers() == 1
        @warn "Only a single process available: MCMC chains are not sampled in parallel"
    end

    # Check if the number of chains is larger than the number of samples
    if nchains > N
        @warn "Number of chains ($nchains) is greater than number of samples per chain ($N)"
    end

    # Create a seed for each chain using the provided random number generator.
    seeds = rand(rng, UInt, nchains)

    # Set up worker pool.
    pool = Distributed.CachingPool(Distributed.workers())

    # Create a channel for progress logging.
    channel = progress ? Distributed.RemoteChannel(() -> Channel{Bool}(nchains)) : nothing

    local chains
    @ifwithprogresslogger progress name=progressname begin
        Distributed.@sync begin
            # Update the progress bar.
            if progress
                Distributed.@async begin
                    progresschains = 0
                    while take!(channel)
                        progresschains += 1
                        ProgressLogging.@logprogress progresschains/nchains
                    end
                end
            end

            Distributed.@async begin
                try
                    chains = Distributed.pmap(pool, seeds) do seed
                        # Seed a new random number generator with the pre-made seed.
                        Random.seed!(rng, seed)

                        # Sample a chain.
                        chain = StatsBase.sample(rng, model, sampler, N;
                                                 progress = false, kwargs...)

                        # Update the progress bar.
                        channel === nothing || put!(channel, true)

                        # Return the new chain.
                        return chain
                    end
                finally
                    # Stop updating the progress bar.
                    progress && put!(channel, false)
                end
            end
        end
    end

    # Concatenate the chains together.
    return chainsstack(tighten_eltype(chains))
end

tighten_eltype(x) = x
tighten_eltype(x::Vector{Any}) = map(identity, x)
