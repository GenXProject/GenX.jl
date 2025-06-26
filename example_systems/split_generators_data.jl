using DataFrames 
using CSV

#### SETTINGS ###################
PATH_IN = "/Users/gabrielmantegna/Documents/GitHub/GenX/Example_Systems/ldes_conus3z_5days"
PATH_OUT = "/Users/gabrielmantegna/Documents/GitHub/GenX/Example_Systems/ldes_conus3z_5days_0p4"

resource_tags = [
    :THERM,
    :HYDRO,
    :VRE,
    :FLEX,
    :MUST_RUN,
    :ELECTROLYZER,
    :STOR,
]

stor_columns = [
    "STOR",
    "Existing_Cap_MWh",
    "Existing_Charge_Cap_MW",
    "Max_Cap_MWh",
    "Max_Charge_Cap_MW",
    "Min_Cap_MWh",
    "Min_Charge_Cap_MW",
    "Inv_Cost_per_MWhyr",
    "Inv_Cost_Charge_per_MWyr",
    "Fixed_OM_Cost_per_MWhyr",
    "Fixed_OM_Cost_Charge_per_MWyr",
    "Var_OM_Cost_per_MWh_In",
    "Self_Disch",
    "Eff_Up",
    "Eff_Down",
    "Min_Duration",
    "Max_Duration",
]

thermal_cols = [
    "THERM",
    "Up_Time",
    "Down_Time",
    "Min_Power",
    "Ramp_Up_Percentage",
    "Ramp_Dn_Percentage",
]

must_run_cols = [
    "MUST_RUN",
]

flex_cols = [
    "FLEX",
    "Flexible_Demand_Energy_Eff",
    "Max_Flexible_Demand_Delay",
    "Max_Flexible_Demand_Advance",
    "Var_OM_Cost_per_MWh_In",
]

vre_cols = [
    "VRE",
    "Num_VRE_Bins"]

hydro_cols = [
    "HYDRO",
    "Hydro_Energy_to_Power_Ratio", 
    "Eff_Up",
    "Eff_Down",
    "Min_Power",
    "Ramp_Up_Percentage",
    "Ramp_Dn_Percentage",]

hydrogen_cols = [
    "ELECTROLYZER",
    "Hydrogen_MWh_Per_Tonne",
    "Electrolyzer_Min_kt",
    "Hydrogen_Price_Per_Tonne",
    "Min_Power",
    "Ramp_Up_Percentage",
    "Ramp_Dn_Percentage",
]

multistage_cols = [
    "WACC",
    "Capital_Recovery_Period",
    "Lifetime",
    "Min_Retired_Cap_MW",
    "Min_Retired_Energy_Cap_MW",
    "Min_Retired_Charge_Cap_MW",
]

case_out_tree = Dict{String, Array{String}}(
    "policies" => [
        "Energy_share_requirement.csv",
        "Energy_share_requirement_slack.csv",
        "Capacity_reserve_margin.csv",
        "Capacity_reserve_margin_slack.csv",
        "Minimum_capacity_requirement.csv",
        "Maximum_capacity_requirement.csv",
        "CO2_cap.csv",
        "CO2_cap_slack.csv",
    ],
    "system" => [
        "Fuels_data.csv",
        "Load_data.csv",
        "Demand_data.csv",
        "Network.csv",
        "Generators_variability.csv",
        "Reserves.csv",
        "Operational_reserves.csv",
        "Vre_and_stor_solar_variability.csv",
        "Vre_and_stor_wind_variability.csv",
        "Period_map.csv",
    ]
)
#################################

# FOLDER STRUCTURE
function restr_casefolder(path_in::AbstractString, path_out::AbstractString)

    isdir(path_out) && (rm(path_out; recursive=true); @warn("$(path_out) already exists. Overwriting it."))
    mkdir(path_out)
    # settings
    create_settings_folder(path_in, path_out)
    # system
    create_system_folder(path_in, path_out, case_out_tree["system"])
    # policies
    create_policies_folder(path_in, path_out, case_out_tree["policies"])
    # split generators data
    split_generators_data(path_in, path_out)
    # copy the "Run.jl" file
    isfile(joinpath(path_in, "Run.jl")) && cp(joinpath(path_in, "Run.jl"), joinpath(path_out, "Run.jl"))
    # TDR folder
    create_tdr_folder(path_in, path_out)

    return nothing
end

function _copy_files(path_in::AbstractString, path_out::AbstractString, filenames::Array{String})
    for file in filenames
        isfile(joinpath(path_in, file)) && cp(joinpath(path_in, file), joinpath(path_out, file))
    end
end

function create_settings_folder(path_in::AbstractString, path_out::AbstractString)
    settings_path_in = joinpath(path_in, "Settings")
    !isdir(settings_path_in) && return nothing
    @info("Creating settings folder")
    settings_path_out = joinpath(path_out, "settings")
    settings_files = readdir(settings_path_in)
    mkpath(settings_path_out)
    _copy_files(settings_path_in, settings_path_out, settings_files)
end

function create_system_folder(path_in::AbstractString, path_out::AbstractString, filenames::Array{String})
    @info("Creating system folder")
    system_path_out = joinpath(path_out, "system")
    mkpath(system_path_out)
    _copy_files(path_in, system_path_out, filenames)
end

function create_policies_folder(path_in::AbstractString, path_out::AbstractString, filenames::Array{String})
    @info("Creating policies folder")
    policies_path_out = joinpath(path_out, "policies")
    mkpath(policies_path_out)
    _copy_files(path_in, policies_path_out, filenames)
end

function create_resources_folder(path_out::AbstractString)
    @info("Creating resources folder")
    resources_folder = joinpath(path_out, "resources")
    policy_folder = joinpath(resources_folder, "policy_assignments")
    mkpath(policy_folder)
    return resources_folder, policy_folder
end

function restr_resourcefile(df::DataFrame, resourcetype_specific_cols::Dict{Symbol, Vector{String}}, resource_tag::Symbol)
    # if resource_tag is not in the dataframe, return an empty dataframe
    String(resource_tag) ∉ names(df) && return DataFrame()
    
    df = df[df[:, resource_tag] .== 1, :]
    cols_to_remove = reduce(vcat, values(filter(((k,v),) -> k != resource_tag, resourcetype_specific_cols)))
    intersect!(cols_to_remove, names(df))
    setdiff!(cols_to_remove, resourcetype_specific_cols[resource_tag])
    # rename the resource_tag to Model for storage and thermal
    if resource_tag == :STOR || resource_tag == :THERM
        rename!(df, Symbol(resource_tag) => :Model)
    else
        push!(cols_to_remove, String(resource_tag))
    end
    df = df[:, Not(cols_to_remove)]
    return df
end

function restr_policyfile!(policy_info::NamedTuple, df::DataFrame)

    # if the policytag is not in the dataframe, return an empty dataframe
    !any(startswith(x, policy_info.oldtag) for x in names(df)) && return DataFrame()
        
    @info("Writing file $(policy_info.filename)")
    data = df[:, Cols(x -> x == "Resource" || startswith(x, policy_info.oldtag))]
    data = data[any.(>(0), eachrow(data[:, 2:end])), :]
    # remote them from df 
    df = select!(df, Not(Cols(x -> startswith(x, policy_info.oldtag))))
    old_names = names(data)
    # first column is the resource name
    for i in 2:length(old_names)
        new_name = Symbol(replace(string(old_names[i]), policy_info.oldtag => policy_info.newtag))
        rename!(data, old_names[i] => new_name)
    end
    return data
end

function create_multistage_file!(df::DataFrame)
    @info("Writing file Resource_multistage_data.csv")
    data = df[:, Cols(x -> x == "Resource" || x in multistage_cols)]
    # remove them from df
    df = select!(df, Not(Cols(x -> x in multistage_cols)))
    return data
end

function upgrade_newbuild_canretire_interface!(df::DataFrame)
    if string(:Can_Retire) ∉ names(df)
        @info("Upgrading the Can_Retire and New_Build interface")
        df.Can_Retire = convert(Vector{Int}, (df.New_Build .!= -1))
        df.New_Build = convert(Vector{Int}, (df.New_Build .== 1))
    end
    return nothing
end

function split_generators_data(path_in::AbstractString, path_out::AbstractString)
    
    # read Generators_data.csv
    dfGen_or = CSV.read(joinpath(path_in, "Generators_data.csv"), DataFrame)
    # remove R_ID
    dfGen_or = "R_ID" in names(dfGen_or) ? select!(dfGen_or, Not(:R_ID)) : dfGen_or
    # upgrade the Can_Retire and New_Build interface
    upgrade_newbuild_canretire_interface!(dfGen_or)

    # create resources and policy folders
    resources_folder, policy_folder = create_resources_folder(path_out)

    # POLICY TAGS 
    policies = (
        esr     = (filename="Resource_energy_share_requirement.csv", oldtag="ESR_", newtag="ESR_"),
        cap_res = (filename="Resource_capacity_reserve_margin.csv", oldtag="CapRes_", newtag="Derating_factor_"),
        min_cap = (filename="Resource_minimum_capacity_requirement.csv", oldtag="MinCapTag_", newtag="Min_Cap_"),
        max_cap = (filename="Resource_maximum_capacity_requirement.csv", oldtag="MaxCapTag_", newtag="Max_Cap_")
    )

    for policy in policies 
        out_file = joinpath(policy_folder, policy.filename)
        data = restr_policyfile!(policy, dfGen_or)
        !isempty(data) && CSV.write(out_file, data, writeheader=true)
    end

    # MULTISTAGE
    if !isempty(intersect(names(dfGen_or), multistage_cols))
        out_file = joinpath(resources_folder, "Resource_multistage_data.csv")
        data = create_multistage_file!(dfGen_or)
        CSV.write(out_file, data, writeheader=true)
    end

    # GENERATORS
    resourcetype_specific_cols = Dict{Symbol, Vector{String}}(
        :THERM => thermal_cols,
        :HYDRO => hydro_cols,
        :VRE => vre_cols,
        :FLEX => flex_cols,
        :ELECTROLYZER => hydrogen_cols,
        :STOR => stor_columns,
        :MUST_RUN => must_run_cols,
    )

    @assert length(resource_tags) == length(resourcetype_specific_cols)
    @assert Set(resource_tags) == Set(keys(resourcetype_specific_cols))

    resourcetype_filenames = (
        THERM = "Thermal.csv",
        HYDRO = "Hydro.csv",
        VRE = "Vre.csv",
        FLEX = "Flex_demand.csv",
        MUST_RUN = "Must_run.csv",
        ELECTROLYZER = "Electrolyzer.csv",
        STOR = "Storage.csv",
    )

    for resource in resource_tags
        out_file = joinpath(resources_folder, resourcetype_filenames[resource])
        data = restr_resourcefile(dfGen_or, resourcetype_specific_cols, resource)
        if !isempty(data)  
            @info("Writing file $(resourcetype_filenames[resource])") 
            CSV.write(out_file, data, writeheader=true)
        end
    end
end

function create_tdr_folder(path_in::AbstractString, path_out::AbstractString)
    tdr_path_in = joinpath(path_in, "TDR_Results")
    tdr_path_out = joinpath(path_out, "TDR_results")
    isdir(tdr_path_in) && (@info("Creating TDR folder"); cp(tdr_path_in, tdr_path_out))
end

# execute the restrucutring
restr_casefolder(PATH_IN, PATH_OUT)
@info("finished")
