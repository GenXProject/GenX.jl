@doc raw"""
    load_hourly_matching_requirement!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to minimum energy share requirement constraints
(e.g. renewable portfolio standard or clean electricity standard policies)
"""
function load_hourly_matching_requirement!(setup::Dict, path::AbstractString, inputs::Dict)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    # Hourly matching related inputs - read in different files depending on if time domain reduction is activated or not
    TDR_directory = joinpath(path, setup["TimeDomainReductionFolder"])
    # if TDR is used, my_dir = TDR_directory, else my_dir = "system"
    if setup["TimeDomainReduction"] == 1 && time_domain_reduced_files_exist(TDR_directory)
        my_dir = TDR_directory
    else
        # If TDR is not used, then use the "policies" directory specified in the setup
        my_dir = path
    end

    filename = "Hourly_matching_requirement.csv"
    hm_in = load_dataframe(joinpath(my_dir, filename))
    inputs["HMCols"] = names(hm_in)[2:end]
    # Absolute demand profiles and percentage matching targets for each hourly matching constriant
    demand = Matrix(hm_in[2:end, 2:end]) ./ scale_factor # GWh if scaled, MWh if not scaled
    matching_target = hm_in[1, 2:end] 
    inputs["nHM"] = size(demand, 2)
    inputs["dfHM_absolute"] = demand
    inputs["dfHM_matching_target"] = matching_target
    println(filename * " Successfully Read!")

    # Zonal hourly matching demand based on fraction of load, if the file exists
    filename = "Hourly_matching_requirement_zonal.csv"
    if isfile(joinpath(path, filename))
        df = load_dataframe(joinpath(path, filename))
        mat = extract_matrix_from_dataframe(df, "HM")
        inputs["dfHM_zonal"] = mat
        println(filename * " Successfully Read!")
    end

    # Slack for hourly matching requirement, if the file exists
    filename = "Hourly_matching_requirement_slack.csv"
    if isfile(joinpath(path, filename))
        df = load_dataframe(joinpath(path, filename))
        inputs["dfHM_slack"] = df
        inputs["dfHM_slack"][!, :PriceCap] ./= scale_factor # million $/GWh if scaled, $/MWh if not scaled
        println(filename * " Successfully Read!")
    end

    
end
