using Pkg
Pkg.activate("C:/Users/pecci/Code/GenX/")

using Distributed
addprocs(4)

@everywhere begin
    import Pkg
    Pkg.activate("C:/Users/pecci/Code/GenX")
end

@everywhere using GenX

run_genx_case!(dirname(@__FILE__))
