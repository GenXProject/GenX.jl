@doc raw"""
	write_status(path::AbstractString, inputs::Dict, EP::Model)

Function for writing the final solve status of the optimization problem solved.
"""
function write_status(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

    # https://jump.dev/MathOptInterface.jl/v0.9.10/apireference/#MathOptInterface.TerminationStatusCode
    status = termination_status(EP)

    # Note: Gurobi excludes constants from solver reported objective function value - MIPGap calculated may be erroneous
    if (setup["UCommit"] == 0 || setup["UCommit"] == 2)
        dfStatus = DataFrame(Status = status, Solve = inputs["solve_time"],
            Objval = objective_value(EP))
    else
        dfStatus = DataFrame(Status = status, Solve = inputs["solve_time"],
            Objval = objective_value(EP), Objbound = objective_bound(EP),
            FinalMIPGap = (objective_value(EP) - objective_bound(EP)) / objective_value(EP))
    end
    CSV.write(joinpath(path, "status.csv"), dfStatus)
end
