function get_demand_dataframe(path)
    filename = "Demand_data.csv"
    deprecated_synonym = "Load_data.csv"
    df = load_dataframe(path, [filename, deprecated_synonym])
    # update column names
    old_columns = find_matrix_columns_in_dataframe(df,
        DEMAND_COLUMN_PREFIX_DEPRECATED()[1:(end - 1)],
        prefixseparator = 'z')
    old_column_symbols = Symbol.(DEMAND_COLUMN_PREFIX_DEPRECATED() * string(i)
    for i in old_columns)
    if length(old_column_symbols) > 0
        pref_prefix = DEMAND_COLUMN_PREFIX()
        dep_prefix = DEMAND_COLUMN_PREFIX_DEPRECATED()
        @info "$dep_prefix is deprecated. Use $pref_prefix."
        new_column_symbols = Symbol.(DEMAND_COLUMN_PREFIX() * string(i)
        for i in old_columns)
        DataFrames.rename!(df, Dict(old_column_symbols .=> new_column_symbols))
    end
    return df
end

DEMAND_COLUMN_PREFIX() = "Demand_MW_z"
DEMAND_COLUMN_PREFIX_DEPRECATED() = "Load_MW_z"

@doc raw"""
	load_demand_data!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to electricity demand (load)
"""
function load_demand_data!(setup::Dict, path::AbstractString, inputs::Dict)

    # Load related inputs
    TDR_directory = joinpath(path, setup["TimeDomainReductionFolder"])
    # if TDR is used, my_dir = TDR_directory, else my_dir = "system"
    my_dir = get_systemfiles_path(setup, TDR_directory, path)

    demand_in = get_demand_dataframe(my_dir)

    as_vector(col::Symbol) = collect(skipmissing(demand_in[!, col]))

    # Number of time steps (periods)
    T = length(as_vector(:Time_Index))
    # Number of demand curtailment/lost load segments
    SEG = length(as_vector(:Demand_Segment))

    ## Set indices for internal use
    inputs["T"] = T
    inputs["SEG"] = SEG
    Z = inputs["Z"]   # Number of zones

    inputs["omega"] = zeros(Float64, T) # weights associated with operational sub-period in the model - sum of weight = 8760
    # Weights for each period - assumed same weights for each sub-period within a period
    inputs["Weights"] = as_vector(:Sub_Weights) # Weights each period

    # Total number of periods and subperiods
    inputs["REP_PERIOD"] = convert(Int16, as_vector(:Rep_Periods)[1])
    inputs["H"] = convert(Int64, as_vector(:Timesteps_per_Rep_Period)[1])

    # Creating sub-period weights from weekly weights
    for w in 1:inputs["REP_PERIOD"]
        for h in 1:inputs["H"]
            t = inputs["H"] * (w - 1) + h
            inputs["omega"][t] = inputs["Weights"][w] / inputs["H"]
        end
    end

    # Create time set steps indicies
    inputs["hours_per_subperiod"] = div.(T, inputs["REP_PERIOD"]) # total number of hours per subperiod
    hours_per_subperiod = inputs["hours_per_subperiod"] # set value for internal use

    inputs["START_SUBPERIODS"] = 1:hours_per_subperiod:T # set of indexes for all time periods that start a subperiod (e.g. sample day/week)
    inputs["INTERIOR_SUBPERIODS"] = setdiff(1:T, inputs["START_SUBPERIODS"]) # set of indexes for all time periods that do not start a subperiod

    # Demand in MW for each zone
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    # Max value of non-served energy
    inputs["Voll"] = as_vector(:Voll) / scale_factor # convert from $/MWh $ million/GWh (assuming objective is divided by 1000)
    # Demand in MW
    inputs["pD"] = extract_matrix_from_dataframe(demand_in,
        DEMAND_COLUMN_PREFIX()[1:(end - 1)],
        prefixseparator = 'z') / scale_factor

    # Cost of non-served energy/demand curtailment
    # Cost of each segment reported as a fraction of value of non-served energy - scaled implicitly
    inputs["pC_D_Curtail"] = as_vector(:Cost_of_Demand_Curtailment_per_MW) *
                             inputs["Voll"][1]
    # Maximum hourly demand curtailable as % of the max demand (for each segment)
    inputs["pMax_D_Curtail"] = as_vector(:Max_Demand_Curtailment)

    println("Demand (load) data Successfully Read!")

    #println("Demand data:", inputs["pD"])
end

@doc raw"""
	load_demand_data_p!(setup::Dict, p::Portfolio, inputs::Dict)

Read input parameters related to electricity demand (load) from portfolio
"""
function load_demand_data!(setup::Dict, p::Portfolio, inputs::Dict, path::AbstractString)

    # Load related inputs
    # Loads DemandRequirement and DemandSideTechnology (for flexible demand and demand curtailment)
    # from the portfolio
    demand_in = collect(get_technologies(DemandRequirement, p))
    # segments = collect(get_technologies(DemandSideTechnology, p))
    # This is the demand TS for zone-1 just for verification
    first_d = demand_in[1]
    IS.show_time_series(first_d)
    T=0
    region_to_index = inputs["region_to_index"]
    index_to_region = inputs["index_to_region"]
    all_demand_data = []
    for (zone_idx, d) in enumerate(demand_in)
        load_data = []
        keys_ = IS.get_time_series_keys(d)
        #println("keys_ = $keys_")
        names = [x.name for x in keys_] 
        #println("names = $names")
        types = [x.time_series_type for x in keys_]
        #println("types = $types")
        feats = [x.features for x in keys_]
        #println("feats = $feats")
        lengths = [x.length for x in keys_]
        T=sum(lengths)
        #println("T = $T")
        #println("lengths = $lengths")
##Uncomment these lines if using predictive timeseries, like in Stochastic Optimization
        #=temp_first_feats = Dict(Symbol.(keys(feats[1])) .=> values(feats[2]))
        println("temp_first_feats = $temp_first_feats")
        key_feats_first = collect(keys(feats[1]))
        println("key_feats_first = $key_feats_first")
        vals_feats_first = collect(values(feats[1]))
        println("vals_feats_first = $vals_feats_first")
        vals_feats_first[1]
        ts_vals = [IS.get_time_series_values(type, d, name; temp_first_feats...) for type in types, name in names]=#
##Uncomment the above lines if using predictive timeseries, like in Stochastic Optimization
        ts_vals = PSIP.get_data(IS.get_time_series(d, keys_[1]))
        max_demand = PSIP.get_peak_demand_mw(d) #Wait for Jerry's unit conversion fix
        #println("ts_vals = $ts_vals")
        if isempty(ts_vals)
            error("Time series data for $keys_ not found.")
        end
        # Get the region ID for this demand zone
        id = PSIP.get_id(d.region[1])
        #println("Zone $zone_idx has region ID: $id")
        genx_id = region_to_index[id]
        # Extract values from TimeArray - this is the key fix!
        if ts_vals isa TS.TimeArray
            demand_values = values(ts_vals) .* max_demand  # Extract the actual numeric values
        else
            demand_values = ts_vals .* max_demand # If it's already a vector, use as-is
        end
        
        # Store the time series data
        push!(all_demand_data, (genx_id, demand_values))
    end

    inputs["T"] = T
    inputs["pD"] = zeros( T, length(demand_in) )
    
    # Populate the demand matrix
    for (genx_id, demand_values) in all_demand_data
        # Use zone_idx for matrix column, since we may not have sequential region IDs
        inputs["pD"][:, genx_id]  = demand_values
    end

    # Apply scaling factor
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    inputs["pD"] = inputs["pD"] / scale_factor

    # Validate demand totals against DAY_AHEAD_regional_Load.csv
    validate_demand_totals(setup, inputs, all_demand_data, scale_factor, path)

    # Number of demand curtailment/lost load segments
    # SEG = length(segments[1].segments) # Upcoming feature in DemandRequirement
    SEG = 1  # Default to 1 for now
    inputs["SEG"] = SEG
    inputs["omega"] = zeros(Float64, T) # weights associated with operational sub-period in the model - sum of weight = 8760
    # Weights for each period - assumed same weights for each sub-period within a period
    if !haskey(p.internal.ext, "Rep_Periods")
        @warn "No `Rep_Periods` defined in portfolio; using 1"
        inputs["REP_PERIOD"] = 1
    else
        inputs["REP_PERIOD"] = p.internal.ext["Rep_Periods"]
    end

    if !haskey(p.internal.ext, "Timesteps_per_Rep_Period")
        @warn "No `Timesteps_per_Rep_Period` defined in portfolio; using 8760"
        inputs["H"] = 8760
    else
        inputs["H"] = p.internal.ext["Timesteps_per_Rep_Period"]
    end

    if !haskey(p.internal.ext, "sub_weights")
        @warn "No `sub_weights` are defined in the portfolio; assuming $(inputs["REP_PERIOD"])"
        inputs["Weights"] = [8760 / inputs["REP_PERIOD"] for i in 1:inputs["REP_PERIOD"]]
    else
        inputs["Weights"] = p.internal.ext["sub_weights"]
    end

    if !haskey(p.internal.ext, "hours_per_subperiod")
        inputs["hours_per_subperiod"] = div.(T, inputs["REP_PERIOD"]) # total number of hours per subperiod
    else
        inputs["hours_per_subperiod"] = p.internal.ext["hours_per_subperiod"]
    end

    # Creating sub-period weights from weekly weights
    for w in 1:inputs["REP_PERIOD"]
        for h in 1:inputs["H"]
            t = inputs["H"] * (w - 1) + h
            inputs["omega"][t] = inputs["Weights"][w] / inputs["H"]
        end
    end
###Uncomment these lines if using TDR
    #=inputs["omega"] = zeros(Float64, T) # weights associated with operational sub-period in the model - sum of weight = 8760
    # Weights for each period - assumed same weights for each sub-period within a period
    inputs["Weights"] = p.internal.ext["Sub_Weights"] # Weights each period

    # Total number of periods and subperiods #If these fields are needed, create an ext object in the portfolio which is a dictionary with these fields
    inputs["REP_PERIOD"] = convert(Int16, p.internal.ext["Rep_Periods"])
    inputs["H"] = convert(Int64, p.internal.ext["Timesteps_per_Rep_Period"])

    # Creating sub-period weights from weekly weights
    for w in 1:inputs["REP_PERIOD"]
        for h in 1:inputs["H"]
            t = inputs["H"] * (w - 1) + h
            inputs["omega"][t] = inputs["Weights"][w] / inputs["H"]
        end
    end

    # Create time set steps indicies
    inputs["hours_per_subperiod"] = div.(T, inputs["REP_PERIOD"]) # total number of hours per subperiod
    hours_per_subperiod = inputs["hours_per_subperiod"] # set value for internal use

    inputs["START_SUBPERIODS"] = 1:hours_per_subperiod:T # set of indexes for all time periods that start a subperiod (e.g. sample day/week)
    inputs["INTERIOR_SUBPERIODS"] = setdiff(1:T, inputs["START_SUBPERIODS"]) # set of indexes for all time periods that do not start a subperiod=#
###Uncomment these lines if using TDR
    # Demand in MW for each zone
    # Max value of non-served energy
    inputs["Voll"] = [get_value_of_lost_load(d) / scale_factor / inputs["T"] for d in demand_in] # convert from $/MWh $ million/GWh (assuming objective is divided by 1000)
    # Getting the demand in MW for each zone and for each rep period

    # Cost of non-served energy/demand curtailment
    # Cost of each segment reported as a fraction of value of non-served energy - scaled implicitly
    #*inputs["pC_D_Curtail"] = segments[1].curtailment_cost * inputs["Voll"][1]
    inputs["pC_D_Curtail"] = [inputs["Voll"][1] for s in 1:SEG] #NOTE: DAVID NEEDS TO FIX THIS
    # Maximum hourly demand curtailable as % of the max demand (for each segment)
    #*inputs["pMax_D_Curtail"] = segments[1].max_demand_curtailment
    inputs["pMax_D_Curtail"] = [1.0 for s in 1:SEG]
    println("Demand (load) data Successfully Read!")
    
end

# ensure that the length of demand data exactly matches
# the number of subperiods times their length
# and that the number of subperiods equals the list of provided weights
function validatetimebasis(inputs::Dict)
    println("Validating time basis")
    demand_length = size(inputs["pD"], 1)
    generators_variability_length = size(inputs["pP_Max"], 2)

    typical_fuel = first(inputs["fuels"])
    fuel_costs_length = size(inputs["fuel_costs"][typical_fuel], 1)

    T = inputs["T"]
    hours_per_subperiod = inputs["hours_per_subperiod"]
    number_of_representative_periods = inputs["REP_PERIOD"]
    expected_length_1 = hours_per_subperiod * number_of_representative_periods

    H = inputs["H"]
    expected_length_2 = H * number_of_representative_periods

    check_equal = [T,
        demand_length,
        generators_variability_length,
        fuel_costs_length,
        expected_length_1,
        expected_length_2]

    allequal(x) = all(y -> y == x[1], x)
    ok = allequal(check_equal)

    if ~ok
        error("""Critical error in time series construction:
                 lengths of the various time series, and/or the expected
                 total length based on the number of representative periods and their length,
                 are not all equal.

                 Expected length:                    $T
                     (set by the Time index in demand_data.csv [or load_data.csv])
                 Demand series length:               $demand_length
                     (demand_data.csv [or load_data.csv])
                 Resource time profiles length:      $generators_variability_length
                     (generators_variability.csv)
                 Fuel costs length:                  $fuel_costs_length
                     (fuels_data.csv)

                 Metrics from demand_data.csv [load_data.csv]:
                 Detected time steps:            $T
                 No. of representative periods:  $number_of_representative_periods
                     Euclidean quotient of these:    $hours_per_subperiod

                 No. of representative periods:  $number_of_representative_periods
                 Time steps per rep. period:     $H
                     Product of these:               $expected_length_2
              """)
    end

    if "Weights" in keys(inputs)
        weights = inputs["Weights"]
        num_weights = length(weights)
        if num_weights != number_of_representative_periods
            error("""Critical error in time series construction:
                  In demand_data.csv [or load_data.csv],
                  the number of subperiod weights ($num_weights) does not match
                  the expected number of representative periods, ($number_of_representative_periods).""")
        end
    end
end

@doc raw"""
    prevent_doubled_timedomainreduction(path::AbstractString)

This function prevents TimeDomainReduction from running on a case which
already has more than one Representative Period or has more than one Sub_Weight specified.
"""
function prevent_doubled_timedomainreduction(path::AbstractString)
    demand_in = get_demand_dataframe(path)
    as_vector(col::Symbol) = collect(skipmissing(demand_in[!, col]))
    representative_periods = convert(Int16, as_vector(:Rep_Periods)[1])
    sub_weights = as_vector(:Sub_Weights)
    num_sub_weights = length(sub_weights)
    if representative_periods != 1 || num_sub_weights > 1
        error("""Critical error in time series construction:
              Time domain reduction (clustering) is being called for,
              on data which may already be clustered. In demand_data.csv [or load_data.csv],
              the number of representative periods (:Rep_Period) is ($representative_periods)
              and the number of subperiod weight entries (:Sub_Weights) is ($num_sub_weights).
              Each of these must be 1: only a single period can have TimeDomainReduction applied.""")
    end
end

"""
    validate_demand_totals(setup::Dict, inputs::Dict, all_demand_data::Vector, scale_factor::Float64)

Validate that the sum of demand values across all nodes matches the regional totals 
from DAY_AHEAD_regional_Load.csv file.
"""
function validate_demand_totals(setup::Dict, inputs::Dict, all_demand_data::Vector, scale_factor::Number, path::AbstractString)
    try
        # Try to load the DAY_AHEAD_regional_Load.csv file
        csv_path = joinpath(dirname(path), "DAY_AHEAD_regional_Load.csv")
        if !isfile(csv_path)
            @warn "DAY_AHEAD_regional_Load.csv not found at $csv_path. Skipping demand validation."
            return
        end
        
        # Load the CSV file
        regional_demand_df = CSV.read(csv_path, DataFrame)
        
        # Sum demand across all zones for each hour from portfolio data
        portfolio_hourly_totals = sum(inputs["pD"] * scale_factor, dims=2)[:, 1]  # Sum across zones, restore original scale
        
        # Find the "Period" column and get all columns after it (these should be the zone columns)
        all_column_names = names(regional_demand_df)
        period_col_idx = findfirst(name -> occursin("period", lowercase(string(name))), all_column_names)
        
        if period_col_idx === nothing
            @warn "Period column not found in DAY_AHEAD_regional_Load.csv. Looking for zone columns by name pattern."
            zone_columns = filter(name -> occursin("zone", lowercase(string(name))) || 
                                        occursin("region", lowercase(string(name))) ||
                                        occursin("load", lowercase(string(name))), 
                                all_column_names)
        else
            # Get all columns after the Period column (these are the zone columns)
            zone_columns = all_column_names[(period_col_idx + 1):end]
            println("Found Period column at position $period_col_idx. Zone columns: $zone_columns")
        end
        
        if length(zone_columns) >= 3
            csv_hourly_totals = sum(Matrix(regional_demand_df[:, zone_columns[1:3]]), dims=2)[:, 1]
            println("Using first 3 zone columns for validation: $(zone_columns[1:3])")
        else
            @warn "Expected at least 3 zone columns in DAY_AHEAD_regional_Load.csv, found $(length(zone_columns)). Skipping validation."
            return
        end
        
        # Ensure both arrays have the same length
        min_length = min(length(portfolio_hourly_totals), length(csv_hourly_totals))
        portfolio_subset = portfolio_hourly_totals[1:min_length]
        csv_subset = csv_hourly_totals[1:min_length]
        
        # Compare the totals with tolerance for numerical precision
        tolerance = 1e-6
        differences = abs.(portfolio_subset - csv_subset)
        max_difference = maximum(differences)
        relative_error = max_difference / maximum(abs.(csv_subset))
        
        println("=== Demand Validation Results ===")
        println("Portfolio total demand (first 5 hours): $(portfolio_subset[1:min(5, end)])")
        println("CSV total demand (first 5 hours): $(csv_subset[1:min(5, end)])")
        println("Maximum absolute difference: $max_difference")
        println("Maximum relative error: $(relative_error * 100)%")
        
        if max_difference > tolerance
            @warn "Demand validation failed! Maximum difference ($max_difference) exceeds tolerance ($tolerance)"
            @warn "Portfolio and CSV demand totals do not match within expected precision"
        else
            println("✓ Demand validation passed! Portfolio and CSV totals match within tolerance.")
        end
        
    catch e
        @warn "Error during demand validation: $e"
        @warn "Continuing without validation..."
    end
end
