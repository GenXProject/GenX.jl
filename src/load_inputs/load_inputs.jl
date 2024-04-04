@doc raw"""
	load_inputs(setup::Dict,path::AbstractString)

Loads various data inputs from multiple input .csv files in path directory and stores variables in a Dict (dictionary) object for use in model() function

inputs:
setup - dict object containing setup parameters
path - string path to working directory

returns: Dict (dictionary) object containing all data inputs
"""
function load_inputs(setup::Dict, path::AbstractString)

    ## Read input files
    println("Reading Input CSV Files")
    ## input paths
    system_path = joinpath(path, setup["SystemFolder"])
    resources_path = joinpath(path, setup["ResourcesFolder"])
    policies_path = joinpath(path, setup["PoliciesFolder"])
    ## Declare Dict (dictionary) object used to store parameters
    inputs = Dict()
    # Read input data about power network topology, operating and expansion attributes
    if isfile(joinpath(system_path, "Network.csv"))
        network_var = load_network_data!(setup, system_path, inputs)
    else
        inputs["Z"] = 1
        inputs["L"] = 0
    end

    # Read temporal-resolved load data, and clustering information if relevant
    load_demand_data!(setup, path, inputs)
    # Read fuel cost data, including time-varying fuel costs
    load_fuels_data!(setup, path, inputs)
    # Read in generator/resource related inputs
    load_resources_data!(inputs, setup, path, resources_path)
    # Read in generator/resource availability profiles
    load_generators_variability!(setup, path, inputs)

    validatetimebasis(inputs)

    if setup["CapacityReserveMargin"] == 1
        load_cap_reserve_margin!(setup, policies_path, inputs)
        if inputs["Z"] > 1
            load_cap_reserve_margin_trans!(setup, inputs, network_var)
        end
    end

    # Read in general configuration parameters for operational reserves (resource-specific reserve parameters are read in load_resources_data)
    if setup["OperationalReserves"] == 1
        load_operational_reserves!(setup, system_path, inputs)
    end

    if setup["MinCapReq"] == 1
        load_minimum_capacity_requirement!(policies_path, inputs, setup)
    end

    if setup["MaxCapReq"] == 1
        load_maximum_capacity_requirement!(policies_path, inputs, setup)
    end

    if setup["EnergyShareRequirement"] == 1
        load_energy_share_requirement!(setup, policies_path, inputs)
    end

    if setup["CO2Cap"] >= 1
        load_co2_cap!(setup, policies_path, inputs)
    end

    if !isempty(inputs["VRE_STOR"])
        load_vre_stor_variability!(setup, path, inputs)
    end

    # Read in mapping of modeled periods to representative periods
    if is_period_map_necessary(inputs) && is_period_map_exist(setup, path)
        load_period_map!(setup, path, inputs)
    end

    # Virtual charge discharge cost
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    inputs["VirtualChargeDischargeCost"] = setup["VirtualChargeDischargeCost"] /
                                           scale_factor

    println("CSV Files Successfully Read In From $path")

    return inputs
end

function is_period_map_necessary(inputs::Dict)
    multiple_rep_periods = inputs["REP_PERIOD"] > 1
    has_stor_lds = !isempty(inputs["STOR_LONG_DURATION"])
    has_hydro_lds = !isempty(inputs["STOR_HYDRO_LONG_DURATION"])
    has_vre_stor_lds = !isempty(inputs["VRE_STOR"]) && !isempty(inputs["VS_LDS"])
    multiple_rep_periods && (has_stor_lds || has_hydro_lds || has_vre_stor_lds)
end

function is_period_map_exist(setup::Dict, path::AbstractString)
    filename = "Period_map.csv"
    is_in_system_dir = isfile(joinpath(path, setup["SystemFolder"], filename))
    is_in_TDR_dir = isfile(joinpath(path, setup["TimeDomainReductionFolder"], filename))
    is_in_system_dir || is_in_TDR_dir
end

"""
	get_systemfiles_path(setup::Dict, TDR_directory::AbstractString, path::AbstractString)

Determine the directory based on the setup parameters.

This function checks if the TimeDomainReduction setup parameter is equal to 1 and if time domain reduced files exist in the data directory. 
If the condition is met, it returns the path to the TDR_results data directory. Otherwise, it returns the system directory specified in the setup.

Parameters:
- setup: Dict{String, Any} - The GenX settings parameters containing TimeDomainReduction and SystemFolder information.
- TDR_directory: String - The data directory where files are located.
- path: String - Path to the case folder.

Returns:
- String: The directory path based on the setup parameters.
"""
function get_systemfiles_path(setup::Dict,
    TDR_directory::AbstractString,
    path::AbstractString)
    if setup["TimeDomainReduction"] == 1 && time_domain_reduced_files_exist(TDR_directory)
        return TDR_directory
    else
        # If TDR is not used, then use the "system" directory specified in the setup
        return joinpath(path, setup["SystemFolder"])
    end
end

abstract type AbstractLogMsg end
struct ErrorMsg <: AbstractLogMsg
    msg::String
end
struct WarnMsg <: AbstractLogMsg
    msg::String
end
