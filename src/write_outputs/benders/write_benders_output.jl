function write_benders_output(LB_hist::Vector{Float64}, UB_hist::Vector{Float64}, cpu_time::Vector{Float64}, feasibility_hist::Vector{Float64}, outpath::AbstractString, setup::Dict, inputs::Dict, planning_problem::Model, subproblems::Union{Vector{Dict{Any, Any}},DistributedArrays.DArray})
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

    write_co2_emissions_plant(outpath, inputs, setup,
        collect_distributed_expressions(:eEmissionsByPlant, subproblems))

	write_power(outpath, inputs, setup, collect_distributed_expressions(:vP, subproblems))

    write_charge(outpath, inputs, setup, subproblems)
end

function write_co2_emissions_plant(path::AbstractString,
	inputs::Dict,
	setup::Dict,
	emissions_plant::Array)

	gen = inputs["RESOURCES"]  # Resources (objects)
	resources = inputs["RESOURCE_NAMES"] # Resource names
	zones = zone_id.(gen)

	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)

	weight = inputs["omega"]
	scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

	emissions_plant *= scale_factor

	df = DataFrame(Resource = resources,
		Zone = zones,
		AnnualSum = zeros(G))
	df.AnnualSum .= emissions_plant * weight

	write_temporal_data(df, emissions_plant, path, setup, "emissions_plant")
	return nothing
end


function write_power(path::AbstractString, inputs::Dict, setup::Dict, power::Matrix)
    gen = inputs["RESOURCES"]   # Resources (objects)
    resources = inputs["RESOURCE_NAMES"]    # Resource names
    zones = zone_id.(gen)

    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    
    weight = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    # Power injected by each resource in each time step
    power *= scale_factor

    df = DataFrame(Resource = resources,
        Zone = zones,
        AnnualSum = zeros(G))
    df.AnnualSum .= power * weight

    write_temporal_data(df, power, path, setup, "power")
    return df
end

function collect_distributed_expressions(expr_name::Symbol, subproblems)
    p_id = workers()
    np_id = length(p_id)
    flow_df = Vector{Array}(undef, np_id)
    @sync for i in 1:np_id
        @async flow_df[i] = @fetchfrom p_id[i] get_local_expressions(
            expr_name, DistributedArrays.localpart(subproblems))
    end
    return reduce(hcat, flow_df)
end

function get_local_expressions(expr_name::Symbol, subproblems_local::Vector{Dict{Any, Any}})
    n_local_subprob = length(subproblems_local)
    expr_subprob = Vector{Array}(undef, n_local_subprob)
    for s in eachindex(subproblems_local)
        EP = subproblems_local[s]["Model"]
        if !haskey(EP, expr_name)
            @warn "Expression $expr_name not found in subproblem $s"
            continue
        end
        expr_subprob[s] = value.(EP[expr_name])
    end
	reduce(vcat, expr_subprob)
end

function write_charge(path::AbstractString, inputs::Dict, setup::Dict, subproblems::Union{Vector{Dict{Any, Any}},DistributedArrays.DArray})
    gen = inputs["RESOURCES"]   # Resources (objects) 
    resources = inputs["RESOURCE_NAMES"]    # Resource names
    zones = zone_id.(gen)

    weight = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

	p_id = workers()
	np_id = length(p_id)
	charge_subprob = Vector{Matrix}(undef, np_id)
	charge_ids_subprob = Vector{Vector{Int}}(undef, np_id)
	@sync for i in 1:np_id
		@async begin
			result = @fetchfrom p_id[i] get_local_charge(inputs, setup, DistributedArrays.localpart(subproblems))
			charge_subprob[i] = result[1]
			charge_ids_subprob[i] = result[2]
		end
	end

	charge = reduce(hcat, charge_subprob)
	for s in eachindex(charge_ids_subprob)
		@assert charge_ids_subprob[s] == charge_ids_subprob[1] "Charge ids are not the same across all subproblems"
	end
	charge_ids = charge_ids_subprob[1]

	charge *= scale_factor

    df = DataFrame(Resource = resources[charge_ids],
        Zone = zones[charge_ids])
    df.AnnualSum = charge * weight

    write_temporal_data(df, charge, path, setup, "charge")
    return nothing
end

function get_local_charge(inputs::Dict, setup::Dict, subproblems_local)
	gen = inputs["RESOURCES"]   # Resources (objects) 

	n_local_subprob = length(subproblems_local)
	charge_subprob = Vector{Matrix}(undef, n_local_subprob)
	charge_ids_subprob = Vector{Vector{Int}}(undef, n_local_subprob)

	H = inputs["H"]     # Number of time steps (hours)
    STOR_ALL = inputs["STOR_ALL"]
    FLEX = inputs["FLEX"]
    ELECTROLYZER = inputs["ELECTROLYZER"]
    ALLAM_CYCLE_LOX = inputs["ALLAM_CYCLE_LOX"] 
    VRE_STOR = inputs["VRE_STOR"]
    VS_STOR = !isempty(VRE_STOR) ? inputs["VS_STOR"] : []
    FUSION = ids_with(gen, :fusion)

	for s in eachindex(subproblems_local)
		EP = subproblems_local[s]["Model"]
		charge = Matrix[]
		charge_ids = Vector{Int}[]

		if !isempty(STOR_ALL)
			push!(charge, value.(EP[:vCHARGE]))
			push!(charge_ids, STOR_ALL)
		end
		if !isempty(FLEX)
			push!(charge, value.(EP[:vCHARGE_FLEX]))
			push!(charge_ids, FLEX)
		end
		if (setup["HydrogenMinimumProduction"] > 0) & (!isempty(ELECTROLYZER))
			push!(charge, value.(EP[:vUSE]))
			push!(charge_ids, ELECTROLYZER)
		end
		if !isempty(VS_STOR)
			push!(charge, value.(EP[:vCHARGE_VRE_STOR]))
			push!(charge_ids, VS_STOR)
		end
		if !isempty(FUSION)
			_, mat = prepare_fusion_parasitic_power(EP, inputs)
			push!(charge, mat)
			push!(charge_ids, FUSION)
		end
		if !isempty(ALLAM_CYCLE_LOX)
			push!(charge, value.(EP[:vCHARGE_ALLAM]))
			push!(charge_ids, ALLAM_CYCLE_LOX)
		end
		charge_subprob[s] = reduce(vcat, charge, init = zeros(0, H))
		charge_ids_subprob[s] = reduce(vcat, charge_ids, init = Int[])
	end

	charge_subprob = reduce(hcat, charge_subprob)
	# check that all charge_ids_subprob are the same across all subproblems
	for s in eachindex(charge_ids_subprob)
		@assert charge_ids_subprob[s] == charge_ids_subprob[1] "Charge ids are not the same across all subproblems"
	end
	charge_ids = charge_ids_subprob[1]
	return charge_subprob, charge_ids
end