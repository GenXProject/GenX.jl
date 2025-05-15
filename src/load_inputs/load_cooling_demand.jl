@doc raw"""
	load_cooling_demand!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to computing load
"""
function load_cooling_demand!(setup::Dict, path::AbstractString, inputs::Dict)

    # Load related inputs
    TDR_directory = joinpath(path, setup["TimeDomainReductionFolder"])
    # if TDR is used, my_dir = TDR_directory, else my_dir = "system"
    my_dir = get_systemfiles_path(setup, TDR_directory, path)

    filename = "Computing_demand_data.csv"
    computing_demand_in = load_dataframe(my_dir, filename)

    as_vector(col::Symbol) = collect(skipmissing(computing_demand_in[!, col]))

    # Number of demand curtailment/lost load segments
    SEG_Computing = length(as_vector(:Demand_Segment))

    ## Set indices for internal use
    inputs["SEG_Computing"] = SEG_Computing

    # Demand in MW for each zone
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    # Max value of non-served computing demand
    inputs["Voll_Computing"] = as_vector(:Voll) / scale_factor # convert from $/MWh $ million/GWh (assuming objective is divided by 1000)
    # Demand in MW
    inputs["pD_Computing"] = extract_matrix_from_dataframe(computing_demand_in,
        DEMAND_COLUMN_PREFIX()[1:(end - 1)],
        prefixseparator = 'z') / scale_factor

    # Cost of non-served computing demand curtailment
    # Cost of each segment reported as a fraction of value of non-served computing demand - scaled implicitly
    inputs["pC_D_Curtail_Computing"] = as_vector(:Cost_of_Computing_Demand_Curtailment_per_MW) *
                             inputs["Voll_Computing"][1]
    # Maximum hourly demand curtailable as % of the max computing demand (for each segment)
    inputs["pMax_D_Curtail_Computing"] = as_vector(:Max_Computing_Demand_Curtailment)

    println("Computing demand data Successfully Read!")
end