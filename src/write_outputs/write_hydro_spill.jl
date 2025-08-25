@doc raw"""
	write_hydro_spill(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the different values of spilled power from hydro power.
"""
function write_hydro_spill(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    gen = inputs["RESOURCES"]   # Resources (objects)
    resources = inputs["RESOURCE_NAMES"]    # Resource names
    zones = zone_id.(gen)
    HYDRO_RES = inputs["HYDRO_RES"]         # Set of all reservoir hydro resources,
    T = inputs["T"]                         # Number of time steps (hours)
    G = inputs["G"]
    
    weight = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    # Power injected by each resource in each time step
    spillage = zeros(G, T)
    spillage[HYDRO_RES, :] = value.(EP[:vSPILL])

    spillage *= scale_factor
    # annual_spillage = spillage * weight

    df = DataFrame(Resource = resources,
        Zone = zones,
        AnnualSum = zeros(G))
    df.AnnualSum = spillage * weight

    write_temporal_data(df, spillage, path, setup, "hydro_spill")
    return df
end
