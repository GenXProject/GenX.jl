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
	vre_stor(EP::Model, inputs::Dict, setup::Dict)

"""
function vre_stor!(EP::Model, inputs::Dict, setup::Dict)

	println("VRE-Storage Module")

    ### LOAD DATA ###

    # Load generators dataframe, sets, and time periods
	dfGen = inputs["dfGen"]
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones

    # Policy flags
    EnergyShareRequirement = setup["EnergyShareRequirement"]
	CapacityReserveMargin = setup["CapacityReserveMargin"]
    StorageLosses = setup["StorageLosses"]

    # Load VRE-storage inputs
	VRE_STOR = inputs["VRE_STOR"] 	                                # Set of VRE-STOR generators
    dfVRE_STOR = inputs["dfVRE_STOR"]                               # Dataframe of VRE-STOR specific parameters

    SOLAR = inputs["VS_SOLAR"]                                      # Set of VRE-STOR generators with solar-component
    DC = inputs["VS_DC"]                                            # Set of VRE-STOR generators with inverter-component
    WIND = inputs["VS_WIND"]                                        # Set of VRE-STOR generators with wind-component
    STOR = inputs["VS_STOR"]                                        # Set of VRE-STOR generators with storage-component

    by_rid(rid, sym) = by_rid_df(rid, sym, dfVRE_STOR)

    ### VARIABLES ###

    # All of these variables are indexed for each generator because they are created to interface with the energy balance
    @variables(EP, begin

        # Solar-component generation [MWh]
        vP_SOLAR[y in VRE_STOR, t=1:T] >= 0

        # Wind-component generation [MWh]
        vP_WIND[y in VRE_STOR, t=1:T] >= 0

        # DC-battery discharge [MWh]
        vP_DC_DISCHARGE[y in VRE_STOR, t=1:T] >= 0

        # DC-battery charge [MWh]
        vP_DC_CHARGE[y in VRE_STOR, t=1:T] >= 0

        # AC-battery discharge [MWh]
        vP_AC_DISCHARGE[y in VRE_STOR, t=1:T] >= 0

        # AC-battery charge [MWh]
        vP_AC_CHARGE[y in VRE_STOR, t=1:T] >= 0

        # Grid-interfacing charge (Energy withdrawn from grid by resource VRE_STOR at hour "t") [MWh]
        vCHARGE_VRE_STOR[y in VRE_STOR,t=1:T] >= 0
    end)
   
	### EXPRESSIONS ###

    ## 1. Objective Function Expressions ##

    # Separate grid costs
    @expression(EP, eTotalCGrid, sum(dfGen[y, :Inv_Cost_per_MWyr]*EP[:vCAP][y]
                                    + dfGen[y,:Fixed_OM_Cost_per_MWyr]*EP[:eTotalCap][y] for y in VRE_STOR))

	## 2. Power Balance Expressions ##
	@expression(EP, ePowerBalance_VRE_STOR[t=1:T, z=1:Z],
	sum(EP[:vP][y,t]-vCHARGE_VRE_STOR[y,t] for y=dfVRE_STOR[(dfVRE_STOR[!,:Zone].==z),:][!,:R_ID]))
	EP[:ePowerBalance] += ePowerBalance_VRE_STOR

    ## 3. Policy Expressions ##

    # Energy losses related to technologies (increase in effective demand)
    @expression(EP, eELOSS_VRE_STOR[y in VRE_STOR], sum(inputs["omega"][t]*(vP_DC_CHARGE[y,t]/by_rid(y, :EtaInverter) + vP_AC_CHARGE[y,t] - vP_DC_DISCHARGE[y,t]/by_rid(y, :EtaInverter) - vP_AC_DISCHARGE[y,t]) for t in 1:T))
    
    # From CO2 Policy module
	@expression(EP, eELOSSByZone_VRE_STOR[z=1:Z],
        sum(EP[:eELOSS_VRE_STOR][y] for y in intersect(VRE_STOR, dfGen[dfGen[!,:Zone].==z,:R_ID]))
    )

    # Energy Share Requirement
    if EnergyShareRequirement >= 1
        @expression(EP, eESRVREStor[ESR=1:inputs["nESR"]], sum(inputs["omega"][t]*by_rid(y,Symbol("ESR_$ESR"))*EP[:vP_SOLAR][y,t]*by_rid(y, :EtaInverter) for y=dfVRE_STOR[findall(x->x>0,dfVRE_STOR[!,Symbol("ESR_$ESR")]),:R_ID], t=1:T)
                        + sum(inputs["omega"][t]*by_rid(y,Symbol("ESR_$ESR"))*EP[:vP_WIND][y,t] for y=dfVRE_STOR[findall(x->x>0,dfVRE_STOR[!,Symbol("ESR_$ESR")]),:R_ID], t=1:T)
						- sum(inputs["dfESR"][z,ESR]*StorageLosses*sum(EP[:eELOSS_VRE_STOR][y] for y=dfVRE_STOR[(dfVRE_STOR[!,:Zone].==z),:][!,:R_ID]) for z=findall(x->x>0,inputs["dfESR"][:,ESR])))
		EP[:eESR] += eESRVREStor		
	end

    # Capacity Reserve Margin
	if CapacityReserveMargin > 0
		CRPL = setup["CapResPeriodLength"]
		@variable(EP, vCAPCONTRSTOR_DISCHARGE_VRE_STOR[y in VRE_STOR, t=1:T])   # VRE-STOR capacity contribution from net discharge
		@variable(EP, vCAPCONTRSTOR_SOC_VRE_STOR[y in VRE_STOR, t=1:T] >= 0)    # VRE-STOR capacity contribution from charge held in reserve
		@variable(EP, vMINSOCSTOR_VRE_STOR[y in VRE_STOR, t=1:T] >= 0)          # Minimum SOC maintained over following n hours

        # Discharge capacity contribution must be less than grid discharge - charge
		@constraint(EP, cCapContrStorEnergy_VRE_STOR[y in VRE_STOR, t=1:T], vCAPCONTRSTOR_DISCHARGE_VRE_STOR[y,t] <= EP[:vP][y,t] - EP[:vCHARGE_VRE_STOR][y,t])
		# Minimum SOC must be less than state of charge
        @constraint(EP, cMinSocTrackStor_VRE_STOR[y in VRE_STOR, t=1:T, n=1:CRPL], vMINSOCSTOR_VRE_STOR[y,t] <= EP[:vS_VRE_STOR][y, hoursafter(p,t,n)])
		# Storage reserve capacity contribution must be less than efficiency down * minimum SOC
        @constraint(EP, cCapContrStorSOC_VRE_STOR[y in VRE_STOR, t=1:T], vCAPCONTRSTOR_SOC_VRE_STOR[y,t] <= by_rid(y,:Eff_Down_DC)*vMINSOCSTOR_VRE_STOR[y,t]/CRPL)
		# Storage reserve capacity contribution must be less than available grid conneecion
        @constraint(EP, cCapContrStorSOCLim_VRE_STOR[y in VRE_STOR, t=1:T], vCAPCONTRSTOR_SOC_VRE_STOR[y,t] <= EP[:eTotalCap][y])
		@constraint(EP, cCapContrStorSOCPartLim_VRE_STOR[y in VRE_STOR, t=1:T], vCAPCONTRSTOR_SOC_VRE_STOR[y,t] <= EP[:eTotalCap][y] - vCAPCONTRSTOR_DISCHARGE_VRE_STOR[y,t])

        # Add two potential contributions together
		@expression(EP, eCapResMarBalanceStor_VRE_STOR[res=1:inputs["NCapacityReserveMargin"], t=1:T], sum(dfVRE_STOR[y,Symbol("CapRes_$res")] * (vCAPCONTRSTOR_DISCHARGE_VRE_STOR[y,t] + vCAPCONTRSTOR_SOC_VRE_STOR[y,t])  for y in VRE_STOR))
		EP[:eCapResMarBalance] += eCapResMarBalanceStor_VRE_STOR
	end


    ## 4. Module Expressions ##

    # Inverter AC Balance
    @expression(EP, eInvACBalance[y in VRE_STOR, t in 1:T], by_rid(y, :EtaInverter)*(vP_DC_DISCHARGE[y, t] + vP_SOLAR[y, t]) - vP_DC_CHARGE[y,t]/by_rid(y, :EtaInverter))

	### CONSTRAINTS ###

    # Constraint 1: Energy Balance Constraint
    @constraint(EP, cEnergyBalance[y in VRE_STOR, t=1:T],
    EP[:vP][y, t] - vCHARGE_VRE_STOR[y, t] == vP_WIND[y, t] + vP_AC_DISCHARGE[y, t] - vP_AC_CHARGE[y, t] + eInvACBalance[y, t])
    
    # Constraint 2: Grid Export/Import Maximum
    @constraint(EP, cGridExport[y in VRE_STOR, t=1:T],
    EP[:vP][y,t] + vCHARGE_VRE_STOR[y,t] <= EP[:eTotalCap][y])
    
    # Activate inverter module
    if !isempty(DC)
        inverter_vre_stor!(EP, inputs)
    end

    # Activate solar module
    if !isempty(SOLAR)
        solar_vre_stor!(EP, inputs, setup)
    end

    # Activate wind module
    if !isempty(WIND)
        wind_vre_stor!(EP, inputs)
    end

    # Activate storage module
    if !isempty(STOR)
        stor_vre_stor!(EP, inputs, setup)
    end
end

@doc raw"""
    inverter_vre_stor!(EP::Model, inputs::Dict)

    This function activates the decision variables and constraints for the inverter component.
"""
function inverter_vre_stor!(EP::Model, inputs::Dict)
    println("VRE-STOR Inverter Module")

    # Load inputs
    T = inputs["T"]     # Number of time steps (hours)
    DC = inputs["VS_DC"]
    NEW_CAP_DC = inputs["NEW_CAP_DC"]
    RET_CAP_DC = inputs["RET_CAP_DC"]

    by_rid(rid, sym) = by_rid_df(rid, sym, dfVRE_STOR)

    ### INVERTER VARIABLES ###
    @variables(EP, begin
        # Inverter capacity 
        vRETDCCAP[y in RET_CAP_DC] >= 0                         # Retired inverter capacity [MW AC]
        vDCCAP[y in NEW_CAP_DC] >= 0                            # New installed inverter capacity [MW AC]
    end)

    ### EXPRESSIONS ###

    # 1. Total inverter capacity
    @expression(EP, eTotalCap_DC[y in DC],
		if (y in intersect(NEW_CAP_DC, RET_CAP_DC)) # Resources eligible for new capacity and retirements
			by_rid(y, :Existing_Cap_Inverter_MW) + EP[:vDCCAP][y] - EP[:vRETDCCAP][y]
		elseif (y in setdiff(NEW_CAP_DC, RET_CAP_DC)) # Resources eligible for only new capacity
			by_rid(y, :Existing_Cap_Inverter_MW) + EP[:vDCCAP][y]
		elseif (y in setdiff(RET_CAP_DC, NEW_CAP_DC)) # Resources eligible for only capacity retirements
			by_rid(y, :Existing_Cap_Inverter_MW) - EP[:vRETDCCAP][y]
		else
			by_rid(y, :Existing_Cap_Inverter_MW)
		end
	)

    # 2. Objective function additions

    # Fixed costs for inverter component (if resource is not eligible for new inverter capacity, fixed costs are only O&M costs)
    @expression(EP, eCFixDC[y in DC],
        if y in NEW_CAP_DC # Resources eligible for new capacity
            by_rid(y, :Inv_Cost_Inverter_per_MWyr)*vDCCAP[y] + by_rid(y, :Fixed_OM_Inverter_Cost_per_MWyr)*eTotalCap_DC[y]
        else
            by_rid(y, :Fixed_OM_Inverter_Cost_per_MWyr)*eTotalCap_DC[y]
        end
    )
    # Sum individual resource contributions
    @expression(EP, eTotalCFixDC, sum(eCFixDC[y] for y in DC))
    EP[:eObj] += eTotalCFixDC
    
    ### CONSTRAINTS ###

    # Constraints 1: Retirements and capacity additions
    # Cannot retire more capacity than existing capacity for VRE-STOR technologies
    @constraint(EP, cMaxRet_DC[y=RET_CAP_DC], vRETDCCAP[y] <= by_rid(y, :Existing_Cap_Inverter_MW))
    # Constraint on maximum capacity (if applicable) [set input to -1 if no constraint on maximum capacity]
	# DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is >= Max_Cap_MW and lead to infeasabilty
    @constraint(EP, cMaxCap_DC[y in dfVRE_STOR[dfVRE_STOR.Max_Cap_Inverter_MW.>=0,:R_ID]], 
    eTotalCap_DC[y] <= by_rid(y, :Max_Cap_Inverter_MW))
    # Constraint on Minimum capacity (if applicable) [set input to -1 if no constraint on minimum capacity]
    # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is <= Min_Cap_MW and lead to infeasabilty
    @constraint(EP, cMinCap_DC[y in dfVRE_STOR[dfVRE_STOR.Min_Cap_Inverter_MW.>0,:R_ID]], 
    eTotalCap_DC[y] >= by_rid(y, :Min_Cap_Inverter_MW))

    # Constraint 2: Inverter Exports Maximum
    @constraint(EP, cInverterExport[y in DC, t in 1:T], by_rid(y, :EtaInverter)*(EP[:vP_SOLAR][y, t]+EP[:vP_DC_DISCHARGE][y,t]) + EP[:vP_DC_CHARGE][y,t]/by_rid(y, :EtaInverter) <= eTotalCap_DC[y])
end

@doc raw"""
    solar_vre_stor!(EP::Model, inputs::Dict)

    This function activates the decision variables and constraints for the solar PV component.
"""
function solar_vre_stor!(EP::Model, inputs::Dict, setup::Dict)
    println("VRE-STOR Solar Module")

    T = inputs["T"]     # Number of time steps (hours)
    SOLAR = inputs["VS_SOLAR"]
    VRE_STOR = inputs["VRE_STOR"]
    NOT_SOLAR = setdiff(VRE_STOR, SOLAR)
    NEW_CAP_SOLAR = inputs["NEW_CAP_SOLAR"]
    RET_CAP_SOLAR = inputs["RET_CAP_SOLAR"]

    by_rid(rid, sym) = by_rid_df(rid, sym, dfVRE_STOR)

    ### SOLAR VARIABLES ###
    @variables(EP, begin
        vRETSOLARCAP[y in RET_CAP_SOLAR] >= 0                         # Retired solar capacity [MW DC]
        vSOLARCAP[y in NEW_CAP_SOLAR] >= 0                            # New installed solar capacity [MW DC]
    end)

    ### EXPRESSIONS ###

    # 1. Total solar capacity
    @expression(EP, eTotalCap_SOLAR[y in SOLAR],
		if (y in intersect(NEW_CAP_SOLAR, RET_CAP_SOLAR)) # Resources eligible for new capacity and retirements
			by_rid(y, :Existing_Cap_Solar_MW) + EP[:vSOLARCAP][y] - EP[:vRETSOLARCAP][y]
		elseif (y in setdiff(NEW_CAP_SOLAR, RET_CAP_SOLAR)) # Resources eligible for only new capacity
			by_rid(y, :Existing_Cap_Solar_MW) + EP[:vSOLARCAP][y]
		elseif (y in setdiff(RET_CAP_SOLAR, NEW_CAP_SOLAR)) # Resources eligible for only capacity retirements
			by_rid(y, :Existing_Cap_Solar_MW) - EP[:vRETSOLARCAP][y]
		else
			by_rid(y, :Existing_Cap_Solar_MW)
		end
	)

    # 2. Objective function additions

    # Fixed costs for solar resources (if resource is not eligible for new solar capacity, fixed costs are only O&M costs)
    @expression(EP, eCFixSolar[y in SOLAR],
        if y in NEW_CAP_SOLAR # Resources eligible for new capacity
            by_rid(y, :Inv_Cost_Solar_per_MWyr)*vSOLARCAP[y] + by_rid(y, :Fixed_OM_Solar_Cost_per_MWyr)*eTotalCap_SOLAR[y]
        else
            by_rid(y, :Fixed_OM_Solar_Cost_per_MWyr)*eTotalCap_SOLAR[y]
        end
    )
    # Variable costs of "generation" for solar resource "y" during hour "t"
    @expression(EP, eCVarOutSolar[y in SOLAR, t=1:T], inputs["omega"][t]*(by_rid(y, :Var_OM_Cost_per_MWh_Solar)*EP[:vP_SOLAR][y,t]*by_rid(y, :EtaInverter)))
    
    # Sum individual resource contributions
    @expression(EP, eTotalCFixSolar, sum(eCFixSolar[y] for y in SOLAR))
    @expression(EP, eTotalCVarOutSolar, sum(eCVarOutSolar[y, t] for y in SOLAR, t in 1:T))
    EP[:eObj] += (eTotalCFixSolar + eTotalCVarOutSolar)

    # 3. Minimum Capacity Requirement Policy
    if (setup["MinCapReq"] == 1)
        @expression(EP, eMinCapResSolar[mincap = 1:inputs["NumberOfMinCapReqs"]], sum(EP[:eTotalCap_SOLAR][y]*by_rid(y, :EtaInverter) for y in dfVRE_STOR[(dfVRE_STOR[!,Symbol("MinCapTag_$mincap")].== 1) ,:][!,:R_ID]))
		EP[:eMinCapRes] += eMinCapResSolar
	end

    ### CONSTRAINTS ###

    # Constraint 0: Non-solar generating resources get capped for generation
    @constraint(EP, cSolarGenMaxN[y in NOT_SOLAR, t in 1:T], EP[:vP_SOLAR][y, t] == 0)

    # Constraints 1: Retirements and capacity additions
    # Cannot retire more capacity than existing capacity for VRE-STOR technologies
    @constraint(EP, cMaxRet_Solar[y=RET_CAP_SOLAR], vRETSOLARCAP[y] <= by_rid(y, :Existing_Cap_Solar_MW))
    # Constraint on maximum capacity (if applicable) [set input to -1 if no constraint on maximum capacity]
	# DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is >= Max_Cap_MW and lead to infeasabilty
    @constraint(EP, cMaxCap_Solar[y in dfVRE_STOR[dfVRE_STOR.Max_Cap_Solar_MW.>=0,:R_ID]], 
    eTotalCap_SOLAR[y] <= by_rid(y, :Max_Cap_Solar_MW))
    # Constraint on Minimum capacity (if applicable) [set input to -1 if no constraint on minimum capacity]
    # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is <= Min_Cap_MW and lead to infeasabilty
    @constraint(EP, cMinCap_Solar[y in dfVRE_STOR[dfVRE_STOR.Min_Cap_Solar_MW.>0,:R_ID]], 
    eTotalCap_SOLAR[y] >= by_rid(y, :Min_Cap_Solar_MW))

    # Constraint 2: PV Generation
    @constraint(EP, cSolarGenMaxS[y in SOLAR, t in 1:T], EP[:vP_SOLAR][y, t] <= inputs["pP_Max_Solar"][y,t]*eTotalCap_SOLAR[y])

    # Constraint 3: Inverter Ratio between solar capacity and grid
    @constraint(EP, cInverterRatio_Solar[y in dfVRE_STOR[dfVRE_STOR.Inverter_Ratio_Solar.>0,:R_ID]], 
    EP[:eTotalCap_SOLAR][y] == by_rid(y, :Inverter_Ratio_Solar) * EP[:eTotalCap_DC][y])

end

@doc raw"""
    wind_vre_stor!(EP::Model, inputs::Dict)

    This function activates the decision variables and constraints for the wind component.
"""
function wind_vre_stor!(EP::Model, inputs::Dict)
    println("VRE-STOR Wind Module")

    T = inputs["T"]     # Number of time steps (hours)
    WIND = inputs["VS_WIND"]
    VRE_STOR = inputs["VRE_STOR"]
    NOT_WIND = setdiff(VRE_STOR, WIND)
    NEW_CAP_WIND = inputs["NEW_CAP_WIND"]
    RET_CAP_WIND = inputs["RET_CAP_WIND"]

    by_rid(rid, sym) = by_rid_df(rid, sym, dfVRE_STOR)

    ### WIND VARIABLES ###
    @variables(EP, begin
        # Wind capacity 
        vRETWINDCAP[y in RET_CAP_WIND] >= 0                         # Retired wind capacity [MW AC]
        vWINDCAP[y in NEW_CAP_WIND] >= 0                            # New installed wind capacity [MW AC]
    end)

    ### EXPRESSIONS ###

    # 1. Total wind capacity
    @expression(EP, eTotalCap_WIND[y in WIND],
		if (y in intersect(NEW_CAP_WIND, RET_CAP_WIND)) # Resources eligible for new capacity and retirements
			by_rid(y, :Existing_Cap_Wind_MW) + EP[:vWINDCAP][y] - EP[:vRETWINDCAP][y]
		elseif (y in setdiff(NEW_CAP_WIND, RET_CAP_WIND)) # Resources eligible for only new capacity
			by_rid(y, :Existing_Cap_Wind_MW) + EP[:vWINDCAP][y]
		elseif (y in setdiff(RET_CAP_WIND, NEW_CAP_WIND)) # Resources eligible for only capacity retirements
			by_rid(y, :Existing_Cap_Wind_MW) - EP[:vRETWINDCAP][y]
		else
			by_rid(y, :Existing_Cap_Wind_MW)
		end
	)

    # 2. Objective function additions

    # Fixed costs for wind resources (if resource is not eligible for new wind capacity, fixed costs are only O&M costs)
    @expression(EP, eCFixWind[y in WIND],
        if y in NEW_CAP_WIND # Resources eligible for new capacity
            by_rid(y, :Inv_Cost_Wind_per_MWyr)*vWINDCAP[y] + by_rid(y, :Fixed_OM_Wind_Cost_per_MWyr)*eTotalCap_WIND[y]
        else
            by_rid(y, :Fixed_OM_Wind_Cost_per_MWyr)*eTotalCap_WIND[y]
        end
    )
    # Variable costs of "generation" for wind resource "y" during hour "t"
    @expression(EP, eCVarOutWind[y in WIND, t=1:T], inputs["omega"][t]*(by_rid(y, :Var_OM_Cost_per_MWh_Wind)*EP[:vP_WIND][y,t]))
    
    # Sum individual resource contributions
    @expression(EP, eTotalCFixWind, sum(eCFixWind[y] for y in WIND))
    @expression(EP, eTotalCVarOutWind, sum(eCVarOutWind[y, t] for y in WIND, t in 1:T))
    EP[:eObj] += (eTotalCFixWind + eTotalCVarOutWind)

    # 3. Minimum Capacity Requirement Policy
    if (setup["MinCapReq"] == 1)
        @expression(EP, eMinCapResWind[mincap = 1:inputs["NumberOfMinCapReqs"]], sum(EP[:eTotalCap_WIND][y] for y in dfVRE_STOR[(dfVRE_STOR[!,Symbol("MinCapTag_$mincap")].== 1) ,:][!,:R_ID]))
		EP[:eMinCapRes] += eMinCapResWind
	end

    ### CONSTRAINTS ###

    # Constraint 0: Non-wind generating resources get capped for generation
    @constraint(EP, cWindGenMaxN[y in NOT_WIND, t in 1:T], EP[:vP_WIND][y, t] == 0)

    # Constraints 1: Retirements and capacity additions
    # Cannot retire more capacity than existing capacity for VRE-STOR technologies
    @constraint(EP, cMaxRet_Wind[y=RET_CAP_WIND], vRETWINDCAP[y] <= by_rid(y, :Existing_Cap_Wind_MW))
    # Constraint on maximum capacity (if applicable) [set input to -1 if no constraint on maximum capacity]
	# DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is >= Max_Cap_MW and lead to infeasabilty
    @constraint(EP, cMaxCap_Wind[y in dfVRE_STOR[dfVRE_STOR.Max_Cap_Wind_MW.>=0,:R_ID]], 
    eTotalCap_WIND[y] <= by_rid(y, :Max_Cap_Wind_MW))
    # Constraint on Minimum capacity (if applicable) [set input to -1 if no constraint on minimum capacity]
    # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is <= Min_Cap_MW and lead to infeasabilty
    @constraint(EP, cMinCap_Wind[y in dfVRE_STOR[dfVRE_STOR.Min_Cap_Wind_MW.>0,:R_ID]], 
    eTotalCap_WIND[y] >= by_rid(y, :Min_Cap_Wind_MW))

    # Constraint 2: Wind Generation
    @constraint(EP, cWindGenMaxW[y in WIND, t in 1:T], EP[:vP_WIND][y, t] <= inputs["pP_Max_Wind"][y,t]*eTotalCap_WIND[y])

    # Constraint 3: Inverter Ratio between wind capacity and grid
    @constraint(EP, cInverterRatio_Wind[y in dfVRE_STOR[dfVRE_STOR.Inverter_Ratio_Wind.>0,:R_ID]], 
    EP[:eTotalCap_WIND][y] == by_rid(y, :Inverter_Ratio_Wind) * EP[:eTotalCap][y])
end

@doc raw"""
    stor_vre_stor!(EP::Model, inputs::Dict)

    This function activates the decision variables and constraints for the required battery-pack component.
"""
function stor_vre_stor!(EP::Model, inputs::Dict, setup::Dict)
    println("VRE-STOR Battery Module")

    # Load inputs
    T = inputs["T"]     # Number of time steps (hours)
    STOR = inputs["VS_STOR"]
    dfGen = inputs["dfGen"]
    dfVRE_STOR = inputs["dfVRE_STOR"]
    VRE_STOR = inputs["VRE_STOR"]
    NEW_CAP_STOR = inputs["NEW_CAP_STOR"]
    RET_CAP_STOR = inputs["RET_CAP_STOR"]
    DC_DISCHARGE = inputs["VS_STOR_DC_DISCHARGE"]
    DC_CHARGE = inputs["VS_STOR_DC_CHARGE"]
    AC_DISCHARGE = inputs["VS_STOR_AC_DISCHARGE"]
    AC_CHARGE = inputs["VS_STOR_AC_CHARGE"]

    START_SUBPERIODS = inputs["START_SUBPERIODS"]
	INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]
	hours_per_subperiod = inputs["hours_per_subperiod"] # total number of hours per subperiod

    # Split storage resources
    VS_LDS, VS_nonLDS, VS_SYM_DC_DISCHARGE, VS_SYM_DC_CHARGE, VS_ASYM_DC_DISCHARGE, VS_ASYM_DC_CHARGE, VS_SYM_AC_DISCHARGE, VS_SYM_AC_CHARGE, VS_ASYM_AC_DISCHARGE, VS_ASYM_AC_CHARGE = split_storage_resources(dfVRE_STOR, inputs, setup)
    inputs["VS_LDS"] = VS_LDS
    inputs["VS_nonLDS"] = VS_nonLDS
    inputs["VS_ASYM"] = union(VS_ASYM_DC_CHARGE, VS_ASYM_DC_DISCHARGE, VS_ASYM_AC_DISCHARGE, VS_ASYM_AC_CHARGE)
    inputs["VS_ASYM_DC_CHARGE"] = VS_ASYM_DC_CHARGE
    inputs["VS_ASYM_DC_DISCHARGE"] = VS_ASYM_DC_DISCHARGE
    inputs["VS_ASYM_AC_DISCHARGE"] = VS_ASYM_AC_DISCHARGE
    inputs["VS_ASYM_AC_CHARGE"] = VS_ASYM_AC_CHARGE
    inputs["VS_SYM_DC"] = intersect(VS_SYM_DC_CHARGE, VS_SYM_DC_DISCHARGE)
    inputs["VS_SYM_AC"] = intersect(VS_SYM_AC_CHARGE, VS_SYM_AC_DISCHARGE)

    by_rid(rid, sym) = by_rid_df(rid, sym, dfVRE_STOR)

    ### STOR VARIABLES ###
    @variables(EP, begin
        # Storage energy capacity
        vCAPENERGY_VS[y in NEW_CAP_STOR] >= 0      # Energy storage reservoir capacity (MWh capacity) built for VRE storage [MWh]
        vRETCAPENERGY_VS[y in RET_CAP_STOR] >= 0   # Energy storage reservoir capacity retired for VRE storage [MWh]
    
        # State of charge variable
        vS_VRE_STOR[y in STOR,t=1:T] >= 0                  # Storage level of resource "y" at hour "t" [MWh] on zone "z"
    end)

    ### EXPRESSIONS ###

    # 1. Total storage energy capacity
    @expression(EP, eTotalCap_STOR[y in STOR],
		if (y in intersect(NEW_CAP_STOR, RET_CAP_STOR)) # Resources eligible for new capacity and retirements
			dfGen[y,:Existing_Cap_MWh] + EP[:vCAPENERGY_VS][y] - EP[:vRETCAPENERGY_VS][y]
		elseif (y in setdiff(NEW_CAP_STOR, RET_CAP_STOR)) # Resources eligible for only new capacity
			dfGen[y,:Existing_Cap_MWh] + EP[:vCAPENERGY_VS][y]
		elseif (y in setdiff(RET_CAP_STOR, NEW_CAP_STOR)) # Resources eligible for only capacity retirements
			dfGen[y,:Existing_Cap_MWh] - EP[:vRETCAPENERGY_VS][y]
		else
			dfGen[y,:Existing_Cap_MWh]
		end
	)

    # 2. Objective function additions

    # Fixed costs for storage resources (if resource is not eligible for new energy capacity, fixed costs are only O&M costs)
	@expression(EP, eCFixEnergy_VS[y in STOR],
        if y in NEW_CAP_STOR # Resources eligible for new capacity
            dfGen[y,:Inv_Cost_per_MWhyr]*vCAPENERGY_VS[y] + dfGen[y,:Fixed_OM_Cost_per_MWhyr]*eTotalCap_STOR[y]
        else
            dfGen[y,:Fixed_OM_Cost_per_MWhyr]*eTotalCap_STOR[y]
        end
    )

    # Variable costs of charging DC for VRE-STOR resources "y" during hour "t"
    @expression(EP, eCVar_Charge_DC[y in DC_CHARGE, t=1:T], inputs["omega"][t]*(by_rid(y, :Var_OM_Cost_per_MWh_Charge_DC)*by_rid(y, :EtaInverter)*EP[:vP_DC_CHARGE][y,t]))
    # Variable costs of discharging DC for VRE-STOR resources "y" during hour "t"
    @expression(EP, eCVar_Discharge_DC[y in DC_DISCHARGE, t=1:T], inputs["omega"][t]*(by_rid(y, :Var_OM_Cost_per_MWh_Discharge_DC)*by_rid(y, :EtaInverter)*EP[:vP_DC_DISCHARGE][y,t]))
    # Variable costs of charging AC for VRE-STOR resources "y" during hour "t"
    @expression(EP, eCVar_Charge_AC[y in AC_CHARGE, t=1:T], inputs["omega"][t]*(by_rid(y, :Var_OM_Cost_per_MWh_Charge_AC)*EP[:vP_AC_CHARGE][y,t]))
    # Variable costs of discharging AC for VRE-STOR resources "y" during hour "t"
    @expression(EP, eCVar_Discharge_AC[y in AC_DISCHARGE, t=1:T], inputs["omega"][t]*(by_rid(y, :Var_OM_Cost_per_MWh_Discharge_AC)*EP[:vP_AC_DISCHARGE][y,t]))


    # Sum individual resource contributions
    @expression(EP, eTotalCFixStor, sum(eCFixEnergy_VS[y] for y in STOR))
    @expression(EP, eTotalCVarStor, sum(eCVar_Charge_DC[y, t] for y in DC_CHARGE, t in 1:T) +
                                    sum(eCVar_Discharge_DC[y, t] for y in DC_DISCHARGE, t in 1:T) +
                                    sum(eCVar_Charge_AC[y, t] for y in AC_CHARGE, t in 1:T) +
                                    sum(eCVar_Discharge_AC[y, t] for y in AC_CHARGE, t in 1:T))
    EP[:eObj] += (eTotalCFixStor + eTotalCVarStor)

    ### CONSTRAINTS ###

    # Constraint 0: Set generators with no storage component with no discharge/charging abiliites
    @constraint(EP, cDCDischargeN[y in setdiff(VRE_STOR, DC_DISCHARGE), t=1:T], EP[:vP_DC_DISCHARGE][y, t] == 0)
    @constraint(EP, cACDischargeN[y in setdiff(VRE_STOR, AC_DISCHARGE), t=1:T], EP[:vP_AC_DISCHARGE][y, t] == 0)
    @constraint(EP, cDCChargeN[y in setdiff(VRE_STOR, DC_CHARGE), t=1:T], EP[:vP_DC_CHARGE][y, t] == 0)
    @constraint(EP, cACChargeN[y in setdiff(VRE_STOR, AC_CHARGE), t=1:T], EP[:vP_AC_CHARGE][y, t] == 0)

    # Constraints 1: Retirements and capacity additions
    # Cannot retire more capacity than existing capacity for VRE-STOR technologies
    @constraint(EP, cMaxRet_Stor[y=RET_CAP_STOR], vRETCAPENERGY_VS[y] <= dfGen[y, :Existing_Cap_MWh])
    # Constraint on maximum capacity (if applicable) [set input to -1 if no constraint on maximum capacity]
	# DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is >= Max_Cap_MW and lead to infeasabilty
    @constraint(EP, cMaxCap_Stor[y in dfGen[dfGen.Max_Cap_MWh.>=0,:R_ID]], 
    eTotalCap_STOR[y] <= dfGen[y, :Max_Cap_MWh])
    # Constraint on Minimum capacity (if applicable) [set input to -1 if no constraint on minimum capacity]
    # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is <= Min_Cap_MW and lead to infeasabilty
    @constraint(EP, cMinCap_Stor[y in dfGen[dfGen.Min_Cap_MWh.>0,:R_ID]], 
    eTotalCap_STOR[y] >= dfGen[y, :Min_Cap_MWh])

    # Constraint 2: SOC Maximum
    @constraint(EP, cSOCMax[y in STOR, t in 1:T], vS_VRE_STOR[y, t] <= eTotalCap_STOR[y])

    # Constraint 3: State of Charge (energy stored for the next hour)
    if setup["OperationWrapping"] == 1 && !isempty(VS_LDS) # Check for LDS=1 & OperationWrapping=1
		CONSTRAINTSET = VS_nonLDS
	else
		CONSTRAINTSET = STOR
	end

    @constraint(EP, cSoCBalInterior_VRE_STOR[t in INTERIOR_SUBPERIODS, y in STOR], 
    vS_VRE_STOR[y,t] == vS_VRE_STOR[y,t-1] -
                        (1/by_rid(y, :Eff_Down_DC)*EP[:vP_DC_DISCHARGE][y,t]) +
                        (by_rid(y, :Eff_Up_DC)*EP[:vP_DC_CHARGE][y,t]) -
                        (1/by_rid(y, :Eff_Down_AC)*EP[:vP_AC_DISCHARGE][y,t]) +
                        (by_rid(y, :Eff_Up_AC)*EP[:vP_AC_CHARGE][y,t]) -
                        (dfGen[y,:Self_Disch]*EP[:vS_VRE_STOR][y,t-1]))
    @constraint(EP, cSoCBalStart_VRE_STOR[t in START_SUBPERIODS, y in CONSTRAINTSET],
    vS_VRE_STOR[y,t] == vS_VRE_STOR[y,t+hours_per_subperiod-1] - 
                        (1/by_rid(y, :Eff_Down_DC)*EP[:vP_DC_DISCHARGE][y,t]) +
                        (by_rid(y, :Eff_Up_DC)*EP[:vP_DC_CHARGE][y,t]) -
                        (1/by_rid(y, :Eff_Down_AC)*EP[:vP_AC_DISCHARGE][y,t]) +
                        (by_rid(y, :Eff_Up_AC)*EP[:vP_AC_CHARGE][y,t]) -
                        (dfGen[y,:Self_Disch]*vS_VRE_STOR[y,t+hours_per_subperiod-1]))

    ### SYMMETRIC RESOURCE CONSTRAINTS ###
    if !isempty(inputs["VS_SYM_DC"])
        # Constraint 4: Charging + Discharging DC Maximum 
        @constraint(EP, cChargeDischargeMaxDC[y in inputs["VS_SYM_DC"], t=1:T],
                        EP[:vP_DC_DISCHARGE][y,t]/by_rid(y, :Eff_Down_DC) + 
                        by_rid(y, :Eff_Up_DC)*EP[:vP_DC_CHARGE][y,t] <= 
                        by_rid(y, :C_Rate_DC) * eTotalCap_STOR[y])
    end
    if !isempty(inputs["VS_SYM_AC"])
        # Constraint 4: Charging + Discharging AC Maximum 
        @constraint(EP, cChargeDischargeMaxAC[y in inputs["VS_SYM_AC"], t=1:T],
                        EP[:vP_AC_DISCHARGE][y,t]/by_rid(y, :Eff_Down_AC) + 
                        by_rid(y, :Eff_Up_AC)*EP[:vP_AC_CHARGE][y,t] <= 
                        by_rid(y, :C_Rate_AC) * eTotalCap_STOR[y])
    end

    ### ASYMMETRIC RESOURCE MODULE ###
    if !isempty(VS_ASYM)
        investment_charge_vre_stor!(EP, inputs)
    end

    ### LONG-DURATION ENERGY STORAGE RESOURCE MODULE ###
    if !isempty(VS_LDS)
        lds_vre_stor!(EP, inputs)
    end
    
end

@doc raw"""
    split_storage_resources(df::DataFrame, inputs::Dict, setup::Dict)

    This function returns the storage type (1. long-duration or short-duration storage, 2. symmetric or asymmetric storage)
    for charging and discharging capacities.
"""
function split_storage_resources(df::DataFrame, inputs::Dict, setup::Dict)
	VRE_STOR = inputs["VRE_STOR"]
    LDS = inputs["VS_LDS"]
    STOR = inputs["VS_STOR"]

    # Split LDS & Non-LDS resources
	if setup["OperationWrapping"] == 1
		VS_LDS = intersect(LDS, STOR)
		VS_nonLDS = setdiff(STOR, LDS)
	else
		VS_LDS = Int[]
		VS_nonLDS = VRE_STOR
	end

    # DC resource type split
    VS_SYM_DC_DISCHARGE = df[df.STOR_DC_DISCHARGE.==1,:R_ID]
    VS_SYM_DC_CHARGE = df[df.STOR_DC_CHARGE.==1,:R_ID]
    VS_ASYM_DC_DISCHARGE = df[df.STOR_DC_DISCHARGE.==2,:R_ID]
    VS_ASYM_DC_CHARGE = df[df.STOR_DC_CHARGE.==2,:R_ID]

    # AC resource type split
    VS_SYM_AC_DISCHARGE = df[df.STOR_AC_DISCHARGE.==1,:R_ID]
    VS_SYM_AC_CHARGE = df[df.STOR_AC_CHARGE.==1,:R_ID]
    VS_ASYM_AC_DISCHARGE = df[df.STOR_AC_DISCHARGE.==2,:R_ID]
    VS_ASYM_AC_CHARGE = df[df.STOR_AC_CHARGE.==2,:R_ID]

    # Send warnings for symmetric/asymmetric resources
    if !isempty(setdiff(VS_SYM_DC_DISCHARGE,VS_SYM_DC_CHARGE)) || !isempty(setdiff(VS_SYM_DC_CHARGE,VS_SYM_DC_DISCHARGE)) || !isempty(setdiff(VS_SYM_AC_DISCHARGE,VS_SYM_AC_CHARGE)) || !isempty(setdiff(VS_SYM_AC_CHARGE,VS_SYM_AC_DISCHARGE))
        @warn("Symmetric capacities must both be DC or AC.")
    end

	return VS_LDS, VS_nonLDS, VS_SYM_DC_DISCHARGE, VS_SYM_DC_CHARGE, VS_ASYM_DC_DISCHARGE, VS_ASYM_DC_CHARGE, VS_SYM_AC_DISCHARGE, VS_SYM_AC_CHARGE, VS_ASYM_AC_DISCHARGE, VS_ASYM_AC_CHARGE
end

@doc raw"""
    lds_vre_stor!(EP::Model, inputs::Dict)

    This function activates the decision variables and constraints for LDS resources.
"""
function lds_vre_stor!(EP::Model, inputs::Dict)
    println("VRE-STOR LDS Module")

    VS_LDS = inputs["VS_LDS"]
    dfGen = inputs["dfGen"]

    REP_PERIOD = inputs["REP_PERIOD"]  # Number of representative periods
	dfPeriodMap = inputs["Period_Map"] # Dataframe that maps modeled periods to representative periods
	NPeriods = nrow(dfPeriodMap) # Number of modeled periods
    hours_per_subperiod = inputs["hours_per_subperiod"] #total number of hours per subperiod

	MODELED_PERIODS_INDEX = 1:NPeriods
	REP_PERIODS_INDEX = MODELED_PERIODS_INDEX[dfPeriodMap.Rep_Period .== MODELED_PERIODS_INDEX]

    by_rid(rid, sym) = by_rid_df(rid, sym, dfVRE_STOR)

    # State of charge of storage at beginning of each modeled period n
	@variable(EP, vSOCw_VRE_STOR[y in VS_LDS, n in MODELED_PERIODS_INDEX] >= 0)

    # Build up in storage inventory over each representative period w
    # Build up inventory can be positive or negative
    @variable(EP, vdSOC_VRE_STOR[y in VS_LDS, w=1:REP_PERIOD])

    # Note: tw_min = hours_per_subperiod*(w-1)+1; tw_max = hours_per_subperiod*w
    @constraint(EP, cVreStorSoCBalLongDurationStorageStart[w=1:REP_PERIOD, y in VS_LDS], 
                    (EP[:vS_VRE_STOR][y,hours_per_subperiod * (w - 1) + 1] ==
                    (1 - dfGen[y, :Self_Disch]) * (EP[:vS_VRE_STOR][y, hours_per_subperiod * w] - EP[:vdSOC_VRE_STOR][y,w])
                    - (1 / by_rid(y, :Eff_Down_DC) * EP[:vP_DC_DISCHARGE][y, hours_per_subperiod * (w - 1) + 1])
                    + (by_rid(y, :Eff_Up_DC) * EP[:vP_DC_CHARGE][y,hours_per_subperiod * (w - 1) + 1])
                    - (1 / by_rid(y, :Eff_Down_AC) * EP[:vP_AC_DISCHARGE][y, hours_per_subperiod * (w - 1) + 1])
                    + (by_rid(y, :Eff_Up_AC) * EP[:vP_AC_CHARGE][y,hours_per_subperiod * (w - 1) + 1]))
                )

    # Storage at beginning of period w = storage at beginning of period w-1 + storage built up in period w (after n representative periods)
    ## Multiply storage build up term from prior period with corresponding weight
    @constraint(EP, cVreStorSoCBalLongDurationStorageInterior[y in VS_LDS, r in MODELED_PERIODS_INDEX[1:(end-1)]],
                    EP[:vSOCw_VRE_STOR][y,r+1] == EP[:vSOCw_VRE_STOR][y,r] + EP[:vdSOC_VRE_STOR][y,dfPeriodMap[r,:Rep_Period_Index]])

    ## Last period is linked to first period
    @constraint(EP, cVreStorSoCBalLongDurationStorageEnd[y in VS_LDS, r in MODELED_PERIODS_INDEX[end]],
                    EP[:vSOCw_VRE_STOR][y,1] == EP[:vSOCw_VRE_STOR][y,r] + EP[:vdSOC_VRE_STOR][y,dfPeriodMap[r,:Rep_Period_Index]])

    # Storage at beginning of each modeled period cannot exceed installed energy capacity
    @constraint(EP, cVreStorSoCBalLongDurationStorageUpper[y in VS_LDS, r in MODELED_PERIODS_INDEX],
                    EP[:vSOCw_VRE_STOR][y,r] <= EP[:eTotalCap_STOR][y])

    # Initial storage level for representative periods must also adhere to sub-period storage inventory balance
    # Initial storage = Final storage - change in storage inventory across representative period
    @constraint(EP, cVreStorSoCBalLongDurationStorageSub[y in VS_LDS, r in REP_PERIODS_INDEX],
                    EP[:vSOCw_VRE_STOR][y,r] == EP[:vS_VRE_STOR][y,hours_per_subperiod*dfPeriodMap[r,:Rep_Period_Index]] - EP[:vdSOC_VRE_STOR][y,dfPeriodMap[r,:Rep_Period_Index]])
end

@doc raw"""
investment_charge_vre_stor!(EP::Model, inputs::Dict)

    This function activates the decision variables and constraints for asymmetric storage resources (independent charge
        and discharge power capacities (any STOR flag = 2)).
"""
function investment_charge_vre_stor!(EP::Model, inputs::Dict)
    println("VRE-STOR Charge Investment Module")

    VS_ASYM = inputs["VS_ASYM"]
    dfGen = inputs["dfGen"]
    dfVRE_STOR = inputs["dfVRE_STOR"]
    VS_ASYM_DC_CHARGE = inputs["VS_ASYM_DC_CHARGE"]
    VS_ASYM_AC_CHARGE = inputs["VS_ASYM_AC_CHARGE"]
    VS_ASYM_DC_DISCHARGE = inputs["VS_ASYM_DC_DISCHARGE"]
    VS_ASYM_AC_DISCHARGE = inputs["VS_ASYM_AC_DISCHARGE"]

    NEW_CAP_CHARGE_DC = intersect(dfGen[dfGen.New_Build.==1,:R_ID], dfVRE_STOR[dfVRE_STOR.Max_Charge_DC_Cap_MW.!=0,:R_ID], VS_ASYM_DC_CHARGE) # Set of asymmetric charge DC storage resources eligible for new charge capacity
	RET_CAP_CHARGE_DC = intersect(dfGen[dfGen.New_Build.!=-1,:R_ID], dfVRE_STOR[dfVRE_STOR.Existing_Charge_DC_Cap_MW.>=0,:R_ID], VS_ASYM_DC_CHARGE) # Set of asymmetric charge DC storage resources eligible for charge capacity retirements
    inputs["NEW_CAP_CHARGE_DC"] = NEW_CAP_CHARGE_DC
    inputs["RET_CAP_CHARGE_DC"] = RET_CAP_CHARGE_DC

    NEW_CAP_DISCHARGE_DC = intersect(dfGen[dfGen.New_Build.==1,:R_ID], dfVRE_STOR[dfVRE_STOR.Max_Discharge_DC_Cap_MW.!=0,:R_ID], VS_ASYM_DC_DISCHARGE) # Set of asymmetric discharge DC storage resources eligible for new discharge capacity
	RET_CAP_DISCHARGE_DC = intersect(dfGen[dfGen.New_Build.!=-1,:R_ID], dfVRE_STOR[dfVRE_STOR.Existing_Discharge_DC_Cap_MW.>=0,:R_ID], VS_ASYM_DC_DISCHARGE) # Set of asymmetric discharge DC storage resources eligible for discharge capacity retirements
    inputs["NEW_CAP_DISCHARGE_DC"] = NEW_CAP_DISCHARGE_DC
    inputs["RET_CAP_DISCHARGE_DC"] = RET_CAP_DISCHARGE_DC

    NEW_CAP_CHARGE_AC = intersect(dfGen[dfGen.New_Build.==1,:R_ID], dfVRE_STOR[dfVRE_STOR.Max_Charge_AC_Cap_MW.!=0,:R_ID], VS_ASYM_AC_CHARGE) # Set of asymmetric charge AC storage resources eligible for new charge capacity
	RET_CAP_CHARGE_AC = intersect(dfGen[dfGen.New_Build.!=-1,:R_ID], dfVRE_STOR[dfVRE_STOR.Existing_Charge_AC_Cap_MW.>=0,:R_ID], VS_ASYM_AC_CHARGE) # Set of asymmetric charge AC storage resources eligible for charge capacity retirements
    inputs["NEW_CAP_CHARGE_AC"] = NEW_CAP_CHARGE_AC
    inputs["RET_CAP_CHARGE_AC"] = RET_CAP_CHARGE_AC

    NEW_CAP_DISCHARGE_AC = intersect(dfGen[dfGen.New_Build.==1,:R_ID], dfVRE_STOR[dfVRE_STOR.Max_Discharge_AC_Cap_MW.!=0,:R_ID], VS_ASYM_AC_DISCHARGE) # Set of asymmetric discharge AC storage resources eligible for new discharge capacity
	RET_CAP_DISCHARGE_AC = intersect(dfGen[dfGen.New_Build.!=-1,:R_ID], dfVRE_STOR[dfVRE_STOR.Existing_Discharge_AC_Cap_MW.>=0,:R_ID], VS_ASYM_AC_DISCHARGE) # Set of asymmetric discharge AC storage resources eligible for discharge capacity retirements
    inputs["NEW_CAP_DISCHARGE_AC"] = NEW_CAP_DISCHARGE_AC
    inputs["RET_CAP_DISCHARGE_AC"] = RET_CAP_DISCHARGE_AC

    by_rid(rid, sym) = by_rid_df(rid, sym, dfVRE_STOR)

    if !isempty(VS_ASYM_DC_DISCHARGE)
        MAX_DC_DISCHARGE = intersect(dfVRE_STOR[dfVRE_STOR.Max_Discharge_DC_Cap_MW.!=0,:R_ID], VS_ASYM_DC_DISCHARGE)
        MIN_DC_DISCHARGE = intersect(dfVRE_STOR[dfVRE_STOR.Min_Discharge_DC_Cap_MW.!=0,:R_ID], VS_ASYM_DC_DISCHARGE)

        ### VARIABLES ###
        @variables(EP, begin
            vCAPDISCHARGE_DC[y in NEW_CAP_DISCHARGE_DC] >= 0            # Discharge capacity DC component built for VRE storage [MW]
            vRETCAPDISCHARGE_DC[y in RET_CAP_DISCHARGE_DC] >= 0         # Discharge capacity DC component retired for VRE storage [MW]
        end)

        ### EXPRESSIONS ###

        # 1. Total storage discharge DC capacity
        @expression(EP, eTotalCapDischarge_DC[y in VS_ASYM_DC_DISCHARGE],
            if (y in intersect(NEW_CAP_DISCHARGE_DC, RET_CAP_DISCHARGE_DC))
                by_rid(y,:Existing_Discharge_DC_Cap_MW) + EP[:vCAPDISCHARGE_DC][y] - EP[:vRETCAPDISCHARGE_DC][y]
            elseif (y in setdiff(NEW_CAP_DISCHARGE_DC, RET_CAP_DISCHARGE_DC))
                by_rid(y,:Existing_Discharge_DC_Cap_MW) + EP[:vCAPDISCHARGE_DC][y]
            elseif (y in setdiff(RET_CAP_DISCHARGE_DC, NEW_CAP_DISCHARGE_DC))
                by_rid(y,:Existing_Discharge_DC_Cap_MW) - EP[:vRETCAPDISCHARGE_DC][y]
            else
                by_rid(y,:Existing_Discharge_DC_Cap_MW)
            end
	    )

        # 2. Objective Function Additions

        # If resource is not eligible for new discharge DC capacity, fixed costs are only O&M costs
        @expression(EP, eCFixDischarge_DC[y in VS_ASYM_DC_DISCHARGE],
        if y in NEW_CAP_DISCHARGE_DC # Resources eligible for new discharge DC capacity
            by_rid(y,:Inv_Cost_Discharge_DC_per_MWyr)*vCAPDISCHARGE_DC[y] + by_rid(y,:Fixed_OM_Cost_Discharge_DC_per_MWyr)*eTotalCapDischarge_DC[y]
        else
            by_rid(y,:Fixed_OM_Cost_Discharge_DC_per_MWyr)*eTotalCapDischarge_DC[y]
        end
        )
        
        # Sum individual resource contributions to fixed costs to get total fixed costs
        @expression(EP, eTotalCFixDischarge_DC, sum(EP[:eCFixDischarge_DC][y] for y in VS_ASYM_DC_DISCHARGE))
        EP[:eObj] += eTotalCFixDischarge_DC

        ### CONSTRAINTS ###

        # Constraints 1: Retirements and capacity additions
        # Cannot retire more discharge DC capacity than existing discharge capacity
        @constraint(EP, cVreStorMaxRetDischargeDC[y in RET_CAP_DISCHARGE_DC], vRETCAPDISCHARGE_DC[y] <= by_rid(y,:Existing_Discharge_DC_Cap_MW))
        # Constraint on maximum discharge DC capacity (if applicable) [set input to -1 if no constraint on maximum discharge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is >= Max_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP, cVreStorMaxCapDischargeDC[y in MAX_DC_DISCHARGE], eTotalCapDischarge_DC[y] <= by_rid(y,:Max_Discharge_DC_Cap_MW))
        # Constraint on minimum discharge DC capacity (if applicable) [set input to -1 if no constraint on minimum discharge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is <= Min_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP, cVreStorMinCapDischargeDC[y in MIN_DC_DISCHARGE], eTotalCapDischarge_DC[y] >= by_rid(y,:Min_Discharge_DC_Cap_MW))

        # Constraint 2: Maximum discharging rate must be less than discharge power rating
        @constraint(EP, cVreStorMaxDischargingDC[y in VS_ASYM_DC_DISCHARGE, t in 1:T], EP[:vP_DC_DISCHARGE][y,t] <= EP[:eTotalCapDischarge_DC][y])
    end
    
    if !isempty(VS_ASYM_DC_CHARGE)
        MAX_DC_CHARGE = intersect(dfVRE_STOR[dfVRE_STOR.Max_Charge_DC_Cap_MW.!=0,:R_ID], VS_ASYM_DC_CHARGE)
        MIN_DC_CHARGE = intersect(dfVRE_STOR[dfVRE_STOR.Min_Charge_DC_Cap_MW.!=0,:R_ID], VS_ASYM_DC_CHARGE)

        ### VARIABLES ###
        @variables(EP, begin
            vCAPCHARGE_DC[y in NEW_CAP_CHARGE_DC] >= 0               # Charge capacity DC component built for VRE storage [MW]
            vRETCAPCHARGE_DC[y in RET_CAP_CHARGE_DC] >= 0            # Charge capacity DC component retired for VRE storage [MW]
        end)

        ### EXPRESSIONS ###

        # 1. Total storage charge DC capacity
        @expression(EP, eTotalCapCharge_DC[y in VS_ASYM_DC_CHARGE],
            if (y in intersect(NEW_CAP_CHARGE_DC, RET_CAP_CHARGE_DC))
                by_rid(y,:Existing_Charge_DC_Cap_MW) + EP[:vCAPCHARGE_DC][y] - EP[:vRETCAPCHARGE_DC][y]
            elseif (y in setdiff(NEW_CAP_CHARGE_DC, RET_CAP_CHARGE_DC))
                by_rid(y,:Existing_Charge_DC_Cap_MW) + EP[:vCAPCHARGE_DC][y]
            elseif (y in setdiff(RET_CAP_CHARGE_DC, NEW_CAP_CHARGE_DC))
                by_rid(y,:Existing_Charge_DC_Cap_MW) - EP[:vRETCAPCHARGE_DC][y]
            else
                by_rid(y,:Existing_Charge_DC_Cap_MW)
            end
	    )

        # 2. Objective Function Additions

        # If resource is not eligible for new charge DC capacity, fixed costs are only O&M costs
        @expression(EP, eCFixCharge_DC[y in VS_ASYM_DC_CHARGE],
        if y in NEW_CAP_CHARGE_DC # Resources eligible for new charge DC capacity
            by_rid(y,:Inv_Cost_Charge_DC_per_MWyr)*vCAPCHARGE_DC[y] + by_rid(y,:Fixed_OM_Cost_Charge_DC_per_MWyr)*eTotalCapCharge_DC[y]
        else
            by_rid(y,:Fixed_OM_Cost_Charge_DC_per_MWyr)*eTotalCapCharge_DC[y]
        end
        )
        
        # Sum individual resource contributions to fixed costs to get total fixed costs
        @expression(EP, eTotalCFixCharge_DC, sum(EP[:eCFixCharge_DC][y] for y in VS_ASYM_DC_CHARGE))
        EP[:eObj] += eTotalCFixCharge_DC

        ### CONSTRAINTS ###

        # Constraints 1: Retirements and capacity additions
        # Cannot retire more charge DC capacity than existing charge capacity
        @constraint(EP, cVreStorMaxRetChargeDC[y in RET_CAP_CHARGE_DC], vRETCAPCHARGE_DC[y] <= by_rid(y,:Existing_Charge_DC_Cap_MW))
        # Constraint on maximum charge DC capacity (if applicable) [set input to -1 if no constraint on maximum charge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is >= Max_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP, cVreStorMaxCapChargeDC[y in MAX_DC_CHARGE], eTotalCapCharge_DC[y] <= by_rid(y,:Max_Charge_DC_Cap_MW))
        # Constraint on minimum charge DC capacity (if applicable) [set input to -1 if no constraint on minimum charge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is <= Min_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP, cVreStorMinCapChargeDC[y in MIN_DC_CHARGE], eTotalCapCharge_DC[y] >= by_rid(y,:Min_Charge_DC_Cap_MW))

        # Constraint 2: Maximum charging rate must be less than charge power rating
        @constraint(EP, cVreStorMaxChargingDC[y in VS_ASYM_DC_CHARGE, t in 1:T], EP[:vP_DC_CHARGE][y,t] <= EP[:eTotalCapCharge_DC][y])
    end

    if !isempty(VS_ASYM_AC_DISCHARGE)
        MAX_AC_DISCHARGE = intersect(dfVRE_STOR[dfVRE_STOR.Max_Discharge_AC_Cap_MW.!=0,:R_ID], VS_ASYM_AC_DISCHARGE)
        MIN_AC_DISCHARGE = intersect(dfVRE_STOR[dfVRE_STOR.Min_Discharge_AC_Cap_MW.!=0,:R_ID], VS_ASYM_AC_DISCHARGE)

        ### VARIABLES ###
        @variables(EP, begin
            vCAPDISCHARGE_AC[y in NEW_CAP_DISCHARGE_AC] >= 0            # Discharge capacity AC component built for VRE storage [MW]
            vRETCAPDISCHARGE_AC[y in RET_CAP_DISCHARGE_AC] >= 0         # Discharge capacity AC component retired for VRE storage [MW]
        end)

        ### EXPRESSIONS ###

        # 1. Total storage discharge AC capacity
        @expression(EP, eTotalCapDischarge_AC[y in VS_ASYM_AC_DISCHARGE],
            if (y in intersect(NEW_CAP_DISCHARGE_AC, RET_CAP_DISCHARGE_AC))
                by_rid(y,:Existing_Discharge_AC_Cap_MW) + EP[:vCAPDISCHARGE_AC][y] - EP[:vRETCAPDISCHARGE_AC][y]
            elseif (y in setdiff(NEW_CAP_DISCHARGE_AC, RET_CAP_DISCHARGE_AC))
                by_rid(y,:Existing_Discharge_AC_Cap_MW) + EP[:vCAPDISCHARGE_AC][y]
            elseif (y in setdiff(RET_CAP_DISCHARGE_AC, NEW_CAP_DISCHARGE_AC))
                by_rid(y,:Existing_Discharge_AC_Cap_MW) - EP[:vRETCAPDISCHARGE_AC][y]
            else
                by_rid(y,:Existing_Discharge_AC_Cap_MW)
            end
	    )

        # 2. Objective Function Additions

        # If resource is not eligible for new discharge AC capacity, fixed costs are only O&M costs
        @expression(EP, eCFixDischarge_AC[y in VS_ASYM_AC_DISCHARGE],
        if y in NEW_CAP_DISCHARGE_AC # Resources eligible for new discharge AC capacity
            by_rid(y,:Inv_Cost_Discharge_AC_per_MWyr)*vCAPDISCHARGE_AC[y] + by_rid(y,:Fixed_OM_Cost_Discharge_AC_per_MWyr)*eTotalCapDischarge_AC[y]
        else
            by_rid(y,:Fixed_OM_Cost_Discharge_AC_per_MWyr)*eTotalCapDischarge_AC[y]
        end
        )
        
        # Sum individual resource contributions to fixed costs to get total fixed costs
        @expression(EP, eTotalCFixDischarge_AC, sum(EP[:eCFixDischarge_AC][y] for y in VS_ASYM_AC_DISCHARGE))
        EP[:eObj] += eTotalCFixDischarge_AC

        ### CONSTRAINTS ###

        # Constraints 1: Retirements and capacity additions
        # Cannot retire more discharge AC capacity than existing charge capacity
        @constraint(EP, cVreStorMaxRetDischargeAC[y in RET_CAP_DISCHARGE_AC], vRETCAPDISCHARGE_AC[y] <= by_rid(y,:Existing_Discharge_AC_Cap_MW))
        # Constraint on maximum discharge AC capacity (if applicable) [set input to -1 if no constraint on maximum charge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is >= Max_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP, cVreStorMaxCapDischargeAC[y in MAX_AC_DISCHARGE], eTotalCapDischarge_AC[y] <= by_rid(y,:Max_Discharge_AC_Cap_MW))
        # Constraint on minimum discharge AC capacity (if applicable) [set input to -1 if no constraint on minimum charge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is <= Min_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP, cVreStorMinCapDischargeAC[y in MIN_AC_DISCHARGE], eTotalCapDischarge_AC[y] >= by_rid(y,:Min_Discharge_AC_Cap_MW))

        # Constraint 2: Maximum discharging rate must be less than discharge power rating
        @constraint(EP, cVreStorMaxDischargingAC[y in VS_ASYM_AC_DISCHARGE, t in 1:T], EP[:vP_AC_DISCHARGE][y,t] <= EP[:eTotalCapDischarge_AC][y])
    end

    if !isempty(VS_ASYM_AC_CHARGE)
        MAX_AC_CHARGE = intersect(dfVRE_STOR[dfVRE_STOR.Max_Charge_AC_Cap_MW.!=0,:R_ID], VS_ASYM_AC_CHARGE)
        MIN_AC_CHARGE = intersect(dfVRE_STOR[dfVRE_STOR.Min_Charge_AC_Cap_MW.!=0,:R_ID], VS_ASYM_AC_CHARGE)

        ### VARIABLES ###
        @variables(EP, begin
            vCAPCHARGE_AC[y in NEW_CAP_CHARGE_AC] >= 0               # Charge capacity AC component built for VRE storage [MW]
            vRETCAPCHARGE_AC[y in RET_CAP_CHARGE_AC] >= 0            # Charge capacity AC component retired for VRE storage [MW]
        end)

        ### EXPRESSIONS ###

        # 1. Total storage charge AC capacity
        @expression(EP, eTotalCapCharge_AC[y in VS_ASYM_AC_CHARGE],
            if (y in intersect(NEW_CAP_CHARGE_AC, RET_CAP_CHARGE_AC))
                by_rid(y,:Existing_Charge_AC_Cap_MW) + EP[:vCAPCHARGE_AC][y] - EP[:vRETCAPCHARGE_AC][y]
            elseif (y in setdiff(NEW_CAP_CHARGE_AC, RET_CAP_CHARGE_AC))
                by_rid(y,:Existing_Charge_AC_Cap_MW) + EP[:vCAPCHARGE_AC][y]
            elseif (y in setdiff(RET_CAP_CHARGE_AC, NEW_CAP_CHARGE_AC))
                by_rid(y,:Existing_Charge_AC_Cap_MW) - EP[:vRETCAPCHARGE_AC][y]
            else
                by_rid(y,:Existing_Charge_AC_Cap_MW)
            end
	    )

        # 2. Objective Function Additions

        # If resource is not eligible for new charge AC capacity, fixed costs are only O&M costs
        @expression(EP, eCFixCharge_AC[y in VS_ASYM_AC_CHARGE],
        if y in NEW_CAP_CHARGE_AC # Resources eligible for new charge AC capacity
            by_rid(y,:Inv_Cost_Charge_AC_per_MWyr)*vCAPCHARGE_AC[y] + by_rid(y,:Fixed_OM_Cost_Charge_AC_per_MWyr)*eTotalCapCharge_AC[y]
        else
            by_rid(y,:Fixed_OM_Cost_Charge_AC_per_MWyr)*eTotalCapCharge_AC[y]
        end
        )
        
        # Sum individual resource contributions to fixed costs to get total fixed costs
        @expression(EP, eTotalCFixCharge_AC, sum(EP[:eCFixCharge_AC][y] for y in VS_ASYM_AC_CHARGE))
        EP[:eObj] += eTotalCFixCharge_AC

        ### CONSTRAINTS ###

        # Constraints 1: Retirements and capacity additions
        # Cannot retire more charge AC capacity than existing charge capacity
        @constraint(EP, cVreStorMaxRetChargeAC[y in RET_CAP_CHARGE_AC], vRETCAPCHARGE_AC[y] <= by_rid(y,:Existing_Charge_AC_Cap_MW))
        # Constraint on maximum charge AC capacity (if applicable) [set input to -1 if no constraint on maximum charge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is >= Max_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP, cVreStorMaxCapChargeAC[y in MAX_AC_CHARGE], eTotalCapCharge_AC[y] <= by_rid(y,:Max_Charge_AC_Cap_MW))
        # Constraint on minimum charge AC capacity (if applicable) [set input to -1 if no constraint on minimum charge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is <= Min_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP, cVreStorMinCapChargeAC[y in MIN_AC_CHARGE], eTotalCapCharge_AC[y] >= by_rid(y,:Min_Charge_AC_Cap_MW))

        # Constraint 2: Maximum charging rate must be less than charge power rating
        @constraint(EP, cVreStorMaxChargingAC[y in VS_ASYM_AC_CHARGE, t in 1:T], EP[:vP_AC_CHARGE][y,t] <= EP[:eTotalCapCharge_AC][y])
    end
end