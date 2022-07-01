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
	write_co2_load_emission_rate_cap_price_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting carbon price of load emission rate carbon cap.

"""
function write_co2_load_emission_rate_cap_price_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    # L = inputs["L"]     # Number of transmission lines
    # W = inputs["REP_PERIOD"]     # Number of subperiods
    SEG = inputs["SEG"] # Number of load curtailment segments
    STOR_ALL = inputs["STOR_ALL"]

    dfCO2GenRatePrice = DataFrame(CO2_LoadRate_Constraint = [Symbol("CO2_LoadRate_Cap_$cap") for cap = 1:inputs["NCO2LoadRateCap"]],
                            CO2_LoadRate_Price = (-1) * (dual.(EP[:cCO2Emissions_loadrate])),
                            CO2_LoadRate_Slack = value.(EP[:vCO2Emissions_loadrate_slack]),
                            CO2_LoadRate_Penalty = value.(EP[:eCCO2Emissions_loadrate_slack]))
    if setup["ParameterScale"] == 1
        dfCO2GenRatePrice.CO2_LoadRate_Price .*= ModelScalingFactor
        dfCO2GenRatePrice.CO2_LoadRate_Slack .*= ModelScalingFactor
        dfCO2GenRatePrice.CO2_LoadRate_Penalty .*= ModelScalingFactor^2
    end
    CSV.write(joinpath(path, "CO2Price_n_penalty_loadrate.csv"), dfCO2GenRatePrice)

    CO2CapEligibleLoad = DataFrame(CO2CapEligibleLoad_MWh = (transpose(inputs["pD"] - value.(EP[:eZonalNSE])) * inputs["omega"]))
    Storageloss = DataFrame(Storageloss_MWh = zeros(Z))
    if !isempty(inputs["STOR_ALL"])
        if (setup["StorageLosses"] == 1)
            Storageloss.Storageloss_MWh .= value.(EP[:eStorageLossByZone])
        end
    end
    Transmissionloss = DataFrame(Transmissionloss_MWh = zeros(Z))
    if Z > 1
        if (setup["PolicyTransmissionLossCoverage"] == 1)
            Transmissionloss.Transmissionloss_MWh .= 0.5 * value.(EP[:eTransLossByZoneYear])
        end
    end
    dfCO2LoadRateCapRev = DataFrame(Zone=1:Z, AnnualSum=zeros(Z))
    for cap = 1:inputs["NCO2LoadRateCap"]
        temp_CO2LoadRateCapRev = zeros(Z, 3)
        temp_CO2LoadRateCapRev[:, 1] = (-1) * (dual.(EP[:cCO2Emissions_loadrate])[cap]) * (inputs["dfCO2Cap_LoadRate"][:, Symbol("CO_2_Max_LoadRate_$cap")]) .* (inputs["dfCO2Cap_LoadRate"][:, Symbol("CO_2_Cap_Zone_$cap")]) .* CO2CapEligibleLoad[!, :CO2CapEligibleLoad_MWh]
        temp_CO2LoadRateCapRev[:, 2] = (-1) * (dual.(EP[:cCO2Emissions_loadrate])[cap]) * (inputs["dfCO2Cap_LoadRate"][:, Symbol("CO_2_Max_LoadRate_$cap")]) .* (inputs["dfCO2Cap_LoadRate"][:, Symbol("CO_2_Cap_Zone_$cap")]) .* Storageloss[!, :Storageloss_MWh]
        temp_CO2LoadRateCapRev[:, 3] = (-1) * (dual.(EP[:cCO2Emissions_loadrate])[cap]) * (inputs["dfCO2Cap_LoadRate"][:, Symbol("CO_2_Max_LoadRate_$cap")]) .* (inputs["dfCO2Cap_LoadRate"][:, Symbol("CO_2_Cap_Zone_$cap")]) .* Transmissionloss[!, :Transmissionloss_MWh]
        if setup["ParameterScale"] == 1
            temp_CO2LoadRateCapRev *= (ModelScalingFactor^2)
        end
        dfCO2LoadRateCapRev.AnnualSum .+= vec(sum(temp_CO2LoadRateCapRev, dims=2))
        dfCO2LoadRateCapRev = hcat(dfCO2LoadRateCapRev, DataFrame(temp_CO2LoadRateCapRev, [Symbol("CO2_LoadRateCap_Revenue_$cap"); Symbol("CO2_LoadRateCap_Revenue_StorageLoss_$cap"); Symbol("CO2_LoadRateCap_Revenue_Transmissionloss_$cap")]))
    end
    CSV.write(joinpath(path, "CO2Revenue_loadrate.csv"), dfCO2LoadRateCapRev)

    dfCO2LoadRateCapCost = DataFrame(Resource=inputs["RESOURCES"], AnnualSum=zeros(G))
    for cap = 1:inputs["NCO2LoadRateCap"]
        temp_CO2MassCapCost = zeros(G)
        GEN_UNDERCAP = findall(x -> x == 1, (inputs["dfCO2Cap_LoadRate"][dfGen[:, :Zone], Symbol("CO_2_Cap_Zone_$cap")]))
        temp_CO2MassCapCost[GEN_UNDERCAP] = (-1) * (dual.(EP[:cCO2Emissions_loadrate])[cap]) * (value.(EP[:eEmissionsByPlantYear][GEN_UNDERCAP]))
        if setup["ParameterScale"] == 1
            temp_CO2MassCapCost *= (ModelScalingFactor^2)
        end
        dfCO2LoadRateCapCost.AnnualSum .+= temp_CO2MassCapCost
        dfCO2LoadRateCapCost = hcat(dfCO2LoadRateCapCost, DataFrame([temp_CO2MassCapCost], [Symbol("CO2_LoadRateCap_Cost_$cap")]))
    end
    CSV.write(joinpath(path, "CO2Cost_loadrate.csv"), dfCO2LoadRateCapCost)

    return dfCO2GenRatePrice, dfCO2LoadRateCapRev, dfCO2LoadRateCapCost
end