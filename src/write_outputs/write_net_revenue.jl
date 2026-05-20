@doc raw"""
	write_net_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model, dfCap::DataFrame, dfESRRev::DataFrame, dfResRevenue::DataFrame, dfChargingcost::DataFrame, dfPower::DataFrame, dfEnergyRevenue::DataFrame, dfSubRevenue::DataFrame, dfRegSubRevenue::DataFrame, dfVreStor::DataFrame, dfOpRegRevenue::DataFrame, dfOpRsvRevenue::DataFrame)

Function for writing net revenue of different generation technologies.
"""
function write_net_revenue(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model,
        dfCap::DataFrame,
        dfESRRev::DataFrame,
        dfResRevenue::DataFrame,
        dfChargingcost::DataFrame,
        dfPower::DataFrame,
        dfEnergyRevenue::DataFrame,
        dfSubRevenue::DataFrame,
        dfRegSubRevenue::DataFrame,
        dfVreStor::DataFrame,
        dfOpRegRevenue::DataFrame,
        dfOpRsvRevenue::DataFrame)
    gen = inputs["RESOURCES"]
    zones = zone_id.(gen)
    regions = region.(gen)
    clusters = cluster.(gen)
    rid = resource_id.(gen)

    G = inputs["G"]     # Number of generators
    COMMIT = inputs["COMMIT"]# Thermal units for unit commitment
    STOR_ALL = inputs["STOR_ALL"]

    if setup["OperationalReserves"] >= 1
        RSV = inputs["RSV"]# Generators contributing to operating reserves
        REG = inputs["REG"]     # Generators contributing to regulation 
    end

    VRE_STOR = inputs["VRE_STOR"]
    CCS = inputs["CCS"]
    if !isempty(VRE_STOR)
        gen_VRE_STOR = gen.VreStorage
        VRE_STOR_LENGTH = size(inputs["VRE_STOR"])[1]
        SOLAR = inputs["VS_SOLAR"]
        WIND = inputs["VS_WIND"]
        DC = inputs["VS_DC"]
        DC_DISCHARGE = inputs["VS_STOR_DC_DISCHARGE"]
        AC_DISCHARGE = inputs["VS_STOR_AC_DISCHARGE"]
        DC_CHARGE = inputs["VS_STOR_DC_CHARGE"]
        AC_CHARGE = inputs["VS_STOR_AC_CHARGE"]
        # Should read in charge asymmetric capacities
    end

    # Create a NetRevenue dataframe
    dfNetRevenue = DataFrame(region = regions,
        Resource = inputs["RESOURCE_NAMES"],
        zone = zones,
        Cluster = clusters,
        R_ID = rid)

    # Add investment cost to the dataframe
    dfNetRevenue.Inv_cost_MW = inv_cost_per_mwyr.(gen) .* dfCap[1:G, :NewCap]
    dfNetRevenue.Inv_cost_MWh = inv_cost_per_mwhyr.(gen) .* dfCap[1:G, :NewEnergyCap]
    dfNetRevenue.Inv_cost_charge_MW = inv_cost_charge_per_mwyr.(gen) .*
                                      dfCap[1:G, :NewChargeCap]
    if !isempty(VRE_STOR)
        # Doesn't include charge capacities
        if !isempty(SOLAR)
            dfNetRevenue.Inv_cost_MW[VRE_STOR] += inv_cost_solar_per_mwyr.(gen_VRE_STOR) .*
                                                  dfVreStor[1:VRE_STOR_LENGTH, :NewCapSolar]
        end
        if !isempty(DC)
            dfNetRevenue.Inv_cost_MW[VRE_STOR] += inv_cost_inverter_per_mwyr.(gen_VRE_STOR) .*
                                                  dfVreStor[1:VRE_STOR_LENGTH, :NewCapDC]
        end
        if !isempty(WIND)
            dfNetRevenue.Inv_cost_MW[VRE_STOR] += inv_cost_wind_per_mwyr.(gen_VRE_STOR) .*
                                                  dfVreStor[1:VRE_STOR_LENGTH, :NewCapWind]
        end
    end
    if setup["ParameterScale"] == 1
        dfNetRevenue.Inv_cost_MWh *= ModelScalingFactor # converting Million US$ to US$
        dfNetRevenue.Inv_cost_MW *= ModelScalingFactor # converting Million US$ to US$
        dfNetRevenue.Inv_cost_charge_MW *= ModelScalingFactor # converting Million US$ to US$
    end

    # Add operations and maintenance cost to the dataframe
    dfNetRevenue.Fixed_OM_cost_MW = fixed_om_cost_per_mwyr.(gen) .* dfCap[1:G, :EndCap]
    dfNetRevenue.Fixed_OM_cost_MWh = fixed_om_cost_per_mwhyr.(gen) .*
                                     dfCap[1:G, :EndEnergyCap]
    dfNetRevenue.Fixed_OM_cost_charge_MW = fixed_om_cost_charge_per_mwyr.(gen) .*
                                           dfCap[1:G, :EndChargeCap]
    dfNetRevenue.Var_OM_cost_out = var_om_cost_per_mwh.(gen) .* dfPower[1:G, :AnnualSum]
    if !isempty(VRE_STOR)
        if !isempty(SOLAR)
            dfNetRevenue.Fixed_OM_cost_MW[VRE_STOR] += fixed_om_solar_cost_per_mwyr.(gen_VRE_STOR) .*
                                                       dfVreStor[1:VRE_STOR_LENGTH,
                :EndCapSolar]
            dfNetRevenue.Var_OM_cost_out[SOLAR] += var_om_cost_per_mwh_solar.(gen[SOLAR]) .*
                                                    (value.(EP[:vP_SOLAR][SOLAR, :]).data .*
                                                    etainverter.(gen[SOLAR]) *
                                                    inputs["omega"])
        end
        if !isempty(WIND)
            dfNetRevenue.Fixed_OM_cost_MW[VRE_STOR] += fixed_om_wind_cost_per_mwyr.(gen_VRE_STOR) .*
                                                       dfVreStor[1:VRE_STOR_LENGTH, :EndCapWind]

            dfNetRevenue.Var_OM_cost_out[WIND] += var_om_cost_per_mwh_wind.(gen[WIND]) .*
                                                    (value.(EP[:vP_WIND][WIND, :]).data *
                                                    inputs["omega"])
        end
        if !isempty(DC)
            dfNetRevenue.Fixed_OM_cost_MW[VRE_STOR] += fixed_om_inverter_cost_per_mwyr.(gen_VRE_STOR) .*
                                                       dfVreStor[1:VRE_STOR_LENGTH, :EndCapDC]
        end
        if !isempty(DC_DISCHARGE)
            dfNetRevenue.Var_OM_cost_out[DC_DISCHARGE] += var_om_cost_per_mwh_discharge_dc.(gen[DC_DISCHARGE]) .*
                                                            (value.(EP[:vP_DC_DISCHARGE][DC_DISCHARGE,:]).data .*
                                                            etainverter.(gen[DC_DISCHARGE]) *
                                                            inputs["omega"])
        end
        if !isempty(AC_DISCHARGE)
            dfNetRevenue.Var_OM_cost_out[AC_DISCHARGE] += var_om_cost_per_mwh_discharge_ac.(gen[AC_DISCHARGE]) .*
                                                          (value.(EP[:vP_AC_DISCHARGE][AC_DISCHARGE,:]).data * inputs["omega"])
        end
    end
    if setup["ParameterScale"] == 1
        dfNetRevenue.Fixed_OM_cost_MW *= ModelScalingFactor # converting Million US$ to US$
        dfNetRevenue.Fixed_OM_cost_MWh *= ModelScalingFactor # converting Million US$ to US$
        dfNetRevenue.Fixed_OM_cost_charge_MW *= ModelScalingFactor # converting Million US$ to US$
        dfNetRevenue.Var_OM_cost_out *= ModelScalingFactor # converting Million US$ to US$
    end

    # Add fuel cost to the dataframe
    dfNetRevenue.Fuel_cost = sum(value.(EP[:ePlantCFuelOut]), dims = 2)
    if setup["ParameterScale"] == 1
        dfNetRevenue.Fuel_cost *= ModelScalingFactor^2 # converting Million US$ to US$
    end

    # Add storage cost to the dataframe
    dfNetRevenue.Var_OM_cost_in = zeros(nrow(dfNetRevenue))
    if !isempty(STOR_ALL)
        dfNetRevenue.Var_OM_cost_in[STOR_ALL] = var_om_cost_per_mwh_in.(gen.Storage) .*
                                                ((value.(EP[:vCHARGE][STOR_ALL, :]).data) *
                                                 inputs["omega"])
    end
    if !isempty(VRE_STOR)
        if !isempty(DC_CHARGE)
            dfNetRevenue.Var_OM_cost_in[DC_CHARGE] += var_om_cost_per_mwh_charge_dc.(gen[DC_CHARGE]) .*
                                                      (value.(EP[:vP_DC_CHARGE][DC_CHARGE,:]).data ./
                                                       etainverter.(gen[DC_CHARGE]) *
                                                       inputs["omega"])
        end
        if !isempty(AC_CHARGE)
            dfNetRevenue.Var_OM_cost_in[AC_CHARGE] += var_om_cost_per_mwh_charge_ac.(gen[AC_CHARGE]) .*
                                                      (value.(EP[:vP_AC_CHARGE][AC_CHARGE, :]).data * inputs["omega"])
        end
    end

    if setup["ParameterScale"] == 1
        dfNetRevenue.Var_OM_cost_in *= ModelScalingFactor^2 # converting Million US$ to US$
    end
    # Add start-up cost to the dataframe
    dfNetRevenue.StartCost = zeros(nrow(dfNetRevenue))
    if setup["UCommit"] >= 1 && !isempty(COMMIT)
        start_costs = vec(sum(value.(EP[:eCStart][COMMIT, :]).data, dims = 2))
        start_fuel_costs = vec(value.(EP[:ePlantCFuelStart][COMMIT]))
        dfNetRevenue.StartCost[COMMIT] .= start_costs + start_fuel_costs
    end
    if setup["ParameterScale"] == 1
        dfNetRevenue.StartCost *= ModelScalingFactor^2 # converting Million US$ to US$
    end
    # Add charge cost to the dataframe
    dfNetRevenue.Charge_cost = zeros(nrow(dfNetRevenue))
    if has_duals(EP)
        dfNetRevenue.Charge_cost = dfChargingcost[1:G, :AnnualSum] # Unit is confirmed to be US$
    end

    # Add CO2 releated sequestration cost or credit (e.g. 45 Q) to the dataframe
    dfNetRevenue.CO2SequestrationCost = zeros(nrow(dfNetRevenue))
    if any(co2_capture_fraction.(gen) .!= 0)
        dfNetRevenue.CO2SequestrationCost = zeros(G)
        dfNetRevenue[CCS, :CO2SequestrationCost] = value.(EP[:ePlantCCO2Sequestration]).data
    end
    if setup["ParameterScale"] == 1
        dfNetRevenue.CO2SequestrationCost *= ModelScalingFactor^2 # converting Million US$ to US$
    end

    # Add energy and subsidy revenue to the dataframe
    dfNetRevenue.EnergyRevenue = zeros(nrow(dfNetRevenue))
    dfNetRevenue.SubsidyRevenue = zeros(nrow(dfNetRevenue))
    if has_duals(EP)
        dfNetRevenue.EnergyRevenue = dfEnergyRevenue[1:G, :AnnualSum] # Unit is confirmed to be US$
        dfNetRevenue.SubsidyRevenue = dfSubRevenue[1:G, :SubsidyRevenue] # Unit is confirmed to be US$
    end

    # Add energy and subsidy revenue to the dataframe
    dfNetRevenue.OperatingReserveRevenue = zeros(nrow(dfNetRevenue))
    dfNetRevenue.OperatingRegulationRevenue = zeros(nrow(dfNetRevenue))
    if setup["OperationalReserves"] > 0 && has_duals(EP)
        dfNetRevenue.OperatingReserveRevenue[RSV] = dfOpRsvRevenue.AnnualSum # Unit is confirmed to be US$
        dfNetRevenue.OperatingRegulationRevenue[REG] = dfOpRegRevenue.AnnualSum # Unit is confirmed to be US$
    end

    # Add capacity revenue to the dataframe
    dfNetRevenue.ReserveMarginRevenue = zeros(nrow(dfNetRevenue))
    if setup["CapacityReserveMargin"] > 0 && has_duals(EP) # The unit is confirmed to be $
        dfNetRevenue.ReserveMarginRevenue = dfResRevenue[1:G, :AnnualSum]
    end

    # Add RPS/CES revenue to the dataframe
    dfNetRevenue.ESRRevenue = zeros(nrow(dfNetRevenue))
    if setup["EnergyShareRequirement"] > 0 && has_duals(EP) # The unit is confirmed to be $
        dfNetRevenue.ESRRevenue = dfESRRev[1:G, :Total]
    end

    # Calculate emissions cost
    dfNetRevenue.EmissionsCost = zeros(nrow(dfNetRevenue))
    if setup["CO2Cap"] >= 1 && has_duals(EP)
        for cap in 1:inputs["NCO2Cap"]
            co2_cap_dual = dual(EP[:cCO2Emissions_systemwide][cap])
            CO2ZONES = findall(x -> x == 1, inputs["dfCO2CapZones"][:, cap])
            GEN_IN_ZONE = resource_id.(gen[[y in CO2ZONES for y in zone_id.(gen)]])
            if setup["CO2Cap"] == 1 || setup["CO2Cap"] == 2 # Mass-based or Demand + Rate-based
                # Cost = sum(sum(emissions for zone z * dual(CO2 constraint[cap]) for z in Z) for cap in setup["NCO2"])
                temp_vec = value.(EP[:eEmissionsByPlant][GEN_IN_ZONE, :]) * inputs["omega"]
                dfNetRevenue.EmissionsCost[GEN_IN_ZONE] += -co2_cap_dual * temp_vec
            elseif setup["CO2Cap"] == 3 # Generation + Rate-based
                SET_WITH_MAXCO2RATE = union(inputs["THERM_ALL"],
                    inputs["VRE"],
                    inputs["VRE"],
                    inputs["MUST_RUN"],
                    inputs["HYDRO_RES"])
                Y = intersect(GEN_IN_ZONE, SET_WITH_MAXCO2RATE)
                temp_vec = (value.(EP[:eEmissionsByPlant][Y, :]) -
                            (value.(EP[:vP][Y, :]) .*
                             inputs["dfMaxCO2Rate"][zone_id.(gen[Y]), cap])) *
                           inputs["omega"]
                dfNetRevenue.EmissionsCost[Y] += -co2_cap_dual * temp_vec
            end
        end
        if setup["ParameterScale"] == 1
            dfNetRevenue.EmissionsCost *= ModelScalingFactor^2 # converting Million US$ to US$
        end
    end

    # Add regional technology subsidy revenue to the dataframe
    dfNetRevenue.RegSubsidyRevenue = zeros(nrow(dfNetRevenue))
    if setup["MinCapReq"] >= 1 && has_duals(EP)# The unit is confirmed to be US$
        dfNetRevenue.RegSubsidyRevenue = dfRegSubRevenue[1:G, :SubsidyRevenue]
    end

    dfNetRevenue.Revenue = dfNetRevenue.EnergyRevenue
    .+dfNetRevenue.SubsidyRevenue
    .+dfNetRevenue.ReserveMarginRevenue
    .+dfNetRevenue.ESRRevenue
    .+dfNetRevenue.RegSubsidyRevenue
    .+dfNetRevenue.OperatingReserveRevenue
    .+dfNetRevenue.OperatingRegulationRevenue

    dfNetRevenue.Cost = (dfNetRevenue.Inv_cost_MW .+
                         dfNetRevenue.Inv_cost_MWh .+
                         dfNetRevenue.Inv_cost_charge_MW .+
                         dfNetRevenue.Fixed_OM_cost_MW .+
                         dfNetRevenue.Fixed_OM_cost_MWh .+
                         dfNetRevenue.Fixed_OM_cost_charge_MW .+
                         dfNetRevenue.Var_OM_cost_out .+
                         dfNetRevenue.Var_OM_cost_in .+
                         dfNetRevenue.Fuel_cost .+
                         dfNetRevenue.Charge_cost .+
                         dfNetRevenue.EmissionsCost .+
                         dfNetRevenue.StartCost .+
                         dfNetRevenue.CO2SequestrationCost)
    dfNetRevenue.Profit = dfNetRevenue.Revenue .- dfNetRevenue.Cost

    CSV.write(joinpath(path, "NetRevenue.csv"), dfNetRevenue)
end
