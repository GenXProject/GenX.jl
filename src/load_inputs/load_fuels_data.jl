@doc raw"""
    load_fuels_data!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to fuel costs and CO$_2$ content of fuels
"""
function load_fuels_data!(setup::Dict, path::AbstractString, inputs::Dict)

    # Fuel related inputs - read in different files depending on if time domain reduction is activated or not
    TDR_directory = joinpath(path, setup["TimeDomainReductionFolder"])
    # if TDR is used, my_dir = TDR_directory, else my_dir = "system"
    my_dir = get_systemfiles_path(setup, TDR_directory, path)

    filename = "Fuels_data.csv"
    fuels_in = load_dataframe(joinpath(my_dir, filename))

    for nonfuel in ("None",)
        ensure_column!(fuels_in, nonfuel, 0.0)
    end

    # Fuel costs & CO2 emissions rate for each fuel type
    fuels = names(fuels_in)[2:end]
    costs = Matrix(fuels_in[2:end, 2:end])
    CO2_content = fuels_in[1, 2:end] # tons CO2/MMBtu
    fuel_costs = Dict{AbstractString, Array{Float64}}()
    fuel_CO2 = Dict{AbstractString, Float64}()

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    for i in 1:length(fuels)
        # fuel cost is in $/MMBTU w/o scaling, $/Billon BTU w/ scaling
        fuel_costs[fuels[i]] = costs[:, i] / scale_factor
        # No need to scale fuel_CO2, fuel_CO2 is ton/MMBTU or kton/Billion BTU 
        fuel_CO2[fuels[i]] = CO2_content[i]
    end

    inputs["fuels"] = fuels
    inputs["fuel_costs"] = fuel_costs
    inputs["fuel_CO2"] = fuel_CO2

    println(filename * " Successfully Read!")

    return fuel_costs, fuel_CO2
end

struct FuelData
    name::String
    cost::Union{Vector{Float64}, Float64}
    co2_content::Float64
end

function load_fuels_data!(setup::Dict, p::Portfolio, inputs::Dict)

    T = 24
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    # Process fuels data
    fuels_data = collect_unique_fuels(p, T, scale_factor, inputs)

    # Add default "None" fuel if missing
    add_default_fuel!(fuels_data, T)
    
    # Update inputs dictionary
    update_inputs!(inputs, fuels_data)

    function repeat_to_length(v::Vector, M::Int)
        N = length(v)
        reps = ceil(Int, M / N)           # how many times we need to repeat
        long = repeat(v, reps)            # repeat enough times
        return long[1:M]                  # truncate to exactly length M
    end
    
    fuel_costs = inputs["fuel_costs"]
    for key in keys(fuel_costs)
        v = fuel_costs[key]
        if length(v) < inputs["T"]
            v = repeat_to_length(v, inputs["T"])
            fuel_costs[key] = v
        end
    end
    inputs["fuel_costs"] = fuel_costs
    
    println("Fuels data Successfully Read!")
    return nothing
end

# Fuel costs & CO2 emissions rate for each fuel type
function collect_unique_fuels(p::Portfolio, T::Int, scale_factor::Number, inputs::Dict)
    fuel_names = String[]
    rid_fuel_name_map = Dict{Int, String}()
    fuel_costs_dict = Dict{String, Any}()
    fuel_CO2_dict = Dict{String, Float64}()
    seen_fuel_costs = Vector{Float64}()#Set{Union{Float64, IS.TimeSeriesKey}}()
    unique_fuel_count = 1

    thermal_techs = [i for i in get_technologies(SupplyTechnology{PSY.ThermalStandard}, p) if !(occursin("SYNC_COND", i.name))]
    for tech in thermal_techs
        tech_fuel_cost = fuel_costs(tech)
        if tech_fuel_cost in seen_fuel_costs
            idx = findfirst(isequal(tech_fuel_cost), seen_fuel_costs)
            fuel_data = create_fuel_entry(tech, idx, T, scale_factor)
        else
            fuel_data = create_fuel_entry(tech, unique_fuel_count, T, scale_factor)
        end
        rid_fuel_name_map[resource_id(tech)] = fuel_data.name
        fuel_costs_dict[fuel_data.name] = fuel_data.cost
        fuel_CO2_dict[fuel_data.name] = fuel_data.co2_content
        if tech_fuel_cost ∉ seen_fuel_costs
            fuel_data = create_fuel_entry(tech, unique_fuel_count, T, scale_factor)
            #println(seen_fuel_costs, "   ", tech_fuel_cost)
            push!(seen_fuel_costs, tech_fuel_cost)
            
            # Update all dictionaries
            push!(fuel_names, fuel_data.name)
            #rid_fuel_name_map[tech_to_index[resource_id(tech)]] = fuel_data.name
            fuel_costs_dict[fuel_data.name] = fuel_data.cost
            fuel_CO2_dict[fuel_data.name] = fuel_data.co2_content
            unique_fuel_count += 1
        end
    end
    
    return (
        names=fuel_names, 
        rid_map=rid_fuel_name_map, 
        costs=fuel_costs_dict, 
        co2=fuel_CO2_dict
    )
end

function ensure_column!(df::DataFrame, col::AbstractString, fill_element)
    if col ∉ names(df)
        df[!, col] = fill(fill_element, nrow(df))
    end
end

function expand_ts(value::Union{IS.TimeSeriesKey, Float64}, T::Int)
    if isa(value, IS.TimeSeriesKey)
        #FIXME: learn how to get time series from a TimeSeriesKey
        # return get_time_series(SingleTimeSeries, value, value.fuel, model_year = value.model_year, order_day = value.order_day, type = value.type)
    end
    return fill(value, T)
end

function create_fuel_entry(tech, idx::Int, T::Int, scale_factor::Number)
    fuel_base_name = fuel(tech)[1]
    fuel_name = string(fuel_base_name) * "_" * string(idx)  #FIXME: this doesn't work for multi-fuel resources    
    fuel_cost = expand_ts(fuel_costs(tech), T) / scale_factor
    co2 = haskey(co2_content(tech), fuel_base_name) ? co2_content(tech)[fuel_base_name] : 0.0

    FuelData(
        fuel_name,
        fuel_cost,
        co2
    )
end

function add_default_fuel!(fuels_data, T::Int)
    if !haskey(fuels_data.costs, "None")
        push!(fuels_data.names, "None")
        fuels_data.costs["None"] = zeros(T)
        fuels_data.co2["None"] = 0.0
    end
end

function update_inputs!(inputs::Dict, fuels_data)
    inputs["fuels"] = fuels_data.names
    inputs["fuel_costs"] = fuels_data.costs
    inputs["fuel_CO2"] = fuels_data.co2
    inputs["rid_fuel_name_map"] = fuels_data.rid_map
end

#TODO: add support for multifuels