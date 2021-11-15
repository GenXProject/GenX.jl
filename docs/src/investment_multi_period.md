# Investment multi period
```@autodocs
Modules = [GenX]
Pages = ["investment_multi_period.jl"]
```
# Storage multi period
```@autodocs
Modules = [GenX]
Pages = ["storage_multi_period.jl"]
```

# Transmission multi period
```@autodocs
Modules = [GenX]
Pages = ["transmission_multi_period.jl"]
```

## Suggested Reading
The solution strategy implemented for solving the multi-period investment planning model follows the decomposition algorithm described in [Lara et al, Deterministic electric power infrastructure planning: Mixed-integer programming model and nested decomposition algorithm, European Journal of Operations Research, 271(3), 1037-1054, 2018](https://www.sciencedirect.com/science/article/pii/S0377221718304466). The decompositionb algorithm adapts previous nested Benders methods by handling integer and continuous state variables, although at the expense of losing its finite convergence property due to potential duality gap.
