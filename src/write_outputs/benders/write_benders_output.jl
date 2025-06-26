function write_benders_output(LB_hist::Vector{Float64},UB_hist::Vector{Float64},cpu_time::Vector{Float64},feasibility_hist::Vector{Float64},outpath::AbstractString, setup::Dict,inputs::Dict,planning_problem::Model)
	println("Running with crossover on")
	set_attribute(planning_problem, "Crossover", 1)
	optimize!(planning_problem)
	
	dfConv = DataFrame(Iter = 1:length(LB_hist),CPU_Time = cpu_time, LB = LB_hist, UB  = UB_hist, Gap = (UB_hist.-LB_hist)./LB_hist,Feasibility=feasibility_hist)
	
	if !has_values(planning_problem)
		set_attribute(planning_problem, "Crossover", 1)
		optimize!(planning_problem)
	end
	
	#write_planning_solution(outpath, inputs, setup, planning_problem)
	
	elapsed_time_capacity = @elapsed dfCap = write_capacity(outpath, inputs, setup, planning_problem)
	println("Time elapsed for writing capacity is")
	println(elapsed_time_capacity)

	
	if inputs["Z"] > 1
		if setup["NetworkExpansion"] == 1
	            elapsed_time_expansion = @elapsed write_nw_expansion(outpath, inputs, setup, planning_problem)
	            println("Time elapsed for writing network expansion is")
	            println(elapsed_time_expansion)
	        end
    	end
	if setup["MinCapReq"] == 1 && has_duals(planning_problem) == 1
		elapsed_time_min_cap_req = @elapsed write_minimum_capacity_requirement(outpath,inputs,setup,planning_problem)
		println("Time elapsed for writing minimum capacity requirement is")
		println(elapsed_time_min_cap_req)
	end
	if setup["MaxCapReq"] == 1 && has_duals(planning_problem) == 1
		elapsed_time_max_cap_req = @elapsed write_maximum_capacity_requirement(outpath,inputs,setup,planning_problem)
		println("Time elapsed for writing maximum capacity requirement is")
		println(elapsed_time_max_cap_req)
	end
	
	write_planning_problem_costs(outpath,
	inputs,
	setup,
	planning_problem)
	CSV.write(joinpath(outpath, "benders_convergence.csv"),dfConv)
	YAML.write_file(joinpath(outpath, "run_settings.yml"),setup)
end

