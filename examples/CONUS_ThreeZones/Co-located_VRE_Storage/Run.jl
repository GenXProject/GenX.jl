using GenX
using Gurobi

optim = Gurobi.Optimizer

run_genx_case!(dirname(@__FILE__), optim)
