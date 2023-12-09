"""
GenX: An Configurable Capacity Expansion Model
Copyright (C) 2021,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

@doc raw"""
	fix_integers(jump_model::Model)

inputs: jump_model - a model object containing that has been previously solved.

description: fixes the iteger variables ones the model has been solved in order to calculate approximations of dual variables

returns: none (modifies an existing-solved model in the memory). solve() must be run again to solve and getdual veriables

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
            fix(v,values[v],force=true)
			unset_integer(v)
        elseif is_binary(v)
            fix(v,values[v],force=true)
			unset_binary(v)
        end
	end
end

@doc raw"""
	function solve_model()

inputs: EP - a JuMP model representing the energy optimization problem
setup - a Dict containing GenX setup flags

description: Solves and extracts solution variables for later processing

returns: results EP model object with a set of DataFrames containing key results
"""
function solve_model(EP::Model, setup::Dict)
	################################################################################
	## function solve_model()
	##
	## inputs: EP - a JuMP model representing the energy optimization problem
	## setup - a Dict containing GenX setup flags
	##
	## description: Solves and extracts solution variables for later processing
	##
	## returns: results EP model object with a set of DataFrames containing key results
	##
	################################################################################
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

		if !has_duals(EP) && setup["WriteShadowPrices"] == 1
			# function to fix integers and linearize problem
			fix_integers(EP)
			# re-solve statement for LP solution
			println("Solving LP solution for duals")
			optimize!(EP)
		end

		## Record solver time
		solver_time = time() - solver_start_time
	elseif setup["ComputeConflicts"]==0

		@info "No model solution. You can try to set ComputeConflicts to 1 in the genx_settings.yml file to compute conflicting constraints."

	elseif setup["ComputeConflicts"]==1

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