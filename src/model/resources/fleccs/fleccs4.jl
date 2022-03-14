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
	FLECCS3(EP::Model, inputs::Dict, UCommit::Int, Reserves::Int)

The FLECCS3 module creates decision variables, expressions, and constraints related to NGCC-CCS coupled with thermal systems. In this module, we will write up all the constraints formulations associated with the power plant.

This module uses the following 'helper' functions in separate files: FLECCS2_commit() for FLECCS subcompoents subject to unit commitment decisions and constraints (if any) and FLECCS2_no_commit() for FLECCS subcompoents not subject to unit commitment (if any).
"""

function fleccs4(EP::Model, inputs::Dict,  FLECCS::Int, UCommit::Int, Reserves::Int)

	println("FLECCS4, NGCC coupled with thermal storage Module, using heater to generate energy")

	T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    G_F = inputs["G_F"] # Number of FLECCS generator
	FLECCS_ALL = inputs["FLECCS_ALL"] # set of FLECCS generator
	dfGen_ccs = inputs["dfGen_ccs"] # FLECCS general data
#	dfGen_ccs = inputs["dfGen_ccs"] # FLECCS specific parameters
	# get number of flexible subcompoents
	N_F = inputs["N_F"]
	n = length(N_F)


	#NEW_CAP_ccs = inputs["NEW_CAP_FLECCS"] #allow for new capcity build
	#RET_CAP_ccs = inputs["RET_CAP_FLECCS"] #allow for retirement

	START_SUBPERIODS = inputs["START_SUBPERIODS"] #start
    INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"] #interiors

    hours_per_subperiod = inputs["hours_per_subperiod"]

	fuel_type = collect(skipmissing(dfGen_ccs[!,:Fuel]))

	fuel_CO2 = inputs["fuel_CO2"]
	fuel_costs = inputs["fuel_costs"]



	STARTS = 1:inputs["H"]:T
    # Then we record all time periods that do not begin a sub period
    # (these will be subject to normal time couping constraints, looking back one period)
    INTERIORS = setdiff(1:T,STARTS)

	# capacity decision variables


	# variales related to power generation/consumption
    @variables(EP, begin
        # Continuous decision variables
        vP_gt[y in FLECCS_ALL, 1:T]  >= 0 # generation from combustion TURBINE (gas TURBINE)
        #vP_ccs_net[y in FLECCS_ALL, 1:T]  >= 0 # net generation from NGCC-CCS coupled with THERMAL storage
    end)

	# variales related to CO2 and thermal storage
	@variables(EP, begin
        vCAPTURE[y in FLECCS_ALL,1:T] >= 0 # captured co2 at time t, tonne/h
        vSTORE_hot[y in FLECCS_ALL,1:T] >= 0 # energy stored in hot tank storage, MMBTU
        vSTORE_cold[y in FLECCS_ALL,1:T] >= 0 # energy stored in cold tank storage, MMBTU
		vSTEAM_in[y in FLECCS_ALL,1:T] >= 0 # the energy content of steam that fed into the hot storage tank
        vSTEAM_out[y in FLECCS_ALL,1:T] >= 0 # the energy content of steam that pump out of the hot storage tank
		vCOLD_in[y in FLECCS_ALL,1:T] >= 0 # the energy content of cold thermal energy that fed into the hot storage tank
        vCOLD_out[y in FLECCS_ALL,1:T] >= 0 # the energy content of cold thermal energy that pump out of the hot storage tank

	end)



	# the order of those variables must follow the order of subcomponents in the "FLECCS_data3.csv"
	# 1. gas turbine
	# 2. steam turbine
	# 3. PCC
	# 4. Compressor
	# 5. Hot storage tank
	# 6. Cold storage tank
	# 7. Heat pump
	# 8. BOP

	# get the ID of each subcompoents
	# gas turbine
	NGCT_id = inputs["NGCT_id"]
	# steam turbine
	NGST_id = inputs["NGST_id"]
	# PCC
	PCC_id = inputs["PCC_id"]
	# compressor
	Comp_id = inputs["Comp_id"]
	#Hot tank
	Hot_id = inputs["Hot_id"]
	#Cold tank
	Cold_id = inputs["Cold_id"]
	# heat pump
	HeatPump_id = inputs["HeatPump_id"]
	# heat heater
	Heater_id = inputs["Heater_id"]
	#BOP
	BOP_id = inputs["BOP_id"]

	# Specific constraints for FLECCS system
    # Thermal Energy input of combustion TURBINE (or oxyfuel power cycle) at hour "t" [MMBTU], eqn 1
    @expression(EP, eFuel[y in FLECCS_ALL,t=1:T], dfGen_ccs[!,:pHeatRate_gt][1+n*(y-1)] * vP_gt[y,t])

	# additional power output from gas turbine when cold energy is feed into gas turbine, eqn 16
	@expression(EP, ePower_gt_add[y in FLECCS_ALL,t=1:T], vCOLD_out[y,t]/dfGen_ccs[!,:pColdUseRate][1+n*(y-1)] )

	# additional fuel comsumption, eqn 15
	@expression(EP, eFuel_add[y in FLECCS_ALL,t=1:T], dfGen_ccs[!,:pHeatRate_gt_add][1+n*(y-1)] * ePower_gt_add[y,t])


	# Thermal Energy output of steam generated by HRSG at hour "t" [MWh], high pressure steam, eqn 2a
	@expression(EP, eSteam_high[y in FLECCS_ALL,t=1:T], dfGen_ccs[!,:pSteamRate_high][1+n*(y-1)]* eFuel[y,t])
	# mid pressure steam, some of steam is extracted from mid pressure steam turbine, eqn 2d
	@expression(EP, eSteam_mid[y in FLECCS_ALL,t=1:T], dfGen_ccs[!,:pSteamRate_mid][1+n*(y-1)]* eSteam_high[y,t]  )
	# low pressure steam, eqn 2c
	@expression(EP, eSteam_low[y in FLECCS_ALL,t=1:T], dfGen_ccs[!,:pSteamRate_low][1+n*(y-1)] * eSteam_mid[y,t])

    # additional steam generation when addtional power output is generated in the gas turbine
	# Additional high pressure steam, eqn 2e
	@expression(EP, eSteam_high_add[y in FLECCS_ALL,t=1:T], dfGen_ccs[!,:pSteamRate_high_add][1+n*(y-1)] * eFuel_add[y,t])
	# Additional mid pressure steam, some of steam is extracted from mid pressure steam turbine, eqn 2f
	@expression(EP, eSteam_mid_add[y in FLECCS_ALL,t=1:T], dfGen_ccs[!,:pSteamRate_mid_add][1+n*(y-1)]* eSteam_high_add[y,t])
	# Additional low pressure steam, eqn 2g
	@expression(EP, eSteam_low_add[y in FLECCS_ALL,t=1:T], dfGen_ccs[!,:pSteamRate_low_add][1+n*(y-1)] * eSteam_mid_add[y,t])





    # CO2 generated by combustion TURBINE (or oxyfuel power cycle) at hour "t" [tonne/h], eqn 3a
    @expression(EP, eCO2_flue[y in FLECCS_ALL,t=1:T], inputs["CO2_per_MMBTU_FLECCS"][y,NGCT_id]  * (eFuel[y,t]+eFuel_add[y,t]))
	#CO2 vented at time "t" [tonne/h], eqn 3b
    @expression(EP, eCO2_vent[y in FLECCS_ALL,t=1:T], eCO2_flue[y,t] - vCAPTURE[y,t])

    #steam used by post-combustion carbon capture (PCC) unit [MMBTU], eqn 4b
    @expression(EP, eSteam_use_pcc[y in FLECCS_ALL,t=1:T], dfGen_ccs[!,:pSteamUseRate][1+n*(y-1)] * vCAPTURE[y,t] - vSTEAM_out[y,t])

	#power used by post-combustion carbon capture (PCC) unit [MWh], eqn 5
    @expression(EP, ePower_use_pcc[y in FLECCS_ALL,t=1:T], dfGen_ccs[!,:pPowerUseRate][1+n*(y-1)]  * vCAPTURE[y,t])

    #power used by compressor unit [MWh], eqn 7
    @expression(EP, ePower_use_comp[y in FLECCS_ALL,t=1:T], dfGen_ccs[!,:pCO2CompressRate][1+n*(y-1)] * vCAPTURE[y,t])
	#power used by auxiliary [MWh], eqn 8
	@expression(EP, ePower_use_other[y in FLECCS_ALL,t=1:T], dfGen_ccs[!,:pPowerUseRate_Other][1+n*(y-1)] * eFuel[y,t])

    #power used by heat pump for cold energy, eqn 11
	@expression(EP, ePower_use_ts[y in FLECCS_ALL,t=1:T], dfGen_ccs[!,:pPowerUseRate_ts][1+n*(y-1)] * vCOLD_in[y,t])

    # Power consumbed by heater is proportional to vSTEAM_in
	@expression(EP, ePower_use_heater[y in FLECCS_ALL,t=1:T], dfGen_ccs[!,:pPowerUseRate_heater][1+n*(y-1)] * vSTEAM_in[y,t])





	# energy balance for thermal storage tank
	# dynamic of hot tank storage system, normal [MMBTU thermal energy], eqn 12a
	@constraint(EP, cStore_hot[y in FLECCS_ALL, t in INTERIOR_SUBPERIODS],vSTORE_hot[y, t] == vSTORE_hot[y, t-1] + vSTEAM_in[y,t] - vSTEAM_out[y,t])
	# dynamic of rhot tank storage system, wrapping [MMBTU thermal energy], eqn 12b
	@constraint(EP, cStore_hotwrap[y in FLECCS_ALL, t in START_SUBPERIODS],vSTORE_hot[y, t] == vSTORE_hot[y,t+hours_per_subperiod-1] + vSTEAM_in[y,t] - vSTEAM_out[y,t])
	# dynamic of cold tank storage system, normal [MMBTU thermal energy], eqn 13a
	@constraint(EP, cStore_cold[y in FLECCS_ALL, t in INTERIOR_SUBPERIODS],vSTORE_cold[y, t] == vSTORE_cold[y, t-1] + vCOLD_in[y,t] - vCOLD_out[y,t])
	# dynamic of cold tank storage system, wrapping [MMBTU thermal energy], eqn 13b
	@constraint(EP, cStore_coldwrap[y in FLECCS_ALL, t in START_SUBPERIODS],vSTORE_cold[y, t] == vSTORE_cold[y,t+hours_per_subperiod-1]  + vCOLD_in[y,t] - vCOLD_out[y,t])



	#Power generated by steam turbine [MWh], 8e,8f,8g add up
	@expression(EP, ePower_st[y in FLECCS_ALL,t=1:T], (eSteam_high[y,t]+eSteam_high_add[y,t])/dfGen_ccs[!,:pHeatRate_st_high][1+n*(y-1)]+
	(eSteam_mid[y,t] + eSteam_mid_add[y,t])/dfGen_ccs[!,:pHeatRate_st_mid][1+n*(y-1)]+ (eSteam_low[y,t] + eSteam_low_add[y,t]   - eSteam_use_pcc[y,t])/dfGen_ccs[!,:pHeatRate_st_low][1+n*(y-1)])



    @constraint(EP, [y in FLECCS_ALL,t=1:T], eSteam_low[y,t] + eSteam_low_add[y,t]   - eSteam_use_pcc[y,t] >= 0 )

	@expression(EP, ePower_gt[y in FLECCS_ALL,t=1:T], vP_gt[y,t] +ePower_gt_add[y,t] )

	@expression(EP, ePower_aux[y in FLECCS_ALL,t=1:T], ePower_use_comp[y,t] + ePower_use_pcc[y,t] + ePower_use_other[y,t] )

	# NGCC-CCS net power output = vP_gt + ePower_st - ePower_use_comp - ePower_use_pcc, 9b
	@expression(EP, eCCS_net[y in FLECCS_ALL,t=1:T], ePower_gt[y,t] + ePower_st[y,t] -ePower_aux[y,t] -ePower_use_ts[y,t] - ePower_use_heater[y,t])


	# Power balance
	@expression(EP, ePowerBalanceFLECCS[t=1:T, z=1:Z], sum(eCCS_net[y,t] for y in unique(dfGen_ccs[(dfGen_ccs[!,:Zone].==z),:R_ID])))

	# constraints:
	# captured CO2 should be less than the eCO2_flue * maximum co2 capture rate
	@constraint(EP, cMaxCapture_rate[y in FLECCS_ALL,t=1:T], vCAPTURE[y,t] <= (eCO2_flue[y,t])*dfGen_ccs[!,:pCO2CapRate][1+n*(y-1)])
    # the additional power output from gas turbine should have a limit
	@constraint(EP, cMaxAddPower[y in FLECCS_ALL,t=1:T], ePower_gt_add[y,t] <= dfGen_ccs[!,:pCapPercent][1+n*(y-1)]*EP[:eTotalCapFLECCS][y,NGCT_id])


    # steam >0
	@constraint(EP, [y in FLECCS_ALL,t=1:T], eSteam_mid[y,t] >= 0)

	# steam——use——pcc >0
	@constraint(EP, [y in FLECCS_ALL,t=1:T], eSteam_use_pcc[y,t] >= 0)

	# cold energy constraint
	@constraint(EP, [y in FLECCS_ALL,t=1:T], vCOLD_out[y,t] <= eFuel[y,t]*dfGen_ccs[!,:pColdDischarge][1+n*(y-1)] )


	EP[:ePowerBalance] += ePowerBalanceFLECCS


	# create a container for FLECCS output.
	@constraints(EP, begin
	    [y in FLECCS_ALL, i in NGCT_id, t = 1:T],EP[:vFLECCS_output][y,i,t] == vP_gt[y,t]
		[y in FLECCS_ALL, i in NGST_id,t = 1:T],EP[:vFLECCS_output][y,i,t] == ePower_st[y,t]
		[y in FLECCS_ALL, i in PCC_id,t = 1:T],EP[:vFLECCS_output][y,i,t] == vCAPTURE[y,t]
		[y in FLECCS_ALL, i in Comp_id, t =1:T],EP[:vFLECCS_output][y,i,t] == ePower_use_comp[y,t]
		[y in FLECCS_ALL, i in HeatPump_id,t = 1:T],EP[:vFLECCS_output][y,i,t] == ePower_use_ts[y,t]
		[y in FLECCS_ALL, i in Hot_id, t =1:T],EP[:vFLECCS_output][y,i,t] == vSTORE_hot[y,t]
		[y in FLECCS_ALL, i in Cold_id, t =1:T],EP[:vFLECCS_output][y,i,t] == vSTORE_cold[y,t]
		[y in FLECCS_ALL, i in Heater_id, t =1:T],EP[:vFLECCS_output][y,i,t] == ePower_use_heater[y,t]
		#[y in FLECCS_ALL, i in BOP_id, t =1:T],EP[:vFLECCS_output][y,i,t] == eCCS_net[y,t]
	end)

	@constraint(EP, [y in FLECCS_ALL], EP[:eTotalCapFLECCS][y, BOP_id] == EP[:eTotalCapFLECCS][y, NGCT_id]+ EP[:eTotalCapFLECCS][y,NGST_id])






	###########variable cost
	#fuel
	@expression(EP, eCVar_fuel[y in FLECCS_ALL, t = 1:T],(inputs["omega"][t]*fuel_costs[fuel_type[1]][t]*(eFuel[y,t]+eFuel_add[y,t])))

	# CO2 sequestration cost applied to sequestrated CO2
	@expression(EP, eCVar_CO2_sequestration[y in FLECCS_ALL, t = 1:T],(inputs["omega"][t]*vCAPTURE[y,t]*dfGen_ccs[!,:pCO2_sequestration][1+n*(y-1)]))


	# start variable O&M
	# variable O&M for all the teams: combustion turbine (or oxfuel power cycle)
	@expression(EP,eCVar_gt[y in FLECCS_ALL, t = 1:T], inputs["omega"][t]*(dfGen_ccs[(dfGen_ccs[!,:FLECCS_NO].==NGCT_id) .& (dfGen_ccs[!,:R_ID].==y),:Var_OM_Cost_per_Unit][1])*vP_gt[y,t])
	# variable O&M for NGCC-based teams: VOM of steam turbine and co2 compressor
	# variable O&M for steam turbine
	@expression(EP,eCVar_st[y in FLECCS_ALL, t = 1:T], inputs["omega"][t]*(dfGen_ccs[(dfGen_ccs[!,:FLECCS_NO].==NGST_id) .& (dfGen_ccs[!,:R_ID].==y),:Var_OM_Cost_per_Unit][1])*ePower_st[y,t])
	 # variable O&M for compressor
	@expression(EP,eCVar_comp[y in FLECCS_ALL, t = 1:T], inputs["omega"][t]*(dfGen_ccs[(dfGen_ccs[!,:FLECCS_NO].== Comp_id) .& (dfGen_ccs[!,:R_ID].==y),:Var_OM_Cost_per_Unit][1])*(eCO2_flue[y,t] - eCO2_vent[y,t]))


	# specfic variable O&M formulations for each team
	# variable O&M for heat pump
	@expression(EP,eCVar_heatpump[y in FLECCS_ALL, t = 1:T], inputs["omega"][t]*(dfGen_ccs[(dfGen_ccs[!,:FLECCS_NO].== HeatPump_id) .& (dfGen_ccs[!,:R_ID].==y),:Var_OM_Cost_per_Unit][1])*(ePower_use_ts[y,t]))
	# variable O&M for hot storage
	@expression(EP,eCVar_rich[y in FLECCS_ALL, t = 1:T], inputs["omega"][t]*(dfGen_ccs[(dfGen_ccs[!,:FLECCS_NO].== Hot_id) .& (dfGen_ccs[!,:R_ID].==y),:Var_OM_Cost_per_Unit][1])*(vSTORE_hot[y,t]))
	# variable O&M for cold storage
	@expression(EP,eCVar_lean[y in FLECCS_ALL, t = 1:T], inputs["omega"][t]*(dfGen_ccs[(dfGen_ccs[!,:FLECCS_NO].== Cold_id) .& (dfGen_ccs[!,:R_ID].==y),:Var_OM_Cost_per_Unit][1])*(vSTORE_cold[y,t]))
	# variable O&M for PCC
	@expression(EP,eCVar_PCC[y in FLECCS_ALL, t = 1:T], inputs["omega"][t]*(dfGen_ccs[(dfGen_ccs[!,:FLECCS_NO].== PCC_id) .& (dfGen_ccs[!,:R_ID].==y),:Var_OM_Cost_per_Unit][1])*(vCAPTURE[y,t]))


	#adding up variable cost

	@expression(EP,eVar_FLECCS[t = 1:T], sum(eCVar_fuel[y,t] + eCVar_CO2_sequestration[y,t] + eCVar_gt[y,t] + eCVar_st[y,t] + eCVar_comp[y,t] + eCVar_PCC[y,t] +eCVar_heatpump[y,t]  for y in FLECCS_ALL))

	@expression(EP,eTotalCVar_FLECCS, sum(eVar_FLECCS[t] for t in 1:T))


	EP[:eObj] += eTotalCVar_FLECCS



	return EP
end
