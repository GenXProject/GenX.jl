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
	write_co2_load_emission_rate_cap_price_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting carbon price of load emission rate carbon cap.

"""
function write_co2_load_emission_rate_cap_price_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    # L = inputs["L"]     # Number of transmission lines
    # W = inputs["REP_PERIOD"]     # Number of subperiods
    SEG = inputs["SEG"] # Number of load curtailment segments

    tempCO2Price = zeros(Z, inputs["NCO2LoadRateCap"])
    for cap = 1:inputs["NCO2LoadRateCap"]
        tempCO2Price[:, cap] .= (-1) * (dual.(EP[:cCO2Emissions_loadrate])[cap]) .* inputs["dfCO2LoadRateCapZones"][:, cap]
        if setup["ParameterScale"] == 1
            # when scaled, The dual variable is in unit of Million US$/kton, thus k$/ton, to get $/ton, multiply 1000
            tempCO2Price = tempCO2Price * ModelScalingFactor
        end
    end
    dfCO2LoadRatePrice = hcat(DataFrame(Zone = 1:Z), DataFrame(tempCO2Price, [Symbol("CO2_LoadRate_Price_$cap") for cap = 1:inputs["NCO2LoadRateCap"]]))
    # auxNew_Names = [Symbol("Zone"); [Symbol("CO2_LoadRate_Price_$cap") for cap = 1:inputs["NCO2LoadRateCap"]]]
    # rename!(dfCO2LoadRatePrice, auxNew_Names)
    CSV.write(string(path, sep, "CO2Price_loadrate.csv"), dfCO2LoadRatePrice)


    temp_NSE = sum(value.(EP[:vNSE])[s, :, :] for s = 1:SEG) # nse is [S x T x Z], thus temp_NSE is [T x Z]
    CO2CapEligibleLoad = DataFrame(CO2CapEligibleLoad_MWh = (transpose(inputs["pD"] - temp_NSE) * inputs["omega"]))
    Storageloss = DataFrame(Storageloss_MWh = (setup["StorageLosses"] * value.(EP[:eELOSSByZone])))



    dfCO2LoadRateCapRev = DataFrame(Zone = 1:Z, AnnualSum = zeros(Z))
    for cap = 1:inputs["NCO2LoadRateCap"]
        temp_CO2LoadRateCapRev = zeros(Z, 2)
        temp_CO2LoadRateCapRev[:, 1] = (-1) * (dual.(EP[:cCO2Emissions_loadrate])[cap]) * (inputs["dfCO2LoadRateCapZones"][:, cap]) .* (inputs["dfMaxCO2LoadRate"][:, cap]) .* CO2CapEligibleLoad[!, :CO2CapEligibleLoad_MWh]
        temp_CO2LoadRateCapRev[:, 2] = (-1) * (dual.(EP[:cCO2Emissions_loadrate])[cap]) * (inputs["dfCO2LoadRateCapZones"][:, cap]) .* (inputs["dfMaxCO2LoadRate"][:, cap]) .* Storageloss[!, :Storageloss_MWh]
        if setup["ParameterScale"] == 1
            temp_CO2LoadRateCapRev = temp_CO2LoadRateCapRev * (ModelScalingFactor^2)
        end
        # print(temp_CO2LoadRateCapRev)
        dfCO2LoadRateCapRev.AnnualSum .= dfCO2LoadRateCapRev.AnnualSum + vec(sum(temp_CO2LoadRateCapRev, dims = 2))
        dfCO2LoadRateCapRev = hcat(dfCO2LoadRateCapRev, DataFrame(temp_CO2LoadRateCapRev, [Symbol("CO2_LoadRateCap_Revenue_$cap"); Symbol("CO2_LoadRateCap_Revenue_StorageLoss_$cap")]))
    end
    # dfCO2LoadRateCapRev.AnnualSum = sum(eachcol(dfCO2LoadRateCapRev[:, 3:(2*inputs["NCO2LoadRateCap"]+2)]))
    CSV.write(string(path, sep, "CO2Revenue_loadrate.csv"), dfCO2LoadRateCapRev)

    dfCO2LoadRateCapCost = DataFrame(Resource = inputs["RESOURCES"], AnnualSum = zeros(G))
    for cap = 1:inputs["NCO2LoadRateCap"]
        temp_CO2MassCapCost = zeros(G)
        GEN_UNDERCAP = findall(x -> x == 1, (inputs["dfCO2LoadRateCapZones"][dfGen[:, :Zone], cap]))
        temp_CO2MassCapCost[GEN_UNDERCAP] = (-1) * (dual.(EP[:cCO2Emissions_loadrate])[cap]) * (value.(EP[:eEmissionsByPlantYear][GEN_UNDERCAP]))
        if setup["ParameterScale"] == 1
            temp_CO2MassCapCost = temp_CO2MassCapCost * (ModelScalingFactor^2)
        end
        dfCO2LoadRateCapCost.AnnualSum .= dfCO2LoadRateCapCost.AnnualSum + temp_CO2MassCapCost
        dfCO2LoadRateCapCost = hcat(dfCO2LoadRateCapCost, DataFrame([temp_CO2MassCapCost], [Symbol("CO2_LoadRateCap_Cost_$cap")]))
    end
    # dfCO2LoadRateCapCost.AnnualSum = sum(eachcol(dfCO2LoadRateCapCost[:, 3:inputs["NCO2LoadRateCap"]+2]))
    CSV.write(string(path, sep, "CO2Cost_loadrate.csv"), dfCO2LoadRateCapCost)

    return dfCO2LoadRatePrice, dfCO2LoadRateCapRev, dfCO2LoadRateCapCost
end