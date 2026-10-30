using Gurobi
using GenX

run_genx_case!(dirname(@__FILE__), Gurobi.Optimizer)
