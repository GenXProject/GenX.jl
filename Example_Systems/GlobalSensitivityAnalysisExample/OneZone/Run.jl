using Pkg
Pkg.activate("C:/Users/pecci/Code/GenX/")

using GenX

case = dirname(@__FILE__);
run_genx_case!(dirname(@__FILE__))
