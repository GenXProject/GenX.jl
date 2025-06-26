using GenX, Gurobi

run_genx_case!(dirname(@__FILE__), Gurobi.Optimizer)
