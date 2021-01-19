@testset "sample.jl" begin
    @testset "Basic sampling" begin
        @testset "REPL" begin
            empty!(LOGGERS)

            Random.seed!(1234)
            N = 1_000
            chain = sample(MyModel(), MySampler(), N; sleepy = true, loggers = true)

            @test length(LOGGERS) == 1
            logger = first(LOGGERS)
            @test logger isa TeeLogger
            @test logger.loggers[1].logger isa (Sys.iswindows() ? ProgressLogger : TerminalLogger)
            @test logger.loggers[2].logger === CURRENT_LOGGER
            @test Logging.current_logger() === CURRENT_LOGGER

            # test output type and size
            @test chain isa Vector{<:MySample}
            @test length(chain) == N

            # test some statistical properties
            tail_chain = @view chain[2:end]
            @test mean(x.a for x in tail_chain) ≈ 0.5 atol=6e-2
            @test var(x.a for x in tail_chain) ≈ 1 / 12 atol=5e-3
            @test mean(x.b for x in tail_chain) ≈ 0.0 atol=5e-2
            @test var(x.b for x in tail_chain) ≈ 1 atol=6e-2
        end

        @testset "Juno" begin
            empty!(LOGGERS)

            Random.seed!(1234)
            N = 10

            logger = JunoProgressLogger()
            Logging.with_logger(logger) do
                sample(MyModel(), MySampler(), N; sleepy = true, loggers = true)
            end

            @test length(LOGGERS) == 1
            @test first(LOGGERS) === logger
            @test Logging.current_logger() === CURRENT_LOGGER
        end

        @testset "IJulia" begin
            # emulate running IJulia kernel
            @eval IJulia begin
                inited = true
            end

            empty!(LOGGERS)

            Random.seed!(1234)
            N = 10
            sample(MyModel(), MySampler(), N; sleepy = true, loggers = true)

            @test length(LOGGERS) == 1
            logger = first(LOGGERS)
            @test logger isa TeeLogger
            @test logger.loggers[1].logger isa ProgressLogger
            @test logger.loggers[2].logger === CURRENT_LOGGER
            @test Logging.current_logger() === CURRENT_LOGGER

            @eval IJulia begin
                inited = false
            end
        end

        @testset "Custom logger" begin
            empty!(LOGGERS)

            Random.seed!(1234)
            N = 10

            logger = Logging.ConsoleLogger(stderr, Logging.LogLevel(-1))
            Logging.with_logger(logger) do
                sample(MyModel(), MySampler(), N; sleepy = true, loggers = true)
            end

            @test length(LOGGERS) == 1
            @test first(LOGGERS) === logger
            @test Logging.current_logger() === CURRENT_LOGGER
        end

        @testset "Suppress output" begin
            logs, _ = collect_test_logs(; min_level=Logging.LogLevel(-1)) do
                sample(MyModel(), MySampler(), 100; progress = false, sleepy = true)
            end
            @test all(l.level > Logging.LogLevel(-1) for l in logs)
        end
    end

    if VERSION ≥ v"1.3"
        @testset "Multithreaded sampling" begin
            if Threads.nthreads() == 1
                warnregex = r"^Only a single thread available"
                @test_logs (:warn, warnregex) sample(MyModel(), MySampler(), MCMCThreads(),
                                                     10, 10)
            end

            # No dedicated chains type
            N = 10_000
            chains = sample(MyModel(), MySampler(), MCMCThreads(), N, 1000)
            @test chains isa Vector{<:Vector{<:MySample}}
            @test length(chains) == 1000
            @test all(length(x) == N for x in chains)

            Random.seed!(1234)
            chains = sample(MyModel(), MySampler(), MCMCThreads(), N, 1000;
                            chain_type = MyChain)

            # test output type and size
            @test chains isa Vector{<:MyChain}
            @test length(chains) == 1000
            @test all(x -> length(x.as) == length(x.bs) == N, chains)

            # test some statistical properties
            @test all(x -> isapprox(mean(@view x.as[2:end]), 0.5; atol=5e-2), chains)
            @test all(x -> isapprox(var(@view x.as[2:end]), 1 / 12; atol=5e-3), chains)
            @test all(x -> isapprox(mean(@view x.bs[2:end]), 0; atol=5e-2), chains)
            @test all(x -> isapprox(var(@view x.bs[2:end]), 1; atol=5e-2), chains)

            # test reproducibility
            Random.seed!(1234)
            chains2 = sample(MyModel(), MySampler(), MCMCThreads(), N, 1000;
                             chain_type = MyChain)

            @test all(c1.as[i] === c2.as[i] for (c1, c2) in zip(chains, chains2), i in 1:N)
            @test all(c1.bs[i] === c2.bs[i] for (c1, c2) in zip(chains, chains2), i in 1:N)

            # Unexpected order of arguments.
            str = "Number of chains (10) is greater than number of samples per chain (5)"
            @test_logs (:warn, str) match_mode=:any sample(MyModel(), MySampler(),
                                                           MCMCThreads(), 5, 10;
                                                           chain_type = MyChain)

            # Suppress output.
            logs, _ = collect_test_logs(; min_level=Logging.LogLevel(-1)) do
                sample(MyModel(), MySampler(), MCMCThreads(), 10_000, 1000;
                        progress = false, chain_type = MyChain)
            end
            @test all(l.level > Logging.LogLevel(-1) for l in logs)
            
            # Smoke test for nchains < nthreads
            if Threads.nthreads() == 2
                sample(MyModel(), MySampler(), MCMCThreads(), N, 1) 
            end
        end
    end

    @testset "Multicore sampling" begin
        if nworkers() == 1
            warnregex = r"^Only a single process available"
            @test_logs (:warn, warnregex) sample(MyModel(), MySampler(), MCMCDistributed(),
                                                 10, 10; chain_type = MyChain)
        end

        # Add worker processes.
        addprocs()

        # Load all required packages (`interface.jl` needs Random).
        @everywhere begin
            using AbstractMCMC
            using AbstractMCMC: sample

            using Random
            include("utils.jl")
        end

        # No dedicated chains type
        N = 10_000
        chains = sample(MyModel(), MySampler(), MCMCThreads(), N, 1000)
        @test chains isa Vector{<:Vector{<:MySample}}
        @test length(chains) == 1000
        @test all(length(x) == N for x in chains)

        Random.seed!(1234)
        chains = sample(MyModel(), MySampler(), MCMCDistributed(), N, 1000;
                        chain_type = MyChain)

        # Test output type and size.
        @test chains isa Vector{<:MyChain}
        @test all(c.as[1] === missing for c in chains)
        @test length(chains) == 1000
        @test all(x -> length(x.as) == length(x.bs) == N, chains)

        # Test some statistical properties.
        @test all(x -> isapprox(mean(@view x.as[2:end]), 0.5; atol=5e-2), chains)
        @test all(x -> isapprox(var(@view x.as[2:end]), 1 / 12; atol=5e-3), chains)
        @test all(x -> isapprox(mean(@view x.bs[2:end]), 0; atol=5e-2), chains)
        @test all(x -> isapprox(var(@view x.bs[2:end]), 1; atol=5e-2), chains)

        # Test reproducibility.
        Random.seed!(1234)
        chains2 = sample(MyModel(), MySampler(), MCMCDistributed(), N, 1000;
                         chain_type = MyChain)

        @test all(c1.as[i] === c2.as[i] for (c1, c2) in zip(chains, chains2), i in 1:N)
        @test all(c1.bs[i] === c2.bs[i] for (c1, c2) in zip(chains, chains2), i in 1:N)

        # Unexpected order of arguments.
        str = "Number of chains (10) is greater than number of samples per chain (5)"
        @test_logs (:warn, str) match_mode=:any sample(MyModel(), MySampler(),
                                                       MCMCDistributed(), 5, 10;
                                                       chain_type = MyChain)

        # Suppress output.
        logs, _ = collect_test_logs(; min_level=Logging.LogLevel(-1)) do
            sample(MyModel(), MySampler(), MCMCDistributed(), 10_000, 100;
                   progress = false, chain_type = MyChain)
        end
        @test all(l.level > Logging.LogLevel(-1) for l in logs)
    end

    @testset "Chain constructors" begin
        chain1 = sample(MyModel(), MySampler(), 100; sleepy = true)
        chain2 = sample(MyModel(), MySampler(), 100; sleepy = true, chain_type = MyChain)

        @test chain1 isa Vector{<:MySample}
        @test chain2 isa MyChain
    end

    @testset "Discard initial samples" begin
        chain = sample(MyModel(), MySampler(), 100; sleepy = true, discard_initial = 50)
        @test length(chain) == 100
        @test !ismissing(chain[1].a)
    end

    @testset "Thin chain by a factor of `thinning`" begin
        # Run a thinned chain with `N` samples thinned by factor of `thinning`.
        Random.seed!(1234)
        N = 100
        thinning = 3
        chain = sample(MyModel(), MySampler(), N; sleepy = true, thinning = thinning)
        @test length(chain) == N
        @test ismissing(chain[1].a)

        # Repeat sampling without thinning.
        Random.seed!(1234)
        ref_chain = sample(MyModel(), MySampler(), N * thinning; sleepy = true)
        @test all(chain[i].a === ref_chain[(i - 1) * thinning + 1].a for i in 1:N)
    end


    @testset "Sample without predetermined N" begin
        Random.seed!(1234)
        chain = sample(MyModel(), MySampler())
        bmean = mean(x.b for x in chain)
        @test ismissing(chain[1].a)
        @test abs(bmean) <= 0.001 && length(chain) < 10_000

        # Discard initial samples.
        chain = sample(MyModel(), MySampler(); discard_initial = 50)
        bmean = mean(x.b for x in chain)
        @test !ismissing(chain[1].a)
        @test abs(bmean) <= 0.001 && length(chain) < 10_000

        # Thin chain by a factor of `thinning`.
        chain = sample(MyModel(), MySampler(); thinning = 3)
        bmean = mean(x.b for x in chain)
        @test ismissing(chain[1].a)
        @test abs(bmean) <= 0.001 && length(chain) < 10_000
    end

    @testset "Sample vector of `NamedTuple`s" begin
        chain = sample(MyModel(), MySampler(), 1_000; chain_type = Vector{NamedTuple})
        # Check output type
        @test chain isa Vector{<:NamedTuple}
        @test length(chain) == 1_000
        @test all(keys(x) == (:a, :b) for x in chain)

        # Check some statistical properties
        @test ismissing(chain[1].a)
        @test mean(x.a for x in view(chain, 2:1_000)) ≈ 0.5 atol=6e-2
        @test var(x.a for x in view(chain, 2:1_000)) ≈ 1 / 12 atol=1e-2
        @test mean(x.b for x in chain) ≈ 0 atol=0.1
        @test var(x.b for x in chain) ≈ 1 atol=0.15
    end
end
