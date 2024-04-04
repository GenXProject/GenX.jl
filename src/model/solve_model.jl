@doc raw"""
	fix_integers(jump_model::Model)

This function fixes the iteger variables ones the model has been solved in order to calculate approximations of dual variables.

# Arguments
- `jump_model::Model`: a model object containing that has been previously solved.

# Returns
nothing (modifies an existing-solved model in the memory). `solve()` must be run again to solve and getdual veriables

"""
function fix_integers(jump_model::Model)
    ################################################################################
    ## function fix_integers()
    ##
    ## inputs: jump_model - a model object containing that has been previously solved.
    ##
    ## description: fixes the iteger variables ones the model has been solved in order
    ## to calculate approximations of dual variables
    ##
    ## returns: no result since it modifies an existing-solved model in the memory.
    ## solve() must be run again to solve and getdual veriables
    ##
    ################################################################################
    values = Dict(v => value(v) for v in all_variables(jump_model))
    for v in all_variables(jump_model)
        if is_integer(v)
            fix(v, values[v], force = true)
            unset_integer(v)
        elseif is_binary(v)
            fix(v, values[v], force = true)
            unset_binary(v)
        end
    end
end

@doc raw"""
	solve_model(EP::Model, setup::Dict)
Description: Solves and extracts solution variables for later processing

# Arguments
- `EP::Model`: a JuMP model representing the energy optimization problem
- `setup::Dict`: a Dict containing GenX setup flags

# Returns
- `EP::Model`: the solved JuMP model
- `solver_time::Float64`: time taken to solve the model
"""
function solve_model(EP::Model, setup::Dict)
    ## Start solve timer
    solver_start_time = time()
    solver_time = time()

    ## Solve Model
    optimize!(EP)

    if has_values(EP)
        if has_duals(EP) # fully linear model
            println("LP solved for primal")
        else
            println("MILP solved for primal")
        end

        ## Record solver time
        solver_time = time() - solver_start_time
    elseif setup["ComputeConflicts"] == 0
        @info "No model solution. You can try to set ComputeConflicts to 1 in the genx_settings.yml file to compute conflicting constraints."

    elseif setup["ComputeConflicts"] == 1
        @info "No model solution. Trying to identify conflicting constriants..."

        try
            compute_conflict!(EP)
        catch e
            if isa(e, JuMP.ArgumentError)
                @warn "$(solver_name(EP)) does not support computing conflicting constraints. This is available using either Gurobi or CPLEX."
                solver_time = time() - solver_start_time
                return EP, solver_time
            else
                rethrow(e)
            end
        end

        list_of_conflicting_constraints = ConstraintRef[]
        if get_attribute(EP, MOI.ConflictStatus()) == MOI.CONFLICT_FOUND
            for (F, S) in list_of_constraint_types(EP)
                for con in all_constraints(EP, F, S)
                    if get_attribute(con, MOI.ConstraintConflictStatus()) == MOI.IN_CONFLICT
                        push!(list_of_conflicting_constraints, con)
                    end
                end
            end
            display(list_of_conflicting_constraints)
            solver_time = time() - solver_start_time
            return EP, solver_time, list_of_conflicting_constraints
        else
            @info "Conflicts computation failed."
            solver_time = time() - solver_start_time
            return EP, solver_time, list_of_conflicting_constraints
        end
    end

    return EP, solver_time
end # END solve_model()
