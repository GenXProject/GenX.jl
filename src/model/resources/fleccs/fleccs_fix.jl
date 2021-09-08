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
	fleccs_fix(EP::Model, inputs::Dict)

This function defines the expressions and constraints keeping track of total available power generation capacity associated with FLECCS subcomponents as well as constraints on capacity retirements.

The total capacity of each resource is defined as the sum of the existing capacity plus the newly invested capacity minus any retired capacity (Eq. \ref{eq:totalpowercap}). Note for storage resources, additional energy and charge power capacity decisions and constraints are defined in the storage module.

"""

function fleccs_fix(EP::Model, inputs::Dict,  FLECCS::Int, UCommit::Int, Reserves::Int)

	println(" fleccs investment and fix cost Module")

	T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    G_F = inputs["G_F"] # Number of fleccs generator
	gen_ccs = inputs["dfGen_ccs"]

	NEW_CAP_ccs = inputs["NEW_CAP_fleccs"]
	RET_CAP_ccs = inputs["RET_CAP_fleccs"]
	COMMIT_ccs = inputs["COMMIT_CCS"]
	FLECCS_ALL = inputs["FLECCS_ALL"]


	### Variables ###
	# capacity decision variables
	# NGCC
	if FLECCS in [1,2,3,4,5,6]
	# capacity of gas turbine [MW]
	    @variable(EP, vCAP_gt[y in FLECCS_ALL] >= 0)
	    @variable(EP, vRETCAP_gt[y in FLECCS_ALL] >=0)
	    # capacity of steam turbine [MW]
	    @variable(EP, vCAP_st[y in FLECCS_ALL] >= 0)
	    @variable(EP, vRETCAP_st[y in FLECCS_ALL] >= 0)
	    # capacity of compressor [MW]
	    @variable(EP, vCAP_compressor[y in FLECCS_ALL] >= 0)
	    @variable(EP, vRETCAP_compressor[y in FLECCS_ALL] >= 0)
	end

	if FLECCS ==1
		# FLECCS Module 1, conventional flexible NGCC-CCS
		# Post-combustion carbon capture (PCC) capacity [tonnes of CO2]
		@variable(EP, vCAP_pcc[y in FLECCS_ALL] >= 0)
		@variable(EP, vRETCAP_pcc[y in FLECCS_ALL] >= 0)
	elseif FLECCS==2
		#FLECCS Module 2, NGCC-CCS coupled with solvent storage
		# Rich solvent regeneration capacity [tonne CO2]
		@variable(EP, vCAP_regen[y in FLECCS_ALL] >= 0)
		@variable(EP, vRETCAP_regen[y in FLECCS_ALL] >= 0)
		# Rich solvent/sorbent storage capacity [tonne solvent/sorbent]
		@variable(EP, vCAP_rich[y in FLECCS_ALL] >= 0)
		@variable(EP, vRETCAP_rich[y in FLECCS_ALL] >= 0)
		# Lean solvent/sorbent storage capacity [tonne solvent/sorbent]
		@variable(EP, vCAP_lean[y in FLECCS_ALL] >= 0)
		@variable(EP, vRETCAP_lean[y in FLECCS_ALL] >= 0)
		# CO2 adsorber capacity [tonne CO2]
		@variable(EP, vCAP_capture[y in FLECCS_ALL] >= 0)
		@variable(EP, vRETCAP_capture[y in FLECCS_ALL] >= 0)
	elseif FLECCS==3
		#FLECCS Module 3, NGCC-CCS coupled with hydrogen storage
		# Post-combustion carbon capture (PCC) capacity [tonnes of CO2]
		@variable(EP, vCAP_pcc[y in FLECCS_ALL] >= 0)
		@variable(EP, vRETCAP_pcc[y in FLECCS_ALL] >= 0)
		# Electrolyzer capacity [MW]
		@variable(EP, vCAP_electro[y in FLECCS_ALL] >= 0)
		@variable(EP, vRETCAP_electro[y in FLECCS_ALL] >= 0)
		# hydrogen storage [tonne H2]
		@variable(EP, vCAP_h2[y in FLECCS_ALL] >= 0)
		@variable(EP, vRETCAP_h2[y in FLECCS_ALL] >= 0)
	elseif FLECCS==4
		#FLECCS Module 4, NGCC-CCS coupled with thermal storage
		# Post-combustion carbon capture (PCC) capacity [tonnes of CO2]
		@variable(EP, vCAP_pcc[y in FLECCS_ALL] >= 0)
		@variable(EP, vRETCAP_pcc[y in FLECCS_ALL] >= 0)
		# Thermal storage [MMBTU thermal energy]
		@variable(EP, vCAP_therm[y in FLECCS_ALL] >= 0)
		@variable(EP, vRETCAP_therm[y in FLECCS_ALL] >= 0)

    elseif FLECCS==7
	    # FLECCS Module 7, oxyfuel combine cycle with liquid oxygen storage

		@variable(EP, vCAP_oxy[y in FLECCS_ALL] >= 0)
		@variable(EP, vRETCAP_oxy[y in FLECCS_ALL] >= 0)
	    # Installed capacity of Air separation unit (ASU) [MW]
	    @variable(EP, vCAP_asu[y in FLECCS_ALL] >= 0)
	    @variable(EP, vRETCAP_asu[y in FLECCS_ALL] >= 0)
	    # Installed capacity of liquid oxygen storage (LOX) [t O2]
	    @variable(EP, vCAP_lox[y in FLECCS_ALL] >= 0)
	    @variable(EP, vRETCAP_lox[y in FLECCS_ALL] >= 0)
	    # Installed capacity of CO2 storage tank [t CO2]
	    @variable(EP, vCAP_co2[y in FLECCS_ALL] >= 0)
	    @variable(EP, vRETCAP_co2[y in FLECCS_ALL] >= 0)
    end

    """
	### Expressions ###
	# Cap_Size is set to 1 for all variables when unit UCommit == 0
	# When UCommit > 0, Cap_Size is set to 1 for all variables except those where THERM == 1
	if FLECCS in [1,2,3,4,5,6]
		# gas turbine
		@expression(EP, eTotalCap_gt[y in FLECCS_ALL],
			if y in intersect(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for new capacity and retirements
				if UCommit >=1
				    (gen_ccs[(gen_ccs[!,:TURBINE].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (gen_ccs[(gen_ccs[!,:TURBINE].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*(vCAP_gt[y] - vRETCAP_gt[y])
				else
					(gen_ccs[(gen_ccs[!,:TURBINE].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (vCAP_gt[y] - vRETCAP_gt[y])
				end
			elseif y in setdiff(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for only new capacity
				if UCommit >=1
				    (gen_ccs[(gen_ccs[!,:TURBINE].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (gen_ccs[(gen_ccs[!,:TURBINE].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*vCAP_gt[y]
				else
					(gen_ccs[(gen_ccs[!,:TURBINE].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + vCAP_gt[y]
				end
			elseif y in setdiff(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for only capacity retirements
				if UCommit >=1
					(gen_ccs[(gen_ccs[!,:TURBINE].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) - (gen_ccs[(gen_ccs[!,:TURBINE].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*vRETCAP_gt[y]
				else
					(gen_ccs[(gen_ccs[!,:TURBINE].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) - vRETCAP_gt[y]
				end
			else # Resources not eligible for new capacity or retirements
				(gen_ccs[(gen_ccs[!,:TURBINE].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1])
			end
		)

		# steam turbine
		@expression(EP, eTotalCap_st[y in FLECCS_ALL],
			if y in intersect(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for new capacity and retirements
				if UCommit >=1
					(gen_ccs[(gen_ccs[!,:TURBINE].==2) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (gen_ccs[(gen_ccs[!,:TURBINE].==2) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*(vCAP_st[y] - vRETCAP_st[y])
				else
					(gen_ccs[(gen_ccs[!,:TURBINE].==2) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (vCAP_st[y] - vRETCAP_st[y])
				end
			elseif y in setdiff(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for only new capacity
				if UCommit >=1
					(gen_ccs[(gen_ccs[!,:TURBINE].==2) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (gen_ccs[(gen_ccs[!,:TURBINE].==2) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*vCAP_st[y]
				else
					(gen_ccs[(gen_ccs[!,:TURBINE].==2) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + vCAP_st[y]
				end
			elseif y in setdiff(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for only capacity retirements
				if UCommit >=1
					(gen_ccs[(gen_ccs[!,:TURBINE].==2) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) - (gen_ccs[(gen_ccs[!,:TURBINE].==2) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*vRETCAP_st[y]
				else
					(gen_ccs[(gen_ccs[!,:TURBINE].==2) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) - vRETCAP_st[y]
				end
			else # Resources not eligible for new capacity or retirements
				(gen_ccs[(gen_ccs[!,:TURBINE].==2) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1])
			end
		)

		# CO2 compressor
		@expression(EP, eTotalCap_compressor[y in FLECCS_ALL],
			if y in intersect(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for new capacity and retirements
				if UCommit >=1
					(gen_ccs[(gen_ccs[!,:COMPRESSOR].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (gen_ccs[(gen_ccs[!,:COMPRESSOR].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1]) * (vCAP_compressor[y] - vRETCAP_compressor[y])
				else
					(gen_ccs[(gen_ccs[!,:COMPRESSOR].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (vCAP_compressor[y] - vRETCAP_compressor[y])
				end
			elseif y in setdiff(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for only new capacity
				if UCommit >=1
					(gen_ccs[(gen_ccs[!,:COMPRESSOR].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (gen_ccs[(gen_ccs[!,:COMPRESSOR].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1]) * vCAP_compressor[y]
				else
					(gen_ccs[(gen_ccs[!,:COMPRESSOR].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + vCAP_compressor[y]
				end
			elseif y in setdiff(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for only capacity retirements
				if UCommit >=1
					(gen_ccs[(gen_ccs[!,:COMPRESSOR].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) - (gen_ccs[(gen_ccs[!,:COMPRESSOR].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1]) * vRETCAP_compressor[y]
				else
					(gen_ccs[(gen_ccs[!,:COMPRESSOR].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) - vRETCAP_compressor[y]
				end
			else # Resources not eligible for new capacity or retirements
				(gen_ccs[(gen_ccs[!,:COMPRESSOR].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1])
			end
		)
	end


	if FLECCS ==1
		@expression(EP, eTotalCap_pcc[y in FLECCS_ALL],
			if y in intersect(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for new capacity and retirements
				if UCommit >=1
					(gen_ccs[(gen_ccs[!,:PCC].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (gen_ccs[(gen_ccs[!,:PCC].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*(vCAP_pcc[y] - vRETCAP_pcc[y])
				else
					(gen_ccs[(gen_ccs[!,:PCC].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (vCAP_pcc[y] - vRETCAP_pcc[y])
				end
			elseif y in setdiff(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for only new capacity
				if UCommit >=1
					(gen_ccs[(gen_ccs[!,:PCC].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (gen_ccs[(gen_ccs[!,:PCC].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*vCAP_pcc[y]
				else
					(gen_ccs[(gen_ccs[!,:PCC].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + vCAP_pcc[y]
				end
			elseif y in setdiff(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for only capacity retirements
				if UCommit >=1
					(gen_ccs[(gen_ccs[!,:PCC].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) - (gen_ccs[(gen_ccs[!,:PCC].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*vRETCAP_pcc[y]
				else
					(gen_ccs[(gen_ccs[!,:PCC].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) - vRETCAP_pcc[y]
				end
			else # Resources not eligible for new capacity or retirements
				(gen_ccs[(gen_ccs[!,:PCC].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1])
			end
		)
	elseif FLECCS == 2
		@expression(EP, eTotalCap_absorber[y in FLECCS_ALL],
			if y in intersect(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for new capacity and retirements
				if UCommit >=1
					(gen_ccs[(gen_ccs[!,:ABSORBER].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (gen_ccs[(gen_ccs[!,:ABSORBER].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*(vCAP_capture[y] - vRETCAP_capture[y])
				else
					(gen_ccs[(gen_ccs[!,:ABSORBER].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (vCAP_capture[y] - vRETCAP_capture[y])
				end
			elseif y in setdiff(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for only new capacity
				if UCommit >=1
					(gen_ccs[(gen_ccs[!,:ABSORBER].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (gen_ccs[(gen_ccs[!,:ABSORBER].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*vCAP_capture[y]
				else
					(gen_ccs[(gen_ccs[!,:ABSORBER].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + vCAP_capture[y]
				end
			elseif y in setdiff(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for only capacity retirements
				if UCommit >=1
					(gen_ccs[(gen_ccs[!,:ABSORBER].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) - (gen_ccs[(gen_ccs[!,:ABSORBER].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*vRETCAP_capture[y]
				else
					(gen_ccs[(gen_ccs[!,:ABSORBER].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) - vRETCAP_capture[y]
				end
			else # Resources not eligible for new capacity or retirements
				(gen_ccs[(gen_ccs[!,:ABSORBER].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1])
			end
		)

		@expression(EP, eTotalCap_regen[y in FLECCS_ALL],
			if y in intersect(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for new capacity and retirements
				if UCommit >=1
					(gen_ccs[(gen_ccs[!,:REGEN].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (gen_ccs[(gen_ccs[!,:REGEN].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*(vCAP_regen[y] - vRETCAP_regen[y])
				else
					(gen_ccs[(gen_ccs[!,:REGEN].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (vCAP_regen[y] - vRETCAP_regen[y])
				end
			elseif y in setdiff(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for only new capacity
				if UCommit >=1
					(gen_ccs[(gen_ccs[!,:REGEN].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (gen_ccs[(gen_ccs[!,:REGEN].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*vCAP_regen[y]
				else
					(gen_ccs[(gen_ccs[!,:REGEN].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + vCAP_regen[y]
				end
			elseif y in setdiff(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for only capacity retirements
				if UCommit >=1
					(gen_ccs[(gen_ccs[!,:REGEN].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) - (gen_ccs[(gen_ccs[!,:REGEN].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*vRETCAP_regen[y]
				else
					(gen_ccs[(gen_ccs[!,:REGEN].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) - vRETCAP_regen[y]
				end
			else # Resources not eligible for new capacity or retirements
				(gen_ccs[(gen_ccs[!,:REGEN].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1])
			end
		)


		@expression(EP, eTotalCap_rich[y in FLECCS_ALL],
			if y in intersect(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for new capacity and retirements
				if UCommit >=1
					(gen_ccs[(gen_ccs[!,:SOLVENT].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (gen_ccs[(gen_ccs[!,:SOLVENT].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*(vCAP_rich[y] - vRETCAP_rich[y])
				else
					(gen_ccs[(gen_ccs[!,:SOLVENT].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (vCAP_rich[y] - vRETCAP_rich[y])
				end
			elseif y in setdiff(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for only new capacity
				if UCommit >=1
					(gen_ccs[(gen_ccs[!,:SOLVENT].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (gen_ccs[(gen_ccs[!,:SOLVENT].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*vCAP_rich[y]
				else
					(gen_ccs[(gen_ccs[!,:SOLVENT].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + vCAP_rich[y]
				end
			elseif y in setdiff(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for only capacity retirements
				if UCommit >=1
					(gen_ccs[(gen_ccs[!,:SOLVENT].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) - (gen_ccs[(gen_ccs[!,:SOLVENT].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*vRETCAP_rich[y]
				else
					(gen_ccs[(gen_ccs[!,:SOLVENT].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) - vRETCAP_rich[y]
				end
			else # Resources not eligible for new capacity or retirements
				(gen_ccs[(gen_ccs[!,:SOLVENT].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1])
			end
		)


        @expression(EP, eTotalCap_lean[y in FLECCS_ALL],
			if y in intersect(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for new capacity and retirements
				if UCommit >=1
					(gen_ccs[(gen_ccs[!,:SOLVENT].==2) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (gen_ccs[(gen_ccs[!,:SOLVENT].==2) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*(vCAP_lean[y] - vRETCAP_lean[y])
				else
					(gen_ccs[(gen_ccs[!,:SOLVENT].==2) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (vCAP_lean[y] - vRETCAP_lean[y])
				end
			elseif y in setdiff(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for only new capacity
				if UCommit >=1
					(gen_ccs[(gen_ccs[!,:SOLVENT].==2) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + (gen_ccs[(gen_ccs[!,:SOLVENT].==2) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*vCAP_lean[y]
				else
					(gen_ccs[(gen_ccs[!,:SOLVENT].==2) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) + vCAP_lean[y]
				end
			elseif y in setdiff(NEW_CAP_ccs, RET_CAP_ccs) # Resources eligible for only capacity retirements
				if UCommit >=1
					(gen_ccs[(gen_ccs[!,:SOLVENT].==2) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) - (gen_ccs[(gen_ccs[!,:SOLVENT].==2) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*vRETCAP_lean[y]
				else
					(gen_ccs[(gen_ccs[!,:SOLVENT].==2) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]) - vRETCAP_lean[y]
				end
			else # Resources not eligible for new capacity or retirements
				(gen_ccs[(gen_ccs[!,:SOLVENT].==2) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1])
			end
		)
	end



	## Objective Function Expressions ##

	# Fixed costs for resource "y" = annuitized investment cost plus fixed O&M costs
	# If resource is not eligible for new capacity, fixed costs are only O&M costs
	if FLECCS in [1,2,3,4,5,6]
		@expression(EP, eCFix_gt[y in FLECCS_ALL],
			if y in NEW_CAP_ccs # Resources eligible for new capacity
				if y in COMMIT_ccs
					(gen_ccs[(gen_ccs[!,:TURBINE].==1) .& (gen_ccs[!,:R_ID].==y),:Inv_Cost_per_Unityr][1])*gen_ccs[(gen_ccs[!,:TURBINE].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1]*vCAP_gt[y] + (gen_ccs[(gen_ccs[!,:TURBINE].==1) .& (gen_ccs[!,:R_ID].==y),:Fixed_OM_Cost_per_Unityr][1])*eTotalCap_gt[y]
				else
					(gen_ccs[(gen_ccs[!,:TURBINE].==1) .& (gen_ccs[!,:R_ID].==y),:Inv_Cost_per_Unityr][1])*vCAP_gt[y] + (gen_ccs[(gen_ccs[!,:TURBINE].==1) .& (gen_ccs[!,:R_ID].==y),:Fixed_OM_Cost_per_Unityr][1])*eTotalCap_gt[y]
				end
			else
				(gen_ccs[(gen_ccs[!,:TURBINE].==1) .& (gen_ccs[!,:R_ID].==y),:Fixed_OM_Cost_per_Unityr][1])*eTotalCap_gt[y]
			end
		)

		@expression(EP, eCFix_st[y in FLECCS_ALL],
			if y in NEW_CAP_ccs # Resources eligible for new capacity
				if y in COMMIT_ccs
					(gen_ccs[(gen_ccs[!,:TURBINE].==2) .& (gen_ccs[!,:R_ID].==y),:Inv_Cost_per_Unityr][1])*gen_ccs[(gen_ccs[!,:TURBINE].==2) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1]*vCAP_st[y] + (gen_ccs[(gen_ccs[!,:TURBINE].==2) .& (gen_ccs[!,:R_ID].==y),:Fixed_OM_Cost_per_Unityr][1])*eTotalCap_st[y]
				else
					(gen_ccs[(gen_ccs[!,:TURBINE].==2) .& (gen_ccs[!,:R_ID].==y),:Inv_Cost_per_Unityr][1])*vCAP_st[y] + (gen_ccs[(gen_ccs[!,:TURBINE].==2) .& (gen_ccs[!,:R_ID].==y),:Fixed_OM_Cost_per_Unityr][1])*eTotalCap_st[y]
				end
			else
				(gen_ccs[(gen_ccs[!,:TURBINE].==2) .& (gen_ccs[!,:R_ID].==y),:Fixed_OM_Cost_per_Unityr][1])*eTotalCap_st[y]
			end
		)

		@expression(EP, eCFix_compressor[y in FLECCS_ALL],
			if y in NEW_CAP_ccs # Resources eligible for new capacity
				if y in COMMIT_ccs
					(gen_ccs[(gen_ccs[!,:COMPRESSOR].==1) .& (gen_ccs[!,:R_ID].==y),:Inv_Cost_per_Unityr][1])*gen_ccs[(gen_ccs[!,:COMPRESSOR].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1]*vCAP_compressor[y] + (gen_ccs[(gen_ccs[!,:COMPRESSOR].==1) .& (gen_ccs[!,:R_ID].==y),:Fixed_OM_Cost_per_Unityr][1])*eTotalCap_compressor[y]
				else
					(gen_ccs[(gen_ccs[!,:COMPRESSOR].==1) .& (gen_ccs[!,:R_ID].==y),:Inv_Cost_per_Unityr][1])*vCAP_compressor[y] + (gen_ccs[(gen_ccs[!,:COMPRESSOR].==1) .& (gen_ccs[!,:R_ID].==y),:Fixed_OM_Cost_per_Unityr][1])*eTotalCap_compressor[y]
				end
			else
				(gen_ccs[(gen_ccs[!,:COMPRESSOR].==1) .& (gen_ccs[!,:R_ID].==y),:Fixed_OM_Cost_per_Unityr][1])*eTotalCap_compressor[y]
			end
		)
	end

	if FLECCS == 2
		@expression(EP, eCFix_absorber[y in FLECCS_ALL],
			if y in NEW_CAP_ccs # Resources eligible for new capacity
				if y in COMMIT_ccs
					(gen_ccs[(gen_ccs[!,:ABSORBER].==1) .& (gen_ccs[!,:R_ID].==y),:Inv_Cost_per_Unityr][1])*gen_ccs[(gen_ccs[!,:ABSORBER].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1]*vCAP_capture[y] + (gen_ccs[(gen_ccs[!,:ABSORBER].==1) .& (gen_ccs[!,:R_ID].==y),:Fixed_OM_Cost_per_Unityr][1])*eTotalCap_absorber[y]
				else
					(gen_ccs[(gen_ccs[!,:ABSORBER].==1) .& (gen_ccs[!,:R_ID].==y),:Inv_Cost_per_Unityr][1])*vCAP_capture[y] + (gen_ccs[(gen_ccs[!,:ABSORBER].==1) .& (gen_ccs[!,:R_ID].==y),:Fixed_OM_Cost_per_Unityr][1])*eTotalCap_absorber[y]
				end
			else
				(gen_ccs[(gen_ccs[!,:ABSORBER].==1) .& (gen_ccs[!,:R_ID].==y),:Fixed_OM_Cost_per_Unityr][1])*eTotalCap_absorber[y]
			end
		)

		@expression(EP, eCFix_regen[y in FLECCS_ALL],
			if y in NEW_CAP_ccs # Resources eligible for new capacity
				if y in COMMIT_ccs
					(gen_ccs[(gen_ccs[!,:REGEN].==1) .& (gen_ccs[!,:R_ID].==y),:Inv_Cost_per_Unityr][1])*gen_ccs[(gen_ccs[!,:REGEN].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1]*vCAP_regen[y] + (gen_ccs[(gen_ccs[!,:REGEN].==1) .& (gen_ccs[!,:R_ID].==y),:Fixed_OM_Cost_per_Unityr][1])*eTotalCap_regen[y]
				else
					(gen_ccs[(gen_ccs[!,:REGEN].==1) .& (gen_ccs[!,:R_ID].==y),:Inv_Cost_per_Unityr][1])*vCAP_regen[y] + (gen_ccs[(gen_ccs[!,:REGEN].==1) .& (gen_ccs[!,:R_ID].==y),:Fixed_OM_Cost_per_Unityr][1])*eTotalCap_regen[y]
				end
			else
				(gen_ccs[(gen_ccs[!,:REGEN].==1) .& (gen_ccs[!,:R_ID].==y),:Fixed_OM_Cost_per_Unityr][1])*eTotalCap_regen[y]
			end
		)

		@expression(EP, eCFix_rich[y in FLECCS_ALL],
			if y in NEW_CAP_ccs # Resources eligible for new capacity
				if y in COMMIT_ccs
					(gen_ccs[(gen_ccs[!,:SOLVENT].==1) .& (gen_ccs[!,:R_ID].==y),:Inv_Cost_per_Unityr][1])*gen_ccs[(gen_ccs[!,:SOLVENT].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1]*vCAP_lean[y]*vCAP_rich[y] + (gen_ccs[(gen_ccs[!,:SOLVENT].==1) .& (gen_ccs[!,:R_ID].==y),:Fixed_OM_Cost_per_Unityr][1])*eTotalCap_rich[y]
				else
					(gen_ccs[(gen_ccs[!,:SOLVENT].==1) .& (gen_ccs[!,:R_ID].==y),:Inv_Cost_per_Unityr][1])*vCAP_rich[y] + (gen_ccs[(gen_ccs[!,:SOLVENT].==1) .& (gen_ccs[!,:R_ID].==y),:Fixed_OM_Cost_per_Unityr][1])*eTotalCap_rich[y]
				end
			else
				(gen_ccs[(gen_ccs[!,:SOLVENT].==1) .& (gen_ccs[!,:R_ID].==y),:Fixed_OM_Cost_per_Unityr][1])*eTotalCap_rich[y]
			end
		)

		@expression(EP, eCFix_lean[y in FLECCS_ALL],
			if y in NEW_CAP_ccs # Resources eligible for new capacity
				if y in COMMIT_ccs
					(gen_ccs[(gen_ccs[!,:SOLVENT].==2) .& (gen_ccs[!,:R_ID].==y),:Inv_Cost_per_Unityr][1])*gen_ccs[(gen_ccs[!,:SOLVENT].==2) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1]*vCAP_lean[y] + (gen_ccs[(gen_ccs[!,:SOLVENT].==2) .& (gen_ccs[!,:R_ID].==y),:Fixed_OM_Cost_per_Unityr][1])*eTotalCap_lean[y]
				else
					(gen_ccs[(gen_ccs[!,:SOLVENT].==2) .& (gen_ccs[!,:R_ID].==y),:Inv_Cost_per_Unityr][1])*vCAP_lean[y] + (gen_ccs[(gen_ccs[!,:SOLVENT].==2) .& (gen_ccs[!,:R_ID].==y),:Fixed_OM_Cost_per_Unityr][1])*eTotalCap_lean[y]
				end
			else
				(gen_ccs[(gen_ccs[!,:SOLVENT].==2) .& (gen_ccs[!,:R_ID].==y),:Fixed_OM_Cost_per_Unityr][1])*eTotalCap_lean[y]
			end
		)

		@expression(EP, eTotalCFix_ccs, sum((eCFix_gt[y] + eCFix_st[y] + eCFix_compressor[y] + eCFix_absorber[y] + eCFix_regen[y] + eCFix_rich[y] + eCFix_lean[y]) for y in FLECCS_ALL))

	end

	# Add term to objective function expression
	EP[:eObj] += eTotalCFix_ccs

	### Constratints ###
	## Constraints on retirements and capacity additions
	# Cannot retire more capacity than existing capacity
	if FLECCS in [1,2,3,4,5,6]

		@constraint(EP, cMaxRetNoCommit_gt[y in setdiff(RET_CAP_ccs,COMMIT_ccs)], vRETCAP_gt[y] <=(gen_ccs[(gen_ccs[!,:TURBINE].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])* (gen_ccs[(gen_ccs[!,:TURBINE].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]))
		@constraint(EP, cMaxRetNoCommit_st[y in setdiff(RET_CAP_ccs,COMMIT_ccs)], vRETCAP_st[y] <= (gen_ccs[(gen_ccs[!,:TURBINE].==2) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*(gen_ccs[(gen_ccs[!,:TURBINE].==2) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]))
		@constraint(EP, cMaxRetNoCommit_compressor[y in setdiff(RET_CAP_ccs,COMMIT_ccs)], vRETCAP_compressor[y] <= (gen_ccs[(gen_ccs[!,:COMPRESSOR].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*(gen_ccs[(gen_ccs[!,:COMPRESSOR].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]))

		@constraint(EP, cMaxRetCommit_gt[y in setdiff(RET_CAP_ccs,COMMIT_ccs)], vRETCAP_gt[y] <= (gen_ccs[(gen_ccs[!,:TURBINE].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]))
		@constraint(EP, cMaxRetCommit_st[y in setdiff(RET_CAP_ccs,COMMIT_ccs)], vRETCAP_st[y] <= (gen_ccs[(gen_ccs[!,:TURBINE].==2) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]))
		@constraint(EP, cMaxRetCommit_compressor[y in setdiff(RET_CAP_ccs,COMMIT_ccs)], vRETCAP_compressor[y] <= (gen_ccs[(gen_ccs[!,:COMPRESSOR].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]))
	end


	if FLECCS == 2
		@constraint(EP, cMaxRetNoCommit_absorber[y in setdiff(RET_CAP_ccs,COMMIT_ccs)], vRETCAP_capture[y] <= (gen_ccs[(gen_ccs[!,:ABSORBER].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]))
		@constraint(EP, cMaxRetNoCommit_regen[y in setdiff(RET_CAP_ccs,COMMIT_ccs)], vRETCAP_regen[y] <= (gen_ccs[(gen_ccs[!,:REGEN].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]))
		@constraint(EP, cMaxRetNoCommit_rich[y in setdiff(RET_CAP_ccs,COMMIT_ccs)], vRETCAP_rich[y] <= (gen_ccs[(gen_ccs[!,:SOLVENT].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]))
		@constraint(EP, cMaxRetNoCommit_lean[y in setdiff(RET_CAP_ccs,COMMIT_ccs)], vRETCAP_lean[y] <= (gen_ccs[(gen_ccs[!,:SOLVENT].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]))



		@constraint(EP, cMaxRetCommit_absorber[y in setdiff(RET_CAP_ccs,COMMIT_ccs)], vRETCAP_capture[y] <= (gen_ccs[(gen_ccs[!,:ABSORBER].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*(gen_ccs[(gen_ccs[!,:ABSORBER].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]))
		@constraint(EP, cMaxRetCommit_regen[y in setdiff(RET_CAP_ccs,COMMIT_ccs)], vRETCAP_regen[y] <= (gen_ccs[(gen_ccs[!,:REGEN].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*(gen_ccs[(gen_ccs[!,:REGEN].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]))
		@constraint(EP, cMaxRetCommit_rich[y in setdiff(RET_CAP_ccs,COMMIT_ccs)], vRETCAP_rich[y] <= (gen_ccs[(gen_ccs[!,:SOLVENT].==1) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*(gen_ccs[(gen_ccs[!,:SOLVENT].==1) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]))
		@constraint(EP, cMaxRetCommit_lean[y in setdiff(RET_CAP_ccs,COMMIT_ccs)], vRETCAP_lean[y] <= (gen_ccs[(gen_ccs[!,:SOLVENT].==2) .& (gen_ccs[!,:R_ID].==y),:Cap_Size][1])*(gen_ccs[(gen_ccs[!,:SOLVENT].==2) .& (gen_ccs[!,:R_ID].==y),:Existing_Cap_Unit][1]))

	end


	# adding up the fixed cost!
	if FLECCS ==1
		@expression(EP,eTotalCFix_fleccs, sum(eCFix_gt[y] + eCFix_st[y] + eCFix_compressor[y] + eCFix_pcc[y] for y in FLECCS_ALL))
	elseif FLECCS ==2
		@expression(EP,eTotalCFix_fleccs, sum(eCFix_gt[y] + eCFix_st[y] + eCFix_compressor[y] +eCFix_absorber[y] + eCFix_regen[y] + eCFix_rich[y] +eCFix_lean[y] for y in FLECCS_ALL))
	elseif FLECCS == 3
		@expression(EP,eTotalCFix_fleccs, sum(eCFix_gt[y] + eCFix_st[y] + eCFix_compressor[y] + eCFix_pcc[y] + eCFix_electro[y]+ eCFix_h2[y]   for y in FLECCS_ALL))
	elseif FLECCS == 4
		@expression(EP,eTotalCFix_fleccs, sum(eCFix_gt[y] + eCFix_st[y] + eCFix_compressor[y] + eCFix_pcc[y] + eCFix_therm[y]   for y in FLECCS_ALL))
	elseif FLECCS == 6
		@expression(EP,eTotalCFix_fleccs, sum(eCFix_gt[y] + eCFix_asu[y] +eCFix_lox[y] +eCFix_co2[y] for y in FLECCS_ALL))
	end
	# Add to eCFix objective

	EP[:eObj] += eTotalCFix_fleccs
	###
	"""
	return EP
end
