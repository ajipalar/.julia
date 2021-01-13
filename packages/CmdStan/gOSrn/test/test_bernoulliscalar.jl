ProjDir = joinpath(dirname(@__FILE__), "..", "examples", "BernoulliScalar")
cd(ProjDir) do

  isdir("tmp") &&
    rm("tmp", recursive=true);

  include(joinpath(ProjDir, "bernoulliscalar.jl"))

  isdir("tmp") &&
    rm("tmp", recursive=true);

end # cd
