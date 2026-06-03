# function write_benders_convergence(case_path::AbstractString, bd_results::BendersResults)
    
#     number_of_iterations = length(bd_results.LB_hist)

#     dfConv = DataFrame(Iter = 1:number_of_iterations, CPU_Time = bd_results.cpu_time, LB = bd_results.LB_hist, UB  = bd_results.UB_hist, Gap = bd_results.gap_hist, Status = append!([bd_results.termination_status],repeat([""],number_of_iterations-1)))
    
#     CSV.write(joinpath(case_path, "benders_convergence.csv"), dfConv)
# end

# function prepare_costs_benders(system::System, 
#     bd_results::BendersResults, 
#     subop_indices::Vector{Int64}, 
#     settings::NamedTuple
# )
#     planning_problem = bd_results.planning_problem
#     subop_sol = bd_results.subop_sol
#     planning_variable_values = bd_results.planning_sol.values

#     create_discounted_cost_expressions!(planning_problem, system, settings)
#     compute_undiscounted_costs!(planning_problem, system, settings)

#     # Evaluate the fixed cost expressions in the planning problem. Note that this expression has been re-built
#     # in compute_undiscounted_costs! to utilize undiscounted costs and the Benders planning solutions that are 
#     # stored in system. So, no need to re-evaluate the expression on planning_variable_values.
#     fixed_cost = value(planning_problem[:eFixedCost])
#     # Evaluate the discounted fixed cost expression on the Benders planning solutions
#     discounted_fixed_cost = value(x -> planning_variable_values[name(x)], planning_problem[:eDiscountedFixedCost])

#     #### Get variables costs from subproblem solutions and apply undiscounting
#     variable_cost, discounted_variable_cost = compute_benders_variable_costs(subop_sol, subop_indices, system, settings)

#     return (
#         eFixedCost = fixed_cost,
#         eVariableCost = variable_cost,
#         eDiscountedFixedCost = discounted_fixed_cost,
#         eDiscountedVariableCost = discounted_variable_cost
#     )
# end

# function compute_benders_variable_costs(subop_sol::Dict, subop_indices::Vector{Int64}, system::System, settings::NamedTuple)

#     period_lengths = collect(settings.PeriodLengths)
#     discount_rate = settings.DiscountRate
#     period_index = system.time_data[:Electricity].period_index;

#     discounted_variable_cost = sum(subop_sol[w].op_cost for w in subop_indices)

#     period_start_year = total_years(period_lengths[1:period_index-1])
#     discount_factor = present_value_factor(discount_rate, period_start_year)
#     opexmult = present_value_annuity_factor(discount_rate, period_lengths[period_index])
#     variable_cost = period_lengths[period_index] * discounted_variable_cost / (discount_factor * opexmult)

#     return variable_cost, discounted_variable_cost
# end
    
# """
#     collect_data_from_subproblems(case::Case, bd_results::BendersResults; scaling::Float64=1.0)

# Collect all data from all Benders subproblems, handling both distributed and local cases.
# Returns a `SubproblemsData` struct whose fields (`.flows`, `.storage_levels`, `.nsd`, `.operational_costs`)
# are `Vector{DataFrame}` with one element per Benders subproblem.
# """
# function collect_data_from_subproblems(case::Case, bd_results::BendersResults; scaling::Float64=1.0)
#     if case.settings.BendersSettings[:Distributed]
#         return collect_distributed_data(bd_results, scaling)
#     else
#         return collect_local_data(bd_results, scaling)
#     end
# end


# """
# Collect all data from distributed Benders subproblems.
# Returns a `SubproblemsData` with one DataFrame per Benders subproblem in each field.
# """
# function collect_distributed_data(bd_results::BendersResults, scaling::Float64=1.0)
#     p_id = workers()
#     np_id = length(p_id)
#     result_chunks = Vector{Vector{NamedTuple}}(undef, np_id)

#     @sync for i in 1:np_id
#         @async result_chunks[i] = @fetchfrom p_id[i] begin
#             local_subproblems = DistributedArrays.localpart(bd_results.op_subproblem)
#             [extract_subproblem_results(sp[:system_local]; scaling=scaling) for sp in local_subproblems]
#         end
#     end

#     return SubproblemsData(reduce(vcat, result_chunks))
# end


# """
# Collect all data from local Benders subproblems.
# Returns a `SubproblemsData` with one DataFrame per Benders subproblem in each field.
# """
# function collect_local_data(bd_results::BendersResults, scaling::Float64=1.0)
#     n = length(bd_results.op_subproblem)
#     results = SubproblemsData(n)

#     for i in eachindex(bd_results.op_subproblem)
#         system = bd_results.op_subproblem[i][:system_local]
#         results[i] = extract_subproblem_results(system; scaling)
#     end

#     return results
# end

# ###################################
# # Subproblem Results Data Structure
# ###################################

# """
#     SubproblemsData

# Struct holding results from all Benders subproblems, with one vector per output type.
# Each vector has one `DataFrame` per subproblem (same ordering). Use `.flows`, `.storage_levels`,
# `.nsd`, and `.operational_costs` for write functions.

# # Fields
# - `flows::Vector{DataFrame}`: Flow time-series, one DataFrame per subproblem
# - `storage_levels::Vector{DataFrame}`: Storage level time-series, one per subproblem
# - `nsd::Vector{DataFrame}`: Non-served demand time-series, one per subproblem
# - `curtailment::Vector{DataFrame}`: VRE curtailment time-series, one per subproblem
# - `operational_costs::Vector{DataFrame}`: Operational costs (VariableOM, Fuel, Startup, NSD, Supply, Slack), one per subproblem

# # Indexing and iteration
# - `subproblems_data[i]` returns a NamedTuple `(flows=..., storage_levels=..., nsd=..., operational_costs=..., curtailment=...)` for subproblem `i`
# - `for d in subproblems_data` yields that NamedTuple for each subproblem
# - Supports `length`, `firstindex`, `lastindex`, `push!`, `pop!`
# """
# struct SubproblemsData
#     flows::Vector{DataFrame} # one per subproblem
#     storage_levels::Vector{DataFrame} # one per subproblem
#     nsd::Vector{DataFrame} # one per subproblem
#     curtailment::Vector{DataFrame} # one per subproblem
#     operational_costs::Vector{DataFrame} # one per subproblem
# end
# SubproblemsData(n::Int64) = SubproblemsData(Vector{DataFrame}(undef, n), Vector{DataFrame}(undef, n), Vector{DataFrame}(undef, n), Vector{DataFrame}(undef, n), Vector{DataFrame}(undef, n))
# function SubproblemsData(results::Vector{NamedTuple})
#     subproblems_data = SubproblemsData(length(results))
#     for i in eachindex(results)
#         subproblems_data[i] = results[i]
#     end
#     return subproblems_data
# end
# function Base.length(subproblems_data::SubproblemsData)
#     @assert length(subproblems_data.flows) == length(subproblems_data.storage_levels) == length(subproblems_data.nsd) == length(subproblems_data.operational_costs) == length(subproblems_data.curtailment)
#     return length(subproblems_data.flows)
# end
# Base.iterate(s::SubproblemsData) = length(s) == 0 ? nothing : (s[1], 1)
# Base.iterate(s::SubproblemsData, i::Int) = i > length(s) ? nothing : (s[i], i + 1)
# function Base.getindex(subproblems_data::SubproblemsData, i::Int64)
#     return (
#         flows=subproblems_data.flows[i],
#         storage_levels=subproblems_data.storage_levels[i],
#         nsd=subproblems_data.nsd[i],
#         curtailment=subproblems_data.curtailment[i],
#         operational_costs=subproblems_data.operational_costs[i],
#     )
# end
# function Base.setindex!(subproblems_data::SubproblemsData, results::NamedTuple, i::Int64)
#     subproblems_data.flows[i] = results.flows
#     subproblems_data.storage_levels[i] = results.storage_levels
#     subproblems_data.nsd[i] = results.nsd
#     subproblems_data.curtailment[i] = results.curtailment
#     subproblems_data.operational_costs[i] = results.operational_costs
# end
# function Base.push!(subproblems_data::SubproblemsData, results::NamedTuple)
#     push!(subproblems_data.flows, results.flows)
#     push!(subproblems_data.storage_levels, results.storage_levels)
#     push!(subproblems_data.nsd, results.nsd)
#     push!(subproblems_data.curtailment, results.curtailment)
#     push!(subproblems_data.operational_costs, results.operational_costs)
# end
# function Base.pop!(subproblems_data::SubproblemsData)
#     pop!(subproblems_data.flows)
#     pop!(subproblems_data.storage_levels)
#     pop!(subproblems_data.nsd)
#     pop!(subproblems_data.curtailment)
#     pop!(subproblems_data.operational_costs)
# end
# flows(subproblems_data::SubproblemsData) = subproblems_data.flows
# storage_levels(subproblems_data::SubproblemsData) = subproblems_data.storage_levels
# non_served_demand(subproblems_data::SubproblemsData) = subproblems_data.nsd
# curtailment(subproblems_data::SubproblemsData) = subproblems_data.curtailment
# operational_costs(subproblems_data::SubproblemsData) = subproblems_data.operational_costs

# """
#     extract_subproblem_results(system::System; scaling::Float64=1.0)

# Extract all results from a subproblem by iterating through edges, storages, and nodes.

# Returns a NamedTuple containing:
# - flows: DataFrame
# - storage_levels: DataFrame
# - nsd: DataFrame
# - curtailment: DataFrame
# - operational_costs: DataFrame

# # Arguments
# - `system::System`: The system to extract results from
# - `scaling::Float64=1.0`: Scaling factor for values
# """
# function extract_subproblem_results(system::System; scaling::Float64=1.0)
#     # Get edges and storages with their asset mappings
#     edges, edge_asset_map = get_edges(system, return_ids_map=true)
#     storages, storage_asset_map = get_storages(system, return_ids_map=true)
#     # Nodes that can have operational costs (NSD, supply, and/or slack)
#     nodes_with_costs = filter(get_nodes(system)) do n
#         !isempty(non_served_demand(n)) ||
#         !isempty(supply_segments(n)) ||
#         !isempty(policy_slack_vars(n))
#     end

#     # Initialize collectors for flows and costs
#     flow_dfs = DataFrame[]
#     cost_rows = NamedTuple{(:zone, :type, :category, :value),Tuple{String,String,Symbol,Float64}}[]
#     attributed_fuel_cost_by_node = Dict{Symbol,Float64}()

#     # Extract flows and compute operational costs for edges
#     for e in edges
#         zone = get_zone_name(e)
#         asset_type = get_type(edge_asset_map[id(e)])

#         # Reuse existing flow extraction function
#         push!(flow_dfs, get_optimal_flow(e, scaling, edge_asset_map))

#         # Compute operational costs
#         vom_cost = compute_variable_om_cost(e)
#         fuel_cost = compute_fuel_cost(e)
#         startup_cost_val = compute_startup_cost(e)

#         if fuel_cost > 0 && isa(start_vertex(e), Node)
#             source_node = start_vertex(e)
#             attributed_fuel_cost_by_node[id(source_node)] = get(attributed_fuel_cost_by_node, id(source_node), 0.0) + fuel_cost
#         end

#         # Store aggregated costs (only non-zero, with scaling)
#         vom_cost > 0 && push!(cost_rows, (zone=zone, type=asset_type, category=:VariableOM, value=vom_cost * scaling^2))
#         fuel_cost > 0 && push!(cost_rows, (zone=zone, type=asset_type, category=:Fuel, value=fuel_cost * scaling^2))
#         startup_cost_val > 0 && push!(cost_rows, (zone=zone, type=asset_type, category=:Startup, value=startup_cost_val * scaling^2))
#     end

#     # Combine flow DataFrames
#     flows_df = isempty(flow_dfs) ? DataFrame() : reduce(vcat, flow_dfs)

#     # Extract storage levels
#     storage_levels_df = get_optimal_storage_level(storages, scaling, storage_asset_map)

#     # Extract NSD and compute NSD/Supply/Slack costs for nodes
#     nsd_dfs = DataFrame[]
#     for node in nodes_with_costs
#         zone = get_zone_name(node)
#         node_type = get_type(node)

#         # Reuse existing NSD extraction function
#         push!(nsd_dfs, get_optimal_non_served_demand(node, scaling))

#         # NSD cost
#         nsd_cost = compute_nsd_cost(node)
#         nsd_cost > 0 && push!(cost_rows, (zone=zone, type=node_type, category=:NonServedDemand, value=nsd_cost * scaling^2))

#         # Supply cost
#         supply_cost = compute_residual_supply_cost(node, get(attributed_fuel_cost_by_node, id(node), 0.0))
#         supply_cost > 0 && push!(cost_rows, (zone=zone, type=node_type, category=:Supply, value=supply_cost * scaling^2))

#         # Slack cost
#         slack_cost = compute_slack_cost(node)
#         slack_cost > 0 && push!(cost_rows, (zone=zone, type=node_type, category=:UnmetPolicyPenalty, value=slack_cost * scaling^2))
#     end
#     nsd_df = isempty(nsd_dfs) ? DataFrame() : reduce(vcat, nsd_dfs)

#     # Build operational costs DataFrame
#     operational_costs_df = isempty(cost_rows) ?
#                            DataFrame(zone=String[], type=String[], category=Symbol[], value=Float64[]) :
#                            DataFrame(cost_rows)

#     # Extract curtailment for VRE edges
#     curtailment_df = get_optimal_curtailment(system; scaling)

#     return (
#         flows=flows_df,
#         storage_levels=storage_levels_df,
#         nsd=nsd_df,
#         curtailment=curtailment_df,
#         operational_costs=operational_costs_df
#     )
# end

# """
# Convert DenseAxisArray to Dict, preserving axis information.
# """
# function densearray_to_dict(arr::JuMP.Containers.DenseAxisArray)
#     ndims = length(arr.axes)
    
#     if ndims == 1
#         return Dict(idx => JuMP.value(arr[idx]) for idx in arr.axes[1])
#     elseif ndims == 2
#         return Dict((i, j) => JuMP.value(arr[i, j]) for i in arr.axes[1], j in arr.axes[2])
#     else
#         return Dict(idx_tuple => JuMP.value(arr[idx_tuple...]) 
#             for idx_tuple in Iterators.product(arr.axes...))
#     end
# end

# """
# Convert Dict back to DenseAxisArray.
# """
# function dict_to_densearray(dict::AbstractDict)
#     first_key = first(keys(dict))
    
#     if first_key isa Tuple
#         ndims = length(first_key)
        
#         # Extract unique values for each dimension from the dictionary keys
#         # This will make sure to map the dictionary keys to the DenseAxisArray indices
#         key_list = collect(keys(dict))
#         all_axes = []
#         for dim in 1:ndims
#             axis_vals = sort(unique([k[dim] for k in key_list]))
#             push!(all_axes, axis_vals)
#         end
        
#         # Create data array from the dictionary values
#         data = [get(dict, idx_tuple, NaN) for idx_tuple in Iterators.product(all_axes...)]
        
#         return JuMP.Containers.DenseAxisArray(data, all_axes...)
#     elseif isa(first_key, Int64)
#         # Fallback to 1D case if keys are not tuples
#         indices = sort(collect(keys(dict)))
#         values = [dict[i] for i in indices]
#         return JuMP.Containers.DenseAxisArray(values, indices)
#     else
#         error("Unsupported key type: $(typeof(first_key))")
#     end
# end

# """
#     populate_slack_vars_from_subproblems!(
#         period::System,
#         slack_vars::Dict{Tuple{Symbol,Symbol}, <:AbstractDict}
#     )

# Populate slack variables from Benders subproblems back into the planning problem system.

# Converts collected slack variable dictionaries back to DenseAxisArray format and assigns them
# to the appropriate nodes in the planning problem.

# # Arguments
# - `period::System`: The planning problem system
# - `slack_vars::Dict{Tuple{Symbol,Symbol}, <:AbstractDict}`: Dictionary mapping (node_id, slack_vars_key) to slack variable data

# # Returns
# - `nothing`
# """
# function populate_slack_vars_from_subproblems!(period::System, slack_vars::Dict{Tuple{Symbol,Symbol}, <:AbstractDict})
#     for (node_id, slack_vars_key) in keys(slack_vars)
#         node = find_node(period, node_id)
#         @assert !isnothing(node)
#         # Convert dict back to DenseAxisArray before assigning to the node
#         # This will make sure the slack variables are stored in the correct format
#         node.policy_slack_vars[slack_vars_key] = dict_to_densearray(slack_vars[(node_id, slack_vars_key)])
#     end
#     return nothing
# end

# """
#     collect_distributed_policy_slack_vars(bd_results::BendersResults)

# Collect policy slack variables from distributed Benders subproblems across multiple workers.

# # Arguments
# - `bd_results::BendersResults`: Benders decomposition results containing distributed subproblems

# # Returns
# - Dictionary with structure: period_index => (node_id, slack_vars_key) => {axis_idx => value}
# """
# function collect_distributed_policy_slack_vars(bd_results::BendersResults)
#     p_id = workers()
#     np_id = length(p_id)
#     slack_vars = Vector{Dict{Int64, Dict{Tuple{Symbol,Symbol}, Dict{Int64, Float64}}}}(undef, np_id)
#     @sync for i in 1:np_id
#         @async slack_vars[i] = @fetchfrom p_id[i] collect_local_slack_vars(DistributedArrays.localpart(bd_results.op_subproblem))
#     end
    
#     # Merge dictionaries by period_index
#     # Structure: period_index => (node_id, slack_vars_key) => {axis_idx => value}
#     return merge_distributed_slack_vars_dicts(slack_vars)
# end

# """
#     collect_local_slack_vars(subproblems_local::Vector{Dict{Any,Any}})

# Collect policy slack variables from local Benders subproblems on this worker.

# Iterates through subproblems and extracts slack variables from nodes, converting them
# from DenseAxisArray to dictionary format for distributed collection.

# # Arguments
# - `subproblems_local::Vector{Dict{Any,Any}}`: Local subproblems on this worker

# # Returns
# - Dictionary with structure: period_index => (node_id, slack_vars_key) => {axis_idx => value}
# """
# function collect_local_slack_vars(subproblems_local::Vector{Dict{Any,Any}})
#     slack_vars = Dict{Int64, Dict{Tuple{Symbol, Symbol}, Dict{Int64, Float64}}}()
#     for i in eachindex(subproblems_local)
#         system = subproblems_local[i][:system_local]
#         for node in filter(n -> n isa Node, system.locations)
#             period_index = system.time_data[:Electricity].period_index
#             for slack_vars_key in keys(policy_slack_vars(node))
#                 # Create tuple key with (node_id, slack_vars_key) to keep track of the metadata
#                 key = (node.id, slack_vars_key)
                
#                 # Convert DenseAxisArray to Dict before assigning to the period_dict
#                 slack_array = policy_slack_vars(node)[slack_vars_key]
#                 axis_dict = densearray_to_dict(slack_array)
                
#                 # Ensure period_index dict exists
#                 period_dict = get!(slack_vars, period_index, Dict{Tuple{Symbol, Symbol}, Dict{Int64, Float64}}())
                
#                 # Merge axis dictionaries (different subproblems have different time indices)
#                 if haskey(period_dict, key)
#                     merge!(period_dict[key], axis_dict)
#                 else
#                     period_dict[key] = axis_dict
#                 end
#             end
#         end
#     end
#     return slack_vars
# end

# """
#     merge_distributed_slack_vars_dicts(
#         worker_results::Vector{Dict{Int64, Dict{Tuple{Symbol,Symbol}, Dict}}}
#     )

# Helper function that combines results from multiple workers where each worker
# returns a nested dictionary structure: period_idx => (node_id, slack_vars_key) => data_dict.

# # Arguments
# - `worker_results::Vector{Dict{Int64, Dict{K, Dict}}}`: Vector of dictionaries from each worker

# # Returns
# - Merged dictionary with structure: period_idx => (node_id, slack_vars_key) => merged_data_dict
# """
# function merge_distributed_slack_vars_dicts(
#     worker_results::Vector{<:AbstractDict{Int64, <:AbstractDict{Tuple{Symbol,Symbol}, <:AbstractDict}}}
# )
#     merged = Dict{Int64, Dict{Tuple{Symbol,Symbol}, Dict}}()
    
#     for worker_dict in worker_results
#         for (period_idx, period_dict) in worker_dict
#             # Ensure period exists in merged dict
#             if !haskey(merged, period_idx)
#                 merged[period_idx] = Dict{Tuple{Symbol,Symbol}, Dict}()
#             end
            
#             # Merge inner dictionaries for this period
#             for (key, data_dict) in period_dict
#                 if haskey(merged[period_idx], key)
#                     # If same (node_id, slack_vars_key) exists, merge the axis dictionaries
#                     merge!(merged[period_idx][key], data_dict)
#                 else
#                     merged[period_idx][key] = copy(data_dict)
#                 end
#             end
#         end
#     end
    
#     return merged
# end

# """
#     populate_constraint_duals_from_subproblems!(
#         period::System,
#         constraint_duals::Dict{Symbol, Dict{Symbol, <: AbstractDict}},
#         ::Type{<:AbstractTypeConstraint}
#     )

# # Arguments
# - `period::System`: The planning problem
# - `constraint_duals::Dict{Symbol, Dict{Symbol, Dict}}`: The collected constraint duals
# - `::Type{<:AbstractTypeConstraint}`: The constraint type to prepare duals for

# # Returns
# - `nothing`

# Moves constraint duals from collected data back into the planning problem..
# """
# function populate_constraint_duals_from_subproblems!(period::System, constraint_duals::Dict{Symbol, <: AbstractDict{Symbol, <: AbstractDict}}, ::Type{<:AbstractTypeConstraint})
#     for (node_id, balance_dict) in constraint_duals
#         node = find_node(period, node_id)
#         @assert !isnothing(node) "Node $node_id not found in planning problem"
        
#         # Find the BalanceConstraint
#         constraint = get_constraint_by_type(node, BalanceConstraint)
#         isnothing(constraint) && continue
        
#         # Initialize constraint_dual dict if missing
#         if ismissing(constraint.constraint_dual)
#             constraint.constraint_dual = Dict{Symbol, Vector{Float64}}()
#         end
        
#         # For each balance equation, convert time_dict back to vector
#         for (balance_id, time_dict) in balance_dict
#             time_indices = sort(collect(keys(time_dict)))
#             dual_values = [time_dict[t] for t in time_indices]
#             constraint.constraint_dual[balance_id] = dual_values
#         end
#         # verify the constraint duals have all time indices
#         for dual_values in values(constraint.constraint_dual)
#             @assert length(dual_values) == length(time_interval(node))
#         end
#     end
    
#     return nothing
# end

# """
#     collect_distributed_constraint_duals(
#         bd_results::BendersResults,
#         ::Type{BalanceConstraint}
#     )

# # Arguments
# - `bd_results::BendersResults`: Benders decomposition results containing subproblems
# - `::Type{BalanceConstraint}`: The constraint type to collect duals for

# # Returns
# - `Dict{Int64, Dict{Symbol, Dict{Symbol, Dict}}}`: A nested dictionary structure containing the constraint duals

# The returned dictionary has the following structure:
# - period_index => node_id => balance_id => {time_idx => dual_value}
# """
# function collect_distributed_constraint_duals(bd_results::BendersResults, ::Type{BalanceConstraint})
#     p_id = workers()
#     np_id = length(p_id)
#     constraint_duals = Vector{Dict{Int64, Dict{Symbol, Dict{Symbol, Dict}}}}(undef, np_id)
#     @sync for i in 1:np_id
#         @async constraint_duals[i] = @fetchfrom p_id[i] collect_local_constraint_duals(
#             DistributedArrays.localpart(bd_results.op_subproblem),
#             BalanceConstraint
#         )
#     end
    
#     # Merge dictionaries
#     # Structure: period_idx => node_id => balance_id => {time_idx => dual_value}
#     return merge_distributed_balance_duals(constraint_duals)
# end

# """
#     collect_local_constraint_duals(
#         subproblems_local::Vector{<: AbstractDict{Any,Any}},
#         ::Type{BalanceConstraint}
#     )

# Collect BalanceConstraint duals from local subproblems on this worker.

# # Arguments
# - `subproblems_local::Vector{Dict{Any,Any}}`: Local subproblems on this worker
# - `::Type{BalanceConstraint}`: The constraint type to collect duals for

# # Returns
# - Dictionary with structure: period_index => node_id => balance_id => {time_idx => dual_value}
# """
# function collect_local_constraint_duals(
#     subproblems_local::Vector{ <: AbstractDict},
#     ::Type{BalanceConstraint}
# )
#     constraint_duals = Dict{Int64, Dict{Symbol, Dict{Symbol, Dict}}}()
    
#     for i in eachindex(subproblems_local)
#         system = subproblems_local[i][:system_local]
#         period_index = system.time_data[:Electricity].period_index
        
#         for node in filter(n -> n isa Node, system.locations)
#             # Find BalanceConstraint on this node
#             constraint = get_constraint_by_type(node, BalanceConstraint)
#             isnothing(constraint) && continue
#             ismissing(constraint.constraint_ref) && continue
            
#             # Extract dual values if not already extracted
#             if ismissing(constraint_dual(constraint))
#                 set_constraint_dual!(constraint, node)
#             end
            
#             # Get the dictionary of dual values for all balance equations
#             duals_dict = constraint_dual(constraint)
#             ismissing(duals_dict) && continue
            
#             # Ensure period and node dicts exist
#             if !haskey(constraint_duals, period_index)
#                 constraint_duals[period_index] = Dict{Symbol, Dict{Symbol, Dict}}()
#             end
#             if !haskey(constraint_duals[period_index], node.id)
#                 constraint_duals[period_index][node.id] = Dict{Symbol, Dict}()
#             end
            
#             # For each balance equation, store duals as time_idx => value
#             for (balance_id, dual_values) in duals_dict
#                 # Convert vector to dict mapping time indices to values
#                 time_indices = collect(time_interval(node))
#                 dual_dict = Dict(time_indices[i] => dual_values[i] for i in eachindex(time_indices))
                
#                 # Merge time dictionaries (different subproblems have different time indices)
#                 if haskey(constraint_duals[period_index][node.id], balance_id)
#                     merge!(constraint_duals[period_index][node.id][balance_id], dual_dict)
#                 else
#                     constraint_duals[period_index][node.id][balance_id] = dual_dict
#                 end
#             end
#         end
#     end
    
#     return constraint_duals
# end

# """
#     merge_distributed_balance_duals(
#         worker_results::Vector{<:AbstractDict{Int64, <:AbstractDict{Symbol, <:AbstractDict{Symbol, <:AbstractDict}}}}
#     )

# Helper function that combines results from multiple workers where each worker
# returns a nested dictionary structure: period_idx => node_id => balance_id => time_dict.

# # Arguments
# - `worker_results::Vector{<:AbstractDict{Int64, <:AbstractDict{Symbol, <:AbstractDict{Symbol, <:AbstractDict}}}}`: Vector of dictionaries from each worker

# # Returns
# - Merged dictionary with structure: period_idx => node_id => balance_id => {time_idx => dual_value}
# """
# function merge_distributed_balance_duals(
#     worker_results::Vector{<:AbstractDict{Int64, <:AbstractDict{Symbol, <:AbstractDict{Symbol, <:AbstractDict}}}}
# )
#     merged_duals = Dict{Int64, Dict{Symbol, Dict{Symbol, Dict}}}()
    
#     for worker_dict in worker_results
#         for (period_idx, period_dict) in worker_dict
#             # Make sure period exists
#             if !haskey(merged_duals, period_idx)
#                 merged_duals[period_idx] = Dict{Symbol, Dict{Symbol, Dict}}()
#             end
            
#             # Merge inner dictionaries for this period
#             for (node_id, balance_dict) in period_dict
#                 if !haskey(merged_duals[period_idx], node_id)
#                     merged_duals[period_idx][node_id] = Dict{Symbol, Dict}()
#                 end
                
#                 # Merge balance equation dictionaries
#                 for (balance_id, time_dict) in balance_dict
#                     if haskey(merged_duals[period_idx][node_id], balance_id)
#                         # Merge time index dictionaries from different workers
#                         merge!(merged_duals[period_idx][node_id][balance_id], time_dict)
#                     else
#                         merged_duals[period_idx][node_id][balance_id] = copy(time_dict)
#                     end
#                 end
#             end
#         end
#     end
    
#     return merged_duals
# end

# """
#     collect_local_constraint_duals(
#         subproblems_local::Vector{Dict{Any,Any}},
#         constraint_type::Type{<:AbstractTypeConstraint}
#     )

# Fallback function that throws an error if the constraint type is not supported.

# This is a generic fallback method that should be specialized for specific constraint types
# (e.g., `BalanceConstraint`). If called with an unsupported constraint type, it throws a
# descriptive `MethodError`.

# # Arguments
# - `subproblems_local::Vector{Dict{Any,Any}}`: Local subproblems on this worker
# - `constraint_type::Type{<:AbstractTypeConstraint}`: The constraint type to collect duals for

# # Throws
# - `MethodError`: Always thrown to indicate the constraint type is not supported
# """
# function collect_local_constraint_duals(
#     subproblems_local::Vector{<:AbstractDict},
#     constraint_type::Type{AbstractTypeConstraint}
# )
#     throw(MethodError(collect_local_constraint_duals, 
#         (typeof(subproblems_local), typeof(constraint_type)),
#         "Constraint type $(typeof(constraint_type)) not supported for local constraint dual collection."
#     ))
# end