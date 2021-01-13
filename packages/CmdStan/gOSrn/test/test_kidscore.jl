ProjDir = joinpath(dirname(@__FILE__), "..", "examples", "ARM", "Ch03", "Kid")
cd(ProjDir) do

  isdir("tmp") &&
    rm("tmp", recursive=true);

  include(joinpath(ProjDir, "kidscore.jl"))

  isdir("tmp") &&
    rm("tmp", recursive=true);

end # cd
