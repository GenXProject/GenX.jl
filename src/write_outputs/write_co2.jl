@doc raw"""
	write_co2(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting time-dependent CO2 emissions by zone.

"""
function write_co2(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones

    # CO2 emissions by plant
    dfEmissions_plant = DataFrame(Resource=inputs["RESOURCES"], Zone=dfGen[!, :Zone], AnnualSum=zeros(G))
    emissions_plant = value.(EP[:eEmissionsByPlant])
    if setup["ParameterScale"] == 1
        emissions_plant *= ModelScalingFactor
    end
    dfEmissions_plant.AnnualSum .= emissions_plant * inputs["omega"]
    dfEmissions_plant = hcat(dfEmissions_plant, DataFrame(emissions_plant, :auto))

    auxNew_Names = [Symbol("Resource"); Symbol("Zone"); Symbol("AnnualSum"); [Symbol("t$t") for t = 1:T]]
    rename!(dfEmissions_plant, auxNew_Names)

    total = DataFrame(["Total" 0 sum(dfEmissions_plant[!, :AnnualSum]) fill(0.0, (1, T))], auxNew_Names)
    total[!, 4:T+3] .= sum(emissions_plant, dims=1)
    dfEmissions_plant = vcat(dfEmissions_plant, total)
    CSV.write(joinpath(path, "emissions_plant.csv"), dftranspose(dfEmissions_plant, false), writeheader=false)
    
    dfCapturedEmissions_plant = DataFrame(Resource=inputs["RESOURCES"], Zone=dfGen[!, :Zone], AnnualSum=zeros(G))
    if any(x -> x != 0, dfGen.CO2_Capture_Rate)
        # Captured CO2 emissions by plant
        emissions_captured_plant = zeros(G, T)
        emissions_captured_plant = (value.(EP[:eEmissionsCaptureByPlant]))
        if setup["ParameterScale"] == 1
            emissions_captured_plant *= ModelScalingFactor
        end
        dfCapturedEmissions_plant.AnnualSum .= emissions_captured_plant * inputs["omega"]
        dfCapturedEmissions_plant = hcat(dfCapturedEmissions_plant, DataFrame(emissions_captured_plant, :auto))

        auxNew_Names = [Symbol("Resource"); Symbol("Zone"); Symbol("AnnualSum"); [Symbol("t$t") for t = 1:T]]
        rename!(dfCapturedEmissions_plant, auxNew_Names)

        total = DataFrame(["Total" 0 sum(dfCapturedEmissions_plant[!, :AnnualSum]) fill(0.0, (1, T))], auxNew_Names)
        total[!, 4:T+3] .= sum(emissions_captured_plant, dims=1)
        dfCapturedEmissions_plant = vcat(dfCapturedEmissions_plant, total)

        CSV.write(joinpath(path, "captured_emissions_plant.csv"), dftranspose(dfCapturedEmissions_plant, false), writeheader=false)
    end

    return dfEmissions_plant, dfCapturedEmissions_plant
end
