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

    write_temporal_data(df, emissions_plant, path, setup, setup["WriteResultsNamesDict"]["emissions"])
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

<<<<<<< HEAD
<<<<<<< HEAD
        write_temporal_data(
            df, emissions_captured_plant, path, setup, "captured_emissions_plant")
=======
        filepath = joinpath(path, setup["WriteResultsNamesDict"]["captured_emissions_plant_name"])
=======
        filepath = joinpath(path, setup["WriteResultsNamesDict"]["captured_emissions_plant"])
>>>>>>> d3f7a43f6 (Added write_output_file to all results)
        if setup["WriteOutputs"] == "annual"
            write_annual(filepath, dfCapturedEmissions_plant, setup)
        else     # setup["WriteOutputs"] == "full"
            write_fulltimeseries(filepath,
                emissions_captured_plant,
                dfCapturedEmissions_plant,
                setup)
        end
        return nothing
>>>>>>> 8a69955c2 (Added write_output_file to take in parquet and json filetypes)
    end
    return nothing
end
