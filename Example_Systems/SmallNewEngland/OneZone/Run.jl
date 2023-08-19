using GenX, Gurobi, MathOptInterface

optimizer=Gurobi.Optimizer

run_genx_case!(dirname(@__FILE__),optimizer)
