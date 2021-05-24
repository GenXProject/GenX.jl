## SolveModel.jl: Solving Model Module

@doc raw"""
	fix_integers(jump_model::Model)

inputs: jump_model - a model object containing that has been previously solved.

description: fixes the iteger variables ones the model has been solved in order to calculate approximations of dual variables

returns: none (modifies an existing-solved model in the memory). solve() must be run again to solve and getdual veriables

"""
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
function fix_integers(jump_model::Model)
	for v in all_variables(jump_model)
		if is_integer(v)
            unset_integer(v)
            fix(v,value(v),force=true)
        elseif is_binary(v)
            unset_binary(v)
            fix(v,value(v),force=true)
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
function solve_model(EP::Model, setup::Dict)

	## Start solve timer
	solver_start_time = time()
	solver_time = time()

	## Solve Model
	optimize!(EP)

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
	
	return EP, solver_time
end # END solve_model()