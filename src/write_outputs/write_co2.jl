"""
GenX: An Configurable Capacity Expansion Model
Copyright (C) 2021,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

@doc raw"""
	write_co2(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting time-dependent CO$_2$ emissions by zone.

"""
function write_co2(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones

    # CO2 emissions by zone

    dfEmissions = DataFrame(Zone=1:Z, AnnualSum=zeros(Float64, Z))

    emissions_zone = zeros(Z, T)
    emissions_zone = value.(EP[:eEmissionsByZone])
    if setup["ParameterScale"] == 1
        emissions_zone *= ModelScalingFactor
    end
    dfEmissions.AnnualSum .= emissions_zone * inputs["omega"]
    dfEmissions = hcat(dfEmissions, DataFrame(emissions_zone, :auto))

    auxNew_Names = [Symbol("Zone"); Symbol("AnnualSum"); [Symbol("t$t") for t = 1:T]]
    rename!(dfEmissions, auxNew_Names)

    total = DataFrame(["Total" sum(dfEmissions[!, :AnnualSum]) fill(0.0, (1, T))], auxNew_Names)
    total[!, 3:T+2] .= sum(emissions_zone, dims=1)
    dfEmissions = vcat(dfEmissions, total)
    CSV.write(joinpath(path, "emissions.csv"), dftranspose(dfEmissions, false), writeheader=false)

    # CO2 emissions by plant
    dfEmissions_plant = DataFrame(Resource=inputs["RESOURCES"], Zone=dfGen[!, :Zone], AnnualSum=zeros(G))
    emissions_plant = zeros(G, T)
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
    if setup["CO2Capture"] == 1
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

    return dfEmissions, dfEmissions_plant, dfCapturedEmissions_plant
end
