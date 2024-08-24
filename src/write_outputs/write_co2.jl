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
    gen = inputs["RESOURCES"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)

    emissions_plant = value.(EP[:eEmissionsByPlant])

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    emissions_plant *= scale_factor

    df = DataFrame(Resource = inputs["RESOURCE_NAMES"],
        Zone = zone_id.(gen),
        AnnualSum = zeros(G))
    df.AnnualSum .= emissions_plant * inputs["omega"]

    write_temporal_data(df, emissions_plant, path, setup, "emissions_plant")
    return nothing
end

function write_co2_capture_plant(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    gen = inputs["RESOURCES"]
    CCS = inputs["CCS"]
    resources = inputs["RESOURCE_NAMES"][CCS]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    zones = zone_id.(gen[CCS])
    T = inputs["T"]     # Number of time steps (hours)
    weight = inputs["omega"]

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    df = DataFrame(Resource = resources,
        Zone = zones,
        AnnualSum = zeros(length(CCS)))
    if !isempty(CCS)
        emissions_captured_plant = value.(EP[:eEmissionsCaptureByPlant]).data

        emissions_captured_plant *= scale_factor

        df.AnnualSum .= emissions_captured_plant * weight

        write_temporal_data(df, emissions_capture_plant, path, setup, "captured_emissions_plant")
    end
    return nothing
end
