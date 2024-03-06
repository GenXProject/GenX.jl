## Using commercial solvers: Gurobi or CPLEX

If you want to use the commercial solvers Gurobi or CPLEX:

- Make sure you have a valid license and the actual solvers for either of Gurobi or CPLEX installed on your machine
- Add Gurobi or CPLEX to the Julia Project.

```
$ julia --project=/home/youruser/GenX

julia> <press close-bracket ] to access the package manager>
(GenX) pkg> add Gurobi
-or-
(GenX) pkg> add CPLEX
```
```@meta
#TODO: Add instructions for adding Gurobi or CPLEX to the Julia Project with the new PR. 
```

- Edit the `Run.jl` file to use the commercial solver. For example, to use Gurobi, you can add the following lines to the `Run.jl` file:

```julia
using Gurobi
using GenX

run_genx_case!(dirname(@__FILE__), Gurobi.Optimizer)
```

!!! warning "Warning"
    Note that if you have not already installed the required Julia packages or you do not have a valid Gurobi license on your host machine, you will receive an error message and Run.jl will not run to completion.