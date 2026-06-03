module GenXGurobiExt

import GenX
import Gurobi
import JuMP: optimizer_with_attributes

const _LOCK = ReentrantLock()

function __init__()
    lock(_LOCK) do
        if isnothing(GenX.GRB_ENV[])
            GenX.GRB_ENV[] = Gurobi.Env()
        end
    end
end

"""
    GenX.benders_gurobi_optimizer(attributes::Dict)

Gurobi-backed implementation.  Returns an `OptimizerWithAttributes` that
creates a `Gurobi.Optimizer` sharing the module-level Gurobi environment.
"""
function GenX.benders_gurobi_optimizer(attributes::Dict)
    optimizer_with_attributes(() -> Gurobi.Optimizer(GenX.GRB_ENV[]), attributes...)
end

end
