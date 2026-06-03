@doc raw"""
	write_status(path::AbstractString, inputs::Dict, EP::Model)

Function for writing the final solve status of the optimization problem solved.
"""
function write_status(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

    # https://jump.dev/MathOptInterface.jl/v0.9.10/apireference/#MathOptInterface.TerminationStatusCode
    status = termination_status(EP)
    has_solution = has_values(EP)
    objval = has_solution ? objective_value(EP) : missing

    # Note: Gurobi excludes constants from solver reported objective function value - MIPGap calculated may be erroneous
    if (setup["UCommit"] == 0 || setup["UCommit"] == 2)
        dfStatus = DataFrame(Status = status,
            Objval = objval)
    else
        objbound = has_solution ? objective_bound(EP) : missing
        final_mip_gap = has_solution ? (objval - objbound) / objval : missing
        dfStatus = DataFrame(Status = status,
            Objval = objval, Objbound = objbound,
            FinalMIPGap = final_mip_gap)
    end
    CSV.write(joinpath(path, "status.csv"), dfStatus)
end
