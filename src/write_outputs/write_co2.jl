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

    # CO2 emissions by plant
    dfEmissions_plant = DataFrame(Resource = inputs["RESOURCE_NAMES"],
        Zone = zone_id.(gen),
        AnnualSum = zeros(G))
    emissions_plant = value.(EP[:eEmissionsByPlant])

    if setup["ParameterScale"] == 1
        emissions_plant *= ModelScalingFactor
    end
    dfEmissions_plant.AnnualSum .= emissions_plant * inputs["omega"]

    filepath = joinpath(path, "emissions_plant.csv")
    if setup["WriteOutputs"] == "annual"
        write_annual(filepath, dfEmissions_plant)
    else # setup["WriteOutputs"] == "full"
        write_fulltimeseries(filepath, emissions_plant, dfEmissions_plant)
    end
    return nothing
end

function write_co2_capture_plant(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    gen = inputs["RESOURCES"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    CCS = inputs["CCS"]
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones

    dfCapturedEmissions_plant = DataFrame(Resource = inputs["RESOURCE_NAMES"][CCS],
        Zone = zone_id.(gen[CCS]),
        AnnualSum = zeros(length(CCS)))
    if !isempty(CCS)
        # Captured CO2 emissions by plant
        emissions_captured_plant = (value.(EP[:eEmissionsCaptureByPlant]).data)

        if setup["ParameterScale"] == 1
            emissions_captured_plant *= ModelScalingFactor
        end
        dfCapturedEmissions_plant.AnnualSum .= emissions_captured_plant * inputs["omega"]

        filepath = joinpath(path, "captured_emissions_plant.csv")
        if setup["WriteOutputs"] == "annual"
            write_annual(filepath, dfCapturedEmissions_plant)
        else     # setup["WriteOutputs"] == "full"
            write_fulltimeseries(filepath,
                emissions_captured_plant,
                dfCapturedEmissions_plant)
        end
        return nothing
    end
end
