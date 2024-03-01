using GenX
using Gurobi

run_genx_case!(dirname(@__FILE__), Gurobi.Optimizer)