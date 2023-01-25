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

	dfGen = inputs["dfGen"]

	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones

    START_SUBPERIODS = inputs["START_SUBPERIODS"]
	INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]
	hours_per_subperiod = inputs["hours_per_subperiod"] # total number of hours per subperiod

    # Policy flags
    EnergyShareRequirement = setup["EnergyShareRequirement"]
	CapacityReserveMargin = setup["CapacityReserveMargin"]
    MinCapReq = setup["MinCapReq"]
    StorageLosses = setup["StorageLosses"]

    # Load VRE-storage inputs
	VRE_STOR = inputs["VRE_STOR"] 	# Set of VRE-STOR generators
    dfVRE_STOR = inputs["dfVRE_STOR"]

    NEW_CAP_ENERGY_VRE_STOR = inputs["NEW_CAP_ENERGY_VRE_STOR"]
    RET_CAP_ENERGY_VRE_STOR = inputs["RET_CAP_ENERGY_VRE_STOR"]
    NEW_CAP_GRID = inputs["NEW_CAP_GRID"]
    RET_CAP_GRID = inputs["RET_CAP_GRID"]
    STOR_VRE_STOR = inputs["STOR_VRE_STOR"]

    by_rid(rid, sym) = by_rid_df(rid, sym, dfVRE_STOR)

    ### Variables ###
    @variables(EP, begin
    # Grid capacity core variables
    vRETGRIDCAP[y in RET_CAP_GRID] >= 0                         # Retired grid capacity [MW]
    vGRIDCAP[y in NEW_CAP_GRID] >= 0                            # New installed grid capacity [AC MW]
    
    # "Behind the inverter" VRE core generation [MW]
    vP_DC[y in VRE_STOR, t=1:T] >= 0

    # All core storage variables
    vCAPENERGY_VRE_STOR[y in NEW_CAP_ENERGY_VRE_STOR] >= 0      # Energy storage reservoir capacity (MWh capacity) built for VRE storage [MWh]
    vRETCAPENERGY_VRE_STOR[y in RET_CAP_ENERGY_VRE_STOR] >= 0   # Energy storage reservoir capacity retired for VRE storage [MWh]
    vS_VRE_STOR[y in STOR_VRE_STOR,t=1:T] >= 0                  # Storage level of resource "y" at hour "t" [MWh] on zone "z"
    vCHARGE_DC[y in STOR_VRE_STOR, t=1:T] >= 0                  # "Behind the inverter" charge from the VRE-component [MW]
    vDISCHARGE_DC[y in STOR_VRE_STOR, t=1:T] >= 0               # "Behind the inverter" discharge [MW]
    vCHARGE_VRE_STOR[y in STOR_VRE_STOR,t=1:T] >= 0             # Energy withdrawn from grid by resource VRE_STOR at hour "t" [MW]
    end)
   
	### Expressions ###

    # Total energy capacity
    @expression(EP, eTotalCap_STOR[y in STOR_VRE_STOR],
		if (y in intersect(NEW_CAP_ENERGY_VRE_STOR, RET_CAP_ENERGY_VRE_STOR)) # Resources eligible for new capacity and retirements
			dfGen[y,:Existing_Cap_MWh] + EP[:vCAPENERGY_VRE_STOR][y] - EP[:vRETCAPENERGY_VRE_STOR][y]
		elseif (y in setdiff(NEW_CAP_ENERGY_VRE_STOR, RET_CAP_ENERGY_VRE_STOR)) # Resources eligible for only new capacity
			dfGen[y,:Existing_Cap_MWh] + EP[:vCAPENERGY_VRE_STOR][y]
		elseif (y in setdiff(RET_CAP_ENERGY_VRE_STOR, NEW_CAP_ENERGY_VRE_STOR)) # Resources eligible for only capacity retirements
			dfGen[y,:Existing_Cap_MWh] - EP[:vRETCAPENERGY_VRE_STOR][y]
		else
			dfGen[y,:Existing_Cap_MWh]
		end
	)

    # Total grid capacity
    @expression(EP, eTotalCap_GRID[y in VRE_STOR], 
        if y in intersect(NEW_CAP_GRID, RET_CAP_GRID) # Resources eligible for new capacity and retirements
            by_rid(y, :Existing_Cap_Grid_MW) + EP[:vGRIDCAP][y] - EP[:vRETGRIDCAP][y]
        elseif y in setdiff(NEW_CAP_GRID, RET_CAP_GRID) # Resources eligible for only new capacity
            by_rid(y, :Existing_Cap_Grid_MW) + EP[:vGRIDCAP][y]
        elseif y in setdiff(RET_CAP_GRID, NEW_CAP_GRID) # Resources eligible for only capacity retirements
            by_rid(y, :Existing_Cap_Grid_MW) - EP[:vRETGRIDCAP][y]
        else
            by_rid(y, :Existing_Cap_Grid_MW)
        end
    )

    ## Objective Function Expressions ###

    # Fixed costs for storage resources
	# If resource is not eligible for new energy capacity, fixed costs are only O&M costs
	@expression(EP, eCFixEnergy_VRE_STOR[y in STOR_VRE_STOR],
    if y in NEW_CAP_ENERGY_VRE_STOR # Resources eligible for new capacity
        dfGen[y,:Inv_Cost_per_MWhyr]*vCAPENERGY_VRE_STOR[y] + dfGen[y,:Fixed_OM_Cost_per_MWhyr]*eTotalCap_STOR[y]
    else
        dfGen[y,:Fixed_OM_Cost_per_MWhyr]*eTotalCap_STOR[y]
    end
    )

    # Fixed costs for grid connection
    # If resource is not eligible for new grid capacity, fixed costs are only O&M costs
	@expression(EP, eCFixGrid[y in VRE_STOR],
    if y in NEW_CAP_GRID # Resources eligible for new capacity
        by_rid(y, :Inv_Cost_Grid_per_MWyr)*vCAPENERGY_VRE_STOR[y] + by_rid(y, :Fixed_OM_Grid_Cost_per_MWyr)*eTotalCap_Grid[y]
    else
        by_rid(y, :Fixed_OM_Grid_Cost_per_MWyr)*eTotalCap_Grid[y]
    end
    )

    # Fixed costs for VRE-STOR resources
    @expression(EP, eCFix_VRE_STOR[y in VRE_STOR], eCFixEnergy_VRE_STOR[y] + eCFixGrid[y])
    # Variable costs of "generation" for VRE-STOR resource "y" during hour "t" = variable O&M plus fuel cost
    @expression(EP, eCVar_out_VRE_STOR[y in VRE_STOR, t=1:T], inputs["omega"][t]*(by_rid(y, :Var_OM_Cost_per_MWh_VRE_STOR)*vP_DC[y,t]*by_rid(y, :EtaInverter) + by_rid(y, :Var_OM_Cost_per_MWh_In)*vCHARGE_VRE_STOR[y,t]))

	# Sum individual resource contributions to variable charging costs to get total variable charging costs
	@expression(EP, eTotalCFix_VRE_STOR, sum(eCFix_VRE_STOR[y] for y in VRE_STOR))
    @expression(EP, eTotalCVar_VRE_STOR, sum(eCVar_out_VRE_STOR[y, t] for y in VRE_STOR, t in 1:T))
	EP[:eObj] += (eTotalCFix_VRE_STOR + eTotalCVar_VRE_STOR)

    # Separate grid costs
    @expression(EP, eTotalCGrid, 
    sum(by_rid(y, :Inv_Cost_Grid_per_MWyr)*vGRIDCAP[y]
    + by_rid(y,:Fixed_OM_Grid_Cost_per_MWyr)*eTotalCap_GRID[y] for y in VRE_STOR))

	## Power Balance Expressions ##

	@expression(EP, ePowerBalance_VRE_STOR[t=1:T, z=1:Z],
	sum(vP[y,t]-vCHARGE_VRE_STOR[y,t] for y=dfVRE_STOR[(dfVRE_STOR[!,:Zone].==z),:][!,:R_ID]))

	EP[:ePowerBalance] += ePowerBalance_VRE_STOR

    ## Policy Expressions ##

    # Energy losses related to technologies (increase in effective demand)
    @expression(EP, eELOSS_VRE_STOR[y in STOR_VRE_STOR], sum(inputs["omega"][t]*(vCHARGE_DC[y,t]/by_rid(y, :EtaInverter) - vDISCHARGE_DC[y,t]/by_rid(y, :EtaInverter)) for t in 1:T))
    
    # From CO2 Policy module
	@expression(EP, eELOSSByZone_VRE_STOR[z=1:Z],
        sum(EP[:eELOSS_VRE_STOR][y] for y in intersect(VRE_STOR, dfGen[dfGen[!,:Zone].==z,:R_ID]))
    )

    if (MinCapReq == 1)
        @expression(EP, eMinCapResVREStor[mincap = 1:inputs["NumberOfMinCapReqs"]], sum(EP[:eTotalCap_VRE][y]*by_rid(y, EtaInverter) for y in dfVRE_STOR[(dfVRE_STOR[!,Symbol("MinCapTag_$mincap")].== 1) ,:][!,:R_ID]))
		EP[:eMinCapRes] += eMinCapResVREStor
	end

    if EnergyShareRequirement >= 1
        @expression(EP, eESRVREStor[ESR=1:inputs["nESR"]], sum(inputs["omega"][t]*dfVRE_STOR[y,Symbol("ESR_$ESR")]*EP[:vP_DC][y,t]*by_rid(y, EtaInverter) for y=dfVRE_STOR[findall(x->x>0,dfVRE_STOR[!,Symbol("ESR_$ESR")]),:R_ID], t=1:T) 
						- sum(inputs["dfESR"][z,ESR]*StorageLosses*sum(EP[:eELOSS_VRE_STOR][y] for y=dfVRE_STOR[(dfVRE_STOR[!,:Zone].==z),:][!,:R_ID]) for z=findall(x->x>0,inputs["dfESR"][:,ESR])))
		EP[:eESR] += eESRVREStor		
        
        #@expression(EP, eESRVREStor[ESR=1:inputs["nESR"]], sum(inputs["omega"][t]*dfGen_VRE_STOR[!,Symbol("ESR_$ESR")][y]*EP[:vP_DC][y,t]*dfGen_VRE_STOR[!,:EtaInverter][y] for y=dfGen_VRE_STOR[findall(x->x>0,dfGen_VRE_STOR[!,Symbol("ESR_$ESR")]),:R_ID], t=1:T))
        #add_to_expression!.(EP[:eESR], EP[:eESRVREStor])

        #if (StorageLosses == 1)
        #    @expression(EP, eESRVREStorLoss[ESR=1:inputs["nESR"]], 
        #        sum(inputs["dfESR"][:, ESR][z] * EP[:eStorageLossByZone_VRE_STOR][z] for z = 1:Z))
        #    add_to_expression!.(EP[:eESR], -1, EP[:eESRVREStorLoss])
        #end
	end

    # Capacity Reserves Margin policy
	if CapacityReserveMargin > 0
	end

    ## Module Expressions ##

    # DC exports
    @expression(EP, eDCExports[y in VRE_STOR, t in 1:T], vDISCHARGE_DC[y, t] + vP_DC[y, t])

    # Grid charging of battery
    @expression(EP, eGridCharging[y in VRE_STOR, t in 1:T], vCHARGE_VRE_STOR[y, t]*dfGen_VRE_STOR[y,:EtaInverter])

    # VRE charging of battery
    @expression(EP, eVRECharging[y in VRE_STOR, t in 1:T], vCHARGE_DC[y, t] - eGridCharging[y, t])

	### Core Constraints ###

    # Constraint 0: Cannot retire more capacity than existing capacity for VRE-STOR technologies
    @constraint(EP, cMaxRet_GRID[y=RET_CAP_GRID], vRETGRIDCAP[y] <= by_rid(y, :Existing_Cap_Grid_MW))
    @constraint(EP, cMaxRet_STOR[y=RET_CAP_ENERGY_VRE_STOR], vRETCAPENERGY_VRE_STOR[y] <= dfGen[!,:Existing_Cap_MWh][y])

    # Constraint 1: Constraint on maximum capacity (if applicable) [set input to -1 if no constraint on maximum capacity]
	# DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is >= Max_Cap_MW and lead to infeasabilty
    @constraint(EP, cMaxCap_STOR[y in intersect(dfGen[dfGen.Max_Cap_MWh.>=0,:R_ID], VRE_STOR)], 
    eTotalCap_STOR[y] <= dfGen[y,:Max_Cap_MWh])
    @constraint(EP, cMaxCap_GRID[y in dfVRE_STOR[dfVRE_STOR.Max_Cap_Grid_MW.>=0,:R_ID]], 
    eTotalCap_GRID[y] <= by_rid(y, :Max_Cap_Grid_MW))
    
    # Constraint 2: Minimum capacity (if applicable) [set input to -1 if no constraint on minimum capacity]
    # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is <= Min_Cap_MW and lead to infeasabilty
    @constraint(EP, cMinCap_STOR[y in intersect(dfGen[dfGen.Min_Cap_MWh.>0,:R_ID], VRE_STOR)], 
    eTotalCap_STOR[y] >= dfGen[y,:Min_Cap_MWh])
    @constraint(EP, cMinCap_GRID[y in dfVRE_STOR[dfVRE_STOR.Min_Cap_Grid_MW.>0,:R_ID], VRE_STOR], 
    eTotalCap_GRID[y] >= by_rid(y, :Min_Cap_Grid_MW))

    # Constraint 3: Inverter Ratio between capacity and grid
    @constraint(EP, cInverterRatio[y in dfVRE_STOR[dfVRE_STOR.Inverter_Ratio.>0,:R_ID]], 
    eTotalCap_VRE[y] == by_rid(y, :Inverter_Ratio) * eTotalCap_GRID[y])

    # Constraint 4: VRE Generation Maximum Constraint
    @constraint(EP, cVREGenMax[y in VRE_STOR, t=1:T],
    vP_DC[y,t] <= inputs["pP_Max"][y,t]*eTotalCap_VRE[y])

    # Constraint 5: Energy Balance Constraint
    @constraint(EP, cEnergyBalance[y in VRE_STOR, t=1:T],
    vDISCHARGE_DC[y, t] + vP_DC[y, t] - vCHARGE_DC[y, t] == vP[y, t]/by_rid(y, :EtaInverter) - eGridCharging[y, t])
    
    # Constraint 6: Grid Export/Import Maximum
    @constraint(EP, cGridExport[y in VRE_STOR, t=1:T],
    vP[y,t] + vCHARGE_VRE_STOR[y,t] <= eTotalCap_GRID[y])	

    # Constraint 6: Charging + Discharging Maximum 
    @constraint(EP, cChargeDischargeMax[y in VRE_STOR, t=1:T],
    vDISCHARGE_DC[y,t] + vCHARGE_DC[y,t] <= by_rid(y, :Power_To_Energy_Ratio) * eTotalCap_STOR[y])

    # Constraint 7: SOC Maximum
    @constraint(EP, cSOCMax[y in VRE_STOR, t=1:T],
    vS_VRE_STOR[y,t] <= eTotalCap_STOR[y])

    # Constraint 8: State of Charge (energy stored for the next hour)
    if OperationWrapping == 1 && !isempty(inputs["VRE_STOR_LONG_DURATION"])
		CONSTRAINTSET = inputs["VRE_STOR_SHORT_DURATION"]
	else
		CONSTRAINTSET = VRE_STOR
	end
    @constraint(EP, cSoCBalInterior_VRE_STOR[t in INTERIOR_SUBPERIODS, y in VRE_STOR], 
    vS_VRE_STOR[y,t] == vS_VRE_STOR[y,t-1] -
                        (1/dfGen[y,:Eff_Down]*vDISCHARGE_DC[y,t]) +
                        (dfGen[y,:Eff_Up]*vCHARGE_DC[y,t]) -
                        (dfGen[y,:Self_Disch]*vS_VRE_STOR[y,t-1]))
    @constraint(EP, cSoCBalStart_VRE_STOR[t in START_SUBPERIODS, y in CONSTRAINTSET],
    vS_VRE_STOR[y,t] == vS_VRE_STOR[y,t+hours_per_subperiod-1] - 
                        (1/dfGen[y,:Eff_Down]*vDISCHARGE_DC[y,t]) +
                        (dfGen[y,:Eff_Up]*vCHARGE_DC[y,t]) -
                        (dfGen[y,:Self_Disch]*vS_VRE_STOR[y,t+hours_per_subperiod-1]))

    # Activate additional storage constraints as needed
    VRE_STOR_and_LDS, VRE_STOR_and_nonLDS, VRE_STOR_and_SYM, VRE_STOR_AND_ASYM = split_LDS_and_ASYM(dfVRE_STOR, inputs, setup)
    inputs["VRE_STOR_and_LDS"] = VRE_STOR_and_LDS
    inputs["VRE_STOR_and_nonLDS"] = VRE_STOR_and_nonLDS
    inputs["VRE_STOR_and_ASYM"] = VRE_STOR_AND_ASYM

    # Activate LDS constraints if nonempty set
    if !isempty(VRE_STOR_and_LDS)
		lds_vre_stor!(EP, inputs)
	end

    # Activate Asymmetric charging constraints if nonempty set
    if !isempty(VRE_STOR_AND_ASYM)
		investment_charge_vre_stor!(EP, inputs)
	end

    # 	# Capacity Reserves Margin policy
	# if CapacityReserveMargin > 0
	# 	CRPL = setup["CapResPeriodLength"]
	# 	@variable(EP, vCAPCONTRSTOR_DISCHARGE[y in VRE_STOR, t=1:T]) # Storage capacity contribution from net discharge
	# 	@variable(EP, vCAPCONTRSTOR_SOC[y in VRE_STOR, t=1:T] >= 0) # Storage capacity contribution from charge held in reserve
	# 	@variable(EP, vMINSOCSTOR[y in VRE_STOR, t=1:T] >= 0) # Minimum SOC maintained over following n hours

	# 	@constraint(EP, cCapContrStorEnergy[y in VRE_STOR, t=1:T], vCAPCONTRSTOR_DISCHARGE[y,t] <= EP[:vP][y,t] - EP[:vCHARGE][y,t])
	# 	@constraint(EP, cMinSocTrackStor[y in VRE_STOR, t=1:T, n=1:CRPL], vMINSOCSTOR[y,t] <= EP[:vS][y, hoursafter(p,t,n)])
	# 	@constraint(EP, cCapContrStorSOC[y in VRE_STOR, t=1:T], vCAPCONTRSTOR_SOC[y,t] <= dfGen[y,:Eff_Down]*vMINSOCSTOR[y,t]/CRPL)
	# 	@constraint(EP, cCapContrStorSOCLim[y in VRE_STOR, t=1:T], vCAPCONTRSTOR_SOC[y,t] <= EP[:eTotalCap][y])
	# 	@constraint(EP, cCapContrStorSOCPartLim[y in VRE_STOR, t=1:T], vCAPCONTRSTOR_SOC[y,t] <= EP[:eTotalCap][y] - vCAPCONTRSTOR_DISCHARGE[y,t])

	# 	@expression(EP, eCapResMarBalanceStor[res=1:inputs["NCapacityReserveMargin"], t=1:T], sum(dfGen[y,Symbol("CapRes_$res")] * (vCAPCONTRSTOR_DISCHARGE[y,t] + vCAPCONTRSTOR_SOC[y,t])  for y in VRE_STOR))
	# 	EP[:eCapResMarBalance] += eCapResMarBalanceStor
	# end
end

@doc raw"""
    split_LDS_and_ASYM(df::DataFrame, inputs::Dict, setup::Dict)

    This function returns the storage type (1. long-duration or short-duration storage, 2. symmetric or asymmetric storage).
"""
function split_LDS_and_ASYM(df::DataFrame, inputs::Dict, setup::Dict)
	VRE_STOR = inputs["VRE_STOR"]
	if setup["OperationWrapping"] == 1
		VRE_STOR_and_LDS = df[df.LDS.==1,:R_ID]
		VRE_STOR_and_nonLDS = df[df.LDS.!=1,:R_ID]
	else
		VRE_STOR_and_LDS = Int[]
		VRE_STOR_and_nonLDS = VRE_STOR
	end

    VRE_STOR_and_SYM = df[df.STOR.==1,:R_ID]
    VRE_STOR_and_ASYM = df[df.STOR.==2,:R_ID]

	return VRE_STOR_and_LDS, VRE_STOR_and_nonLDS, VRE_STOR_and_SYM, VRE_STOR_and_ASYM
end

@doc raw"""
    lds_vre_stor!(EP::Model, inputs::Dict)

    This function activates the decision variables and constraints for LDS resources.
"""
function lds_vre_stor!(EP::Model, inputs::Dict)
    println("VRE-STOR LDS Module")
    REP_PERIOD = inputs["REP_PERIOD"]  # Number of representative periods

	dfPeriodMap = inputs["Period_Map"] # Dataframe that maps modeled periods to representative periods
	NPeriods = nrow(dfPeriodMap) # Number of modeled periods

	MODELED_PERIODS_INDEX = 1:NPeriods
	REP_PERIODS_INDEX = MODELED_PERIODS_INDEX[dfPeriodMap.Rep_Period .== MODELED_PERIODS_INDEX]

    VRE_STOR_AND_LDS = inputs["VRE_STOR_and_LDS"]
    dfGen = inputs["dfGen"]

	@variable(EP, vSOCw_VRE_STOR[y in VRE_STOR_and_LDS, n in MODELED_PERIODS_INDEX] >= 0)

    # Build up in storage inventory over each representative period w
    # Build up inventory can be positive or negative
    @variable(EP, vdSOC_VRE_STOR[y in VRE_STOR_and_LDS, w=1:REP_PERIOD])

    # Note: tw_min = hours_per_subperiod*(w-1)+1; tw_max = hours_per_subperiod*w
    @constraint(EP, cVreStorSoCBalLongDurationStorageStart[w=1:REP_PERIOD, y in VRE_STOR_and_LDS], 
                    (EP[:vS_VRE_STOR][y,hours_per_subperiod * (w - 1) + 1] ==
                    (1 - dfGen[y, :Self_Disch]) * (EP[:vS_VRE_STOR][y, hours_per_subperiod * w] - EP[:vdSOC_VRE_STOR][y,w])
                    - (1 / dfGen[y, :Eff_Down] * EP[:vDISCHARGE_DC][y, hours_per_subperiod * (w - 1) + 1])
                    + (dfGen[y, :Eff_Up] * vCHARGE_DC[y,hours_per_subperiod * (w - 1) + 1]))
                )

    # Storage at beginning of period w = storage at beginning of period w-1 + storage built up in period w (after n representative periods)
    ## Multiply storage build up term from prior period with corresponding weight
    @constraint(EP, cVreStorSoCBalLongDurationStorageInterior[y in VRE_STOR_and_LDS, r in MODELED_PERIODS_INDEX[1:(end-1)]],
                    EP[:vSOCw_VRE_STOR][y,r+1] == EP[:vSOCw_VRE_STOR][y,r] + EP[:vdSOC_VRE_STOR][y,dfPeriodMap[r,:Rep_Period_Index]])

    ## Last period is linked to first period
    @constraint(EP, cVreStorSoCBalLongDurationStorageEnd[y in VRE_STOR_and_LDS, r in MODELED_PERIODS_INDEX[end]],
                    EP[:vSOCw_VRE_STOR][y,1] == EP[:vSOCw_VRE_STOR][y,r] + EP[:vdSOC_VRE_STOR][y,dfPeriodMap[r,:Rep_Period_Index]])

    # Storage at beginning of each modeled period cannot exceed installed energy capacity
    @constraint(EP, cVreStorSoCBalLongDurationStorageUpper[y in VRE_STOR_and_LDS, r in MODELED_PERIODS_INDEX],
                    EP[:vSOCw_VRE_STOR][y,r] <= EP[:eTotalCap_STOR][y])

    # Initial storage level for representative periods must also adhere to sub-period storage inventory balance
    # Initial storage = Final storage - change in storage inventory across representative period
    @constraint(EP, cVreStorSoCBalLongDurationStorageSub[y in VRE_STOR_and_LDS, r in REP_PERIODS_INDEX],
                    EP[:vSOCw_VRE_STOR][y,r] == EP[:vS_VRE_STOR][y,hours_per_subperiod*dfPeriodMap[r,:Rep_Period_Index]] - EP[:vdSOC_VRE_STOR][y,dfPeriodMap[r,:Rep_Period_Index]])
end

@doc raw"""
investment_charge_vre_stor!(EP::Model, inputs::Dict)

    This function activates the decision variables and constraints for asymmetric storage resources (independent charge
        and discharge power capacities (STOR = 2)).
"""
function investment_charge_vre_stor!(EP::Model, inputs::Dict)
    println("VRE-STOR Charge Investment Module")

    VRE_STOR_ASYM = inputs["VRE_STOR_and_ASYM"]
    dfGen = inputs["dfGen"]

    NEW_CAP_CHARGE = intersect(inputs["NEW_CAP_CHARGE"], VRE_STOR_ASYM) # Set of asymmetric charge/discharge storage resources eligible for new charge capacity
	RET_CAP_CHARGE = intersect(inputs["RET_CAP_CHARGE"], VRE_STOR_ASYM) # Set of asymmetric charge/discharge storage resources eligible for charge capacity retirements
    inputs["NEW_CAP_CHARGE_VRE_STOR"] = NEW_CAP_CHARGE
    inputs["RET_CAP_CHARGE_VRE_STOR"] = RET_CAP_CHARGE
    MAX_VRE_STOR_ASYM = intersect(dfGen[dfGen.Max_Charge_Cap_MW.>0,:R_ID], VRE_STOR_ASYM)
    MIN_VRE_STOR_ASYM = intersect(dfGen[dfGen.Min_Charge_Cap_MW.>0,:R_ID], VRE_STOR_ASYM)

    ### Variables ###
	# New installed charge capacity of resource "y"
	@variable(EP, vCAPCHARGE_VRE_STOR[y in intersect(NEW_CAP_CHARGE, VRE_STOR_ASYM)] >= 0)

	# Retired charge capacity of resource "y" from existing capacity
	@variable(EP, vRETCAPCHARGE_VRE_STOR[y in intersect(RET_CAP_CHARGE, VRE_STOR_ASYM)] >= 0)

    @expression(EP, eTotalCapCharge_VRE_STOR[y in VRE_STOR_ASYM],
		if (y in intersect(NEW_CAP_CHARGE, RET_CAP_CHARGE))
			dfGen[y,:Existing_Charge_Cap_MW] + EP[:vCAPCHARGE_VRE_STOR][y] - EP[:vRETCAPCHARGE_VRE_STOR][y]
		elseif (y in setdiff(NEW_CAP_CHARGE, RET_CAP_CHARGE))
			dfGen[y,:Existing_Charge_Cap_MW] + EP[:vCAPCHARGE_VRE_STOR][y]
		elseif (y in setdiff(RET_CAP_CHARGE, NEW_CAP_CHARGE))
			dfGen[y,:Existing_Charge_Cap_MW] - EP[:vRETCAPCHARGE_VRE_STOR][y]
		else
			dfGen[y,:Existing_Charge_Cap_MW]
		end
	)

	## Objective Function Expressions ##

	# Fixed costs for resource "y" = annuitized investment cost plus fixed O&M costs
	# If resource is not eligible for new charge capacity, fixed costs are only O&M costs
	@expression(EP, eCFixCharge_VRE_STOR[y in VRE_STOR_ASYM],
    if y in NEW_CAP_CHARGE # Resources eligible for new charge capacity
        dfGen[y,:Inv_Cost_Charge_per_MWyr]*vCAPCHARGE_VRE_STOR[y] + dfGen[y,:Fixed_OM_Cost_Charge_per_MWyr]*eTotalCapCharge_VRE_STOR[y]
    else
        dfGen[y,:Fixed_OM_Cost_Charge_per_MWyr]*eTotalCapCharge_VRE_STOR[y]
    end
    )

    # Sum individual resource contributions to fixed costs to get total fixed costs
    @expression(EP, eTotalCFixCharge_VRE_STOR, sum(EP[:eCFixCharge_VRE_STOR][y] for y in VRE_STOR_ASYM))
    EP[:eObj] += eTotalCFixCharge_VRE_STOR

    ## Constraints on retirements and capacity additions
	#Cannot retire more charge capacity than existing charge capacity
	@constraint(EP, cVreStorMaxRetCharge[y in RET_CAP_CHARGE], vRETCAPCHARGE_VRE_STOR[y] <= dfGen[y,:Existing_Charge_Cap_MW])

    #Constraints on new built capacity

    # Constraint on maximum charge capacity (if applicable) [set input to -1 if no constraint on maximum charge capacity]
    # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is >= Max_Charge_Cap_MWh and lead to infeasabilty
    @constraint(EP, cVreStorMaxCapCharge[y in MAX_VRE_STOR_ASYM], eTotalCapCharge_VRE_STOR[y] <= dfGen[y,:Max_Charge_Cap_MW])

    # Constraint on minimum charge capacity (if applicable) [set input to -1 if no constraint on minimum charge capacity]
    # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is <= Min_Charge_Cap_MWh and lead to infeasabilty
    @constraint(EP, cVreStorMinCapCharge[y in MIN_VRE_STOR_ASYM], eTotalCapCharge_VRE_STOR[y] >= dfGen[y,:Min_Charge_Cap_MW])

    # Maximum charging rate must be less than charge power rating (CHECK THIS -- DON'T KNOW IF CORRECT)
    @constraint(EP, cVreStorMaxChargingRate[y in VRE_STOR_ASYM, t in 1:T], EP[:vCHARGE_DC][y,t] <= EP[:eTotalCapCharge_VRE_STOR][y])
end