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
	FLECCS(EP::Model, inputs::Dict, UCommit::Int, Reserves::Int)

The FLECCS module determines which flecce deisng should be implemented
FLECCS1 = conventional NGCC-CCS - retrofit is also elibigle
FLECCS2 = NGCC coupled with solvent storate + aux boiler
FLECCS3 = NGCC coupled with solvent storate 
FLECCS4 = NGCC coupled with thermal storage - cold storage + heater for hot storage
FLECCS5 = NGCC coupled with H2 storage
FLECCS6 = NGCC coupled with DAC (GT+Upitt)
FLECCS7 = NGCC coupled  with lime based DAC 
FLECCS8 = Allam cycle coupled with LOX storage 
"""

function fleccs(EP::Model, inputs::Dict, FLECCS::Int,  UCommit::Int, Reserves::Int, CapacityReserveMargin::Int, MinCapReq::Int)
	# load FLECCS fixed and investment module
	println("load FLECCS module")
	# FLECCS
	dfGen_ccs = inputs["dfGen_ccs"]
	FLECCS_ALL = inputs["FLECCS_ALL"]
	COMMIT_ccs = inputs["COMMIT_CCS"]
	NO_COMMIT_ccs = inputs["NO_COMMIT_CCS"]


	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	N_F = inputs["N_F"]

	EP = fleccs_fix(EP, inputs, FLECCS,  UCommit, Reserves)

	# create a container to store the output variables from each subcompoent
	@variable(EP, vFLECCS_output[y in FLECCS_ALL, i in N_F, 1:T]  >= 0)


	if !isempty(NO_COMMIT_ccs)
		EP = fleccs_no_commit(EP, inputs, FLECCS, Reserves)
	end


	if !isempty(COMMIT_ccs)
		EP = fleccs_commit(EP, inputs, FLECCS,UCommit, Reserves)
	end

	if FLECCS ==1
		EP = fleccs1(EP, inputs, FLECCS, UCommit, Reserves)
	elseif FLECCS ==2
		EP = fleccs2(EP, inputs, FLECCS,UCommit, Reserves)
	elseif FLECCS ==3
		EP = fleccs3(EP, inputs, FLECCS, UCommit, Reserves)
	elseif FLECCS ==4
		EP = fleccs4(EP, inputs, FLECCS, UCommit, Reserves)
	elseif FLECCS ==5
		EP = fleccs5(EP, inputs,  FLECCS, UCommit, Reserves)
	elseif FLECCS ==6
		EP = fleccs6(EP, inputs, FLECCS, UCommit, Reserves)
	elseif FLECCS ==7
		EP = fleccs7(EP, inputs, FLECCS, UCommit, Reserves)
	elseif FLECCS ==8
		EP = fleccs8(EP, inputs, FLECCS, UCommit, Reserves)
	end



	##### CO2 emissioms

	# CO2 from start up fuel
	@expression(EP, eEmissionsByFLECCS_start[y in FLECCS_ALL, i in inputs["COMMIT_CCS"], t=1:T],
	    	sum( inputs["CO2_per_Start_FLECCS"][y,i]*EP[:vSTART_FLECCS][y,i,t] for i in inputs["COMMIT_CCS"]))

	# Add CO2 from start up fuel and vented CO2
	if FLECCS ==7
		@expression(EP, eEmissionsByPlantFLECCS[y in FLECCS_ALL, t=1:T], sum(eEmissionsByFLECCS_start[y,i,t] for i in inputs["COMMIT_CCS"])+0.044*EP[:eCO2_vent][y,t] - 0.044*EP[:vCO2_atmosphere][y,t])
	else
		@expression(EP, eEmissionsByPlantFLECCS[y in FLECCS_ALL, t=1:T], sum(eEmissionsByFLECCS_start[y,i,t] for i in inputs["COMMIT_CCS"])+EP[:eCO2_vent][y,t])
    end

	# Capacity Reserves Margin policy
	if CapacityReserveMargin == 1
		@expression(EP, eCapResMarBalanceFLECCS[res=1:inputs["NCapacityReserveMargin"], t=1:T], sum(dfGen_ccs[y,Symbol("CapRes_$res")] * (EP[:eCCS_net][y,t])  for y in FLECCS_ALL))
		EP[:eCapResMarBalance] += eCapResMarBalanceFLECCS
	end

    if (MinCapReq == 1)
        @expression(EP, eMinCapResFLECCS[mincap = 1:inputs["NumberOfMinCapReqs"]], sum(EP[:eTotalCap_FLECCS] for y in dfGen_ccs[(dfGen_ccs[!,Symbol("MinCapTag_$mincap")].== 1) ,:][!,:R_ID]))
		EP[:eMinCapRes] += eMinCapResFLECCS
	end




	return EP
end
