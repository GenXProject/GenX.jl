@doc raw"""
	write_co2(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting time-dependent CO2 emissions by zone.

"""
function write_co2(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    write_co2_emissions_plant(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    write_co2_capture_plant(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
end

function write_co2_emissions_plant(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)

    gen = inputs["RESOURCES"]  # Resources (objects)
    resources = inputs["RESOURCE_NAMES"] # Resource names
    zones = zone_id.(gen)

    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)

    weight = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    emissions_plant = value.(EP[:eEmissionsByPlant])
    emissions_plant *= scale_factor

    df = DataFrame(Resource = resources,
        Zone = zones,
        AnnualSum = zeros(G))
    df.AnnualSum .= emissions_plant * weight

    write_temporal_data(df, emissions_plant, path, setup, "emissions_plant")
    return nothing
end

function write_co2_capture_plant(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    gen = inputs["RESOURCES"]   # Resources (objects)
    CCS = inputs["CCS"]

    resources = inputs["RESOURCE_NAMES"][CCS]   # Resource names
    zones = zone_id.(gen[CCS])

    weight = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    df = DataFrame(Resource = resources,
        Zone = zones,
        AnnualSum = zeros(length(CCS)))
    if !isempty(CCS)
        emissions_captured_plant = value.(EP[:eEmissionsCaptureByPlant]).data
        emissions_captured_plant *= scale_factor

        df.AnnualSum .= emissions_captured_plant * weight

        write_temporal_data(
            df, emissions_captured_plant, path, setup, "captured_emissions_plant")
    end
    return nothing
end
