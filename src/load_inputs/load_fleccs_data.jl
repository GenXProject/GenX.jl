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
	loaderators_data(setup::Dict, path::AbstractString, inputs::Dict, fuel_costs::Dict, fuel_CO2::Dict)

Function for reading input parameters related to electricity generators (plus storage and flexible demand resources)
"""
function load_fleccs_data(setup::Dict, path::AbstractString, inputs_ccs::Dict, fuel_costs::Dict, fuel_CO2::Dict)

	if setup["FLECCS"] == 1
		dfGen_ccs = DataFrame(CSV.File(joinpath(path,"FLECCS_data1.csv"), header=true), copycols=true)
		FLECCS_parameters = DataFrame(CSV.File(joinpath(path,"FLECCS_data1_process_parameters.csv"), header=true), copycols=true)


		println("FLECCS_data1.csv Successfully Read!, NGCC-CCS without flexible subcompoents")
	elseif setup["FLECCS"] == 2
		dfGen_ccs = DataFrame(CSV.File(joinpath(path,"FLECCS_data2.csv"), header=true), copycols=true)
		FLECCS_parameters =  DataFrame(CSV.File(joinpath(path,"FLECCS_data2_process_parameters.csv"), header=true), copycols=true)
		println("FLECCS_data2.csv Successfully Read!, NGCC-CCS with solvent storage")
	elseif setup["FLECCS"] == 3
		dfGen_ccs = DataFrame(CSV.File(joinpath(path,"FLECCS_data3.csv"), header=true), copycols=true)
		FLECCS_parameters = DataFrame(CSV.File(joinpath(path,"FLECCS_data3_process_parameters.csv"), header=true), copycols=true)
		println("FLECCS_data3.csv Successfully Read!, NGCC-CCS with thermal storage - option1")

	elseif setup["FLECCS"] == 4
		dfGen_ccs = DataFrame(CSV.File(joinpath(path,"FLECCS_data4.csv"), header=true), copycols=true)
		FLECCS_parameters = DataFrame(CSV.File(joinpath(path,"FLECCS_data4_process_parameters.csv"), header=true), copycols=true)

		println("FLECCS_data4.csv Successfully Read!, NGCC-CCS with thermal storage - option2")

	elseif setup["FLECCS"] == 5
		dfGen_ccs = DataFrame(CSV.File(joinpath(path,"FLECCS_data5.csv"), header=true), copycols=true)
		FLECCS_parameters = DataFrame(CSV.File(joinpath(path,"FLECCS_data5_process_parameters.csv"), header=true), copycols=true)
		println("FLECCS_data5.csv Successfully Read!, NGCC-CCS with hydrogen generation and storage")

	elseif setup["FLECCS"] == 6
		dfGen_ccs = DataFrame(CSV.File(joinpath(path,"FLECCS_data6.csv"), header=true), copycols=true)
		FLECCS_parameters = DataFrame(CSV.File(joinpath(path,"FLECCS_data6_process_parameters.csv"), header=true), copycols=true)
		println("FLECCS_data6.csv Successfully Read!, NGCC-CCS with DAC")

	elseif setup["FLECCS"] == 7
		dfGen_ccs = DataFrame(CSV.File(joinpath(path,"FLECCS_data7.csv"), header=true), copycols=true)
		FLECCS_parameters =  DataFrame(CSV.File(joinpath(path,"FLECCS_data7_process_parameters.csv"), header=true), copycols=true)
		println("FLECCS_data7.csv Successfully Read!, NGCC-CCS with DAC-MIT")

	elseif setup["FLECCS"] == 8
		dfGen_ccs = DataFrame(CSV.File(joinpath(path,"FLECCS_data8.csv"), header=true), copycols=true)
		FLECCS_parameters = DataFrame(CSV.File(joinpath(path,"FLECCS_data8_process_parameters.csv"), header=true), copycols=true)
		println("FLECCS_data8.csv Successfully Read!, NGCC-CCS with Allam cycle")
	end

	inputs_ccs["n_F"] =nrow(dfGen_ccs)
	inputs_ccs["N_F"] = unique(dfGen_ccs[!,:FLECCS_NO])
	inputs_ccs["G_F"] = length(unique(dfGen_ccs[!,:R_ID]))
	inputs_ccs["dfGen_ccs"] = dfGen_ccs
	inputs_ccs["FLECCS_ALL"] = unique(dfGen_ccs[!,:R_ID])


	if setup["ParameterScale"] ==1
		if setup["FLECCS"] == 8
			FLECCS_parameters[!,:intercept] = FLECCS_parameters[!,:intercept]/ModelScalingFactor
		end
	end




	inputs_ccs["FLECCS_parameters"] = FLECCS_parameters

    # Set indices for internal use
	n_F =nrow(dfGen_ccs)
	FLECCS_ALL =unique(dfGen_ccs[!,:R_ID])
	N_F = unique(dfGen_ccs[!,:FLECCS_NO])

	# save fuel_costs and CO2_fuel
	inputs_ccs["fuel_costs"] = fuel_costs
	inputs_ccs["fuel_CO2"] = fuel_CO2


	# Set of all resources eligible for new capacity
	inputs_ccs["NEW_CAP_FLECCS"] = intersect(dfGen_ccs[dfGen_ccs.New_Build.==1,:FLECCS_NO], dfGen_ccs[dfGen_ccs.Max_Cap_MW.!=0,:FLECCS_NO])
	# Set of all resources eligible for capacity retirements
	inputs_ccs["RET_CAP_FLECCS"] = intersect(dfGen_ccs[dfGen_ccs.New_Build.!=-1,:FLECCS_NO], dfGen_ccs[dfGen_ccs.Existing_Cap_MW.>=0,:FLECCS_NO])

	# Zones resources are located in
	zones = collect(skipmissing(dfGen_ccs[!,:Zone][1:inputs_ccs["n_F"]]))


	if setup["ParameterScale"] ==1  # Parameter scaling turned on - adjust values of subset of parameter values
		# The existing charging capacity for resources where STOR = 2
		inputs_ccs["dfGen_ccs"][!,:Existing_Cap_Unit] = dfGen_ccs[!,:Existing_Cap_Unit]/ModelScalingFactor # Convert from MW to GW, or from tCO2 to kt CO2

		# Cap_Size scales only capacities for those technologies with capacity >1
		# Step 1: convert vector to float
		inputs_ccs["dfGen_ccs"][!,:Cap_Size] =convert(Array{Float64}, dfGen_ccs[!,:Cap_Size])
		for g in 1:n_F  # Scale only those capacities for which Cap_Size > 1
			if inputs_ccs["dfGen_ccs"][!,:Cap_Size][g]>1.0
				inputs_ccs["dfGen_ccs"][!,:Cap_Size][g] = dfGen_ccs[!,:Cap_Size][g]/ModelScalingFactor # Convert to GW
			end
		end

		## Investment cost terms
		# Annualized capacity investment cost of a generation technology
		inputs_ccs["dfGen_ccs"][!,:Inv_Cost_per_Unityr] = dfGen_ccs[!,:Inv_Cost_per_Unityr]/ModelScalingFactor # Convert to $ million/GW/yr with objective function in millions
		## Fixed O&M cost terms
		# Fixed operations and maintenance cost of a generation or storage technology
		inputs_ccs["dfGen_ccs"][!,:Fixed_OM_Cost_per_Unityr] = dfGen_ccs[!,:Fixed_OM_Cost_per_Unityr]/ModelScalingFactor # Convert to $ million/GW/yr with objective function in millions
		## Variable O&M cost terms
		# Variable operations and maintenance cost of a generation or storage technology
		inputs_ccs["dfGen_ccs"][!,:Var_OM_Cost_per_Unit] = dfGen_ccs[!,:Var_OM_Cost_per_Unit]/ModelScalingFactor # Convert to $ million/GWh with objective function in millions

	end

    # the CO2 emissions scaling
	fuel_type = permutedims(reshape(collect(skipmissing(dfGen_ccs[!,:Fuel])), length(N_F), length(FLECCS_ALL)))

	inputs_ccs["C_Fuel_per_MMBTU_FLECCS"] = reshape(repeat(zeros(Float64, length(N_F), inputs_ccs["T"]), length(FLECCS_ALL)),  length(FLECCS_ALL), length(N_F), inputs_ccs["T"])
	inputs_ccs["CO2_per_MMBTU_FLECCS"] = zeros(Float64,length(FLECCS_ALL), length(N_F))

	for y in FLECCS_ALL
		for i in N_F
			# NOTE: When Setup[ParameterScale] =1, fuel costs are scaled in fuels_data.csv, so no if condition needed to scale C_Fuel_per_MWh
		    inputs_ccs["C_Fuel_per_MMBTU_FLECCS"][y,i,:] = fuel_costs[fuel_type[y,i]]
		    inputs_ccs["CO2_per_MMBTU_FLECCS"][y,i] = fuel_CO2[fuel_type[y,i]]
			if setup["ParameterScale"] ==1
			    inputs_ccs["C_Fuel_per_MMBTU_FLECCS"][y,i,:] = fuel_costs[fuel_type[y,i]]*ModelScalingFactor
		        inputs_ccs["CO2_per_MMBTU_FLECCS"][y,i] = fuel_CO2[fuel_type[y,i]]*ModelScalingFactor
			end
		end
	end

	## delete CO2 seuquestration cost when adding qingyu's module
	# scale CO2 sequestration cost

	if setup["ParameterScale"] == 1
		inputs_ccs["FLECCS_parameters"][!,:pCO2_sequestration] = convert(Array{Float64}, inputs_ccs["FLECCS_parameters"][!,:pCO2_sequestration])/ModelScalingFactor

	end




    # Account for the CO2 emissions associated with start up fuel
	if setup["UCommit"]>=1

		inputs_ccs["COMMIT_CCS"] = unique(dfGen_ccs[dfGen_ccs.THERM.==1,:FLECCS_NO])
		inputs_ccs["NO_COMMIT_CCS"] = unique(dfGen_ccs[dfGen_ccs.THERM.==0,:FLECCS_NO])


		if setup["ParameterScale"] ==1  # Parameter scaling turned on - adjust values of subset of parameter values
			# Cost per MW of nameplate capacity to start a generator
			inputs_ccs[!,:Start_Cost_per_Unit] = dfGen_ccs[!,:Start_Cost_per_Unit]/ModelScalingFactor # Convert to $ million/GW with objective function in millions
		end
		# Fuel consumed on start-up (million BTUs per MW per start) if unit commitment is modelled
		start_fuel = permutedims(reshape(convert(Array{Float64}, collect(skipmissing(dfGen_ccs[!,:Start_Fuel_MMBTU_per_Unit]))),length(N_F), length(FLECCS_ALL)))
		# Fixed cost per start-up ($ per MW per start) if unit commitment is modelled
		start_cost = permutedims(reshape(convert(Array{Float64}, collect(skipmissing(inputs_ccs["dfGen_ccs"][!,:Start_Cost_per_Unit]))),length(N_F), length(FLECCS_ALL)))


		inputs_ccs["C_Start_FLECCS"] = reshape(repeat(zeros(Float64, length(N_F), inputs_ccs["T"]), length(FLECCS_ALL)),  length(FLECCS_ALL), length(N_F),inputs_ccs["T"])
		inputs_ccs["CO2_per_Start_FLECCS"] =zeros(Float64,length(FLECCS_ALL), length(N_F))

	    # Fuel used by each resource
	    for y in FLECCS_ALL
			for i in N_F
			    # Start-up cost is sum of fixed cost per start plus cost of fuel consumed on startup.
			    # CO2 from fuel consumption during startup also calculated
		        #inputs_ccs["C_Start"][g,:] = inputs_ccs["dfGen_ccs"][!,:Cap_Size][g] * (fuel_costs[fuel_type[g]] .* start_fuel[g] .+ start_cost[g])
			    inputs_ccs["C_Start_FLECCS"][y,i,:] =  dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i] * (fuel_costs[fuel_type[y,i]] .* start_fuel[y,i] .+ start_cost[y,i])
			    # No need to re-scale C_Start since Cap_size, fuel_costs and start_cost are scaled When Setup[ParameterScale] =1 - Dharik
			    inputs_ccs["CO2_per_Start_FLECCS"][y,i] = dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i] * (fuel_CO2[fuel_type[y,i]] .* start_fuel[y,i])
				if setup["ParameterScale"] ==1
				    inputs_ccs["CO2_per_Start_FLECCS"][y,i] = (fuel_CO2[fuel_type[y,i]] .* start_fuel[y,i]) * ModelScalingFactor
					inputs_ccs["C_Start_FLECCS"][y,i,:] = inputs_ccs["C_Start_FLECCS"][y,i,:]/ModelScalingFactor
				end
			end
		end
	else
		inputs_ccs["COMMIT_CCS"] = Int64[]
		inputs_ccs["NO_COMMIT_CCS"] = N_F[1:end-1]
	end



    #setup subcompoents ID number
	if setup["FLECCS"] == 1
		# gas turbine
	    inputs_ccs["NGCT_id"] = dfGen_ccs[(dfGen_ccs[!,:TURBINE].==1),:FLECCS_NO][1]
	    # steam turbine
	    inputs_ccs["NGST_id"] = dfGen_ccs[(dfGen_ccs[!,:TURBINE].==2),:FLECCS_NO][1]
	    # absorber
	    inputs_ccs["PCC_id"] = dfGen_ccs[(dfGen_ccs[!,:ABSORBER].==1),:FLECCS_NO][1]
	    # compressor
	    inputs_ccs["Comp_id"] = dfGen_ccs[(dfGen_ccs[!,:COMPRESSOR].==1),:FLECCS_NO][1]
	    #BOP
	    inputs_ccs["BOP_id"] = dfGen_ccs[(dfGen_ccs[!,:BOP].==1),:FLECCS_NO][1]
	elseif setup["FLECCS"] == 2
	    # get the ID of each subcompoents
	    # gas turbine
	    inputs_ccs["NGCT_id"] = dfGen_ccs[(dfGen_ccs[!,:TURBINE].==1),:FLECCS_NO][1]
	    # steam turbine
	    inputs_ccs["NGST_id"] = dfGen_ccs[(dfGen_ccs[!,:TURBINE].==2),:FLECCS_NO][1]
	    # absorber
	    inputs_ccs["Absorber_id"] = dfGen_ccs[(dfGen_ccs[!,:ABSORBER].==1),:FLECCS_NO][1]
	    # regenerator
	    inputs_ccs["Regen_id"] = dfGen_ccs[(dfGen_ccs[!,:REGEN].==1),:FLECCS_NO][1]
	    # compressor
	    inputs_ccs["Comp_id"] = dfGen_ccs[(dfGen_ccs[!,:COMPRESSOR].==1),:FLECCS_NO][1]
	    #Rich tank
		inputs_ccs["Rich_id"] = dfGen_ccs[(dfGen_ccs[!,:SOLVENT].==1),:FLECCS_NO][1]
	    #lean tank
	    inputs_ccs["Lean_id"] = dfGen_ccs[(dfGen_ccs[!,:SOLVENT].==2),:FLECCS_NO][1]
	    #BOP
	    inputs_ccs["BOP_id"] = dfGen_ccs[(dfGen_ccs[!,:BOP].==1),:FLECCS_NO][1]

	elseif setup["FLECCS"] == 3
		inputs_ccs["NGCT_id"] = dfGen_ccs[(dfGen_ccs[!,:TURBINE].==1),:FLECCS_NO][1]
	    # steam turbine
	    inputs_ccs["NGST_id"] = dfGen_ccs[(dfGen_ccs[!,:TURBINE].==2),:FLECCS_NO][1]
	    # PCC
	    inputs_ccs["PCC_id"] = dfGen_ccs[(dfGen_ccs[!,:PCC].==1),:FLECCS_NO][1]
	    # compressor
	    inputs_ccs["Comp_id"] = dfGen_ccs[(dfGen_ccs[!,:COMPRESSOR].==1),:FLECCS_NO][1]
        #Hot tank
        inputs_ccs["Hot_id"] = dfGen_ccs[(dfGen_ccs[!,:STORAGE].==1),:FLECCS_NO][1]
        #Cold tank
        inputs_ccs["Cold_id"] = dfGen_ccs[(dfGen_ccs[!,:STORAGE].==2),:FLECCS_NO][1]
        # heat pump
        inputs_ccs["HeatPump_id"] = dfGen_ccs[(dfGen_ccs[!,:HEATPUMP].==1),:FLECCS_NO][1]
	    #BOP
	    inputs_ccs["BOP_id"] = dfGen_ccs[(dfGen_ccs[!,:BOP].==1),:FLECCS_NO][1]
	elseif setup["FLECCS"] == 4
		inputs_ccs["NGCT_id"] = dfGen_ccs[(dfGen_ccs[!,:TURBINE].==1),:FLECCS_NO][1]
	    # steam turbine
	    inputs_ccs["NGST_id"] = dfGen_ccs[(dfGen_ccs[!,:TURBINE].==2),:FLECCS_NO][1]
	    # PCC
	    inputs_ccs["PCC_id"] = dfGen_ccs[(dfGen_ccs[!,:PCC].==1),:FLECCS_NO][1]
	    # compressor
	    inputs_ccs["Comp_id"] = dfGen_ccs[(dfGen_ccs[!,:COMPRESSOR].==1),:FLECCS_NO][1]
        #Hot tank
        inputs_ccs["Hot_id"] = dfGen_ccs[(dfGen_ccs[!,:STORAGE].==1),:FLECCS_NO][1]
        #Cold tank
        inputs_ccs["Cold_id"] = dfGen_ccs[(dfGen_ccs[!,:STORAGE].==2),:FLECCS_NO][1]
        # heat pump
        inputs_ccs["HeatPump_id"] = dfGen_ccs[(dfGen_ccs[!,:HEATPUMP].==1),:FLECCS_NO][1]
		 # heater
		inputs_ccs["Heater_id"] = dfGen_ccs[(dfGen_ccs[!,:HEATER].==1),:FLECCS_NO][1]
	    #BOP
	    inputs_ccs["BOP_id"] = dfGen_ccs[(dfGen_ccs[!,:BOP].==1),:FLECCS_NO][1]

	elseif setup["FLECCS"] == 5
		println("FLECCS_data4.csv Successfully Read!, NGCC-CCS coupled with H2 generation and storage")
	elseif setup["FLECCS"] == 6
		println("FLECCS_data5.csv Successfully Read!, NGCC-CCS coupled with DAC (Gtech or Upitt)")
	elseif setup["FLECCS"] == 7
		println("FLECCS_data6.csv Successfully Read!, NGCC-CCS coupled with DAC (MIT)")
	elseif setup["FLECCS"] == 8
		println("FLECCS_data8.csv Successfully Read!, Allam cycle coupled with CO2 storage")
		inputs_ccs["OXY_id"] = dfGen_ccs[(dfGen_ccs[!,:OXY].==1),:FLECCS_NO][1]
	    # steam turbine
	    inputs_ccs["ASU_id"] = dfGen_ccs[(dfGen_ccs[!,:ASU].==1),:FLECCS_NO][1]
	    # PCC
	    inputs_ccs["LOX_id"] = dfGen_ccs[(dfGen_ccs[!,:LOX].==1),:FLECCS_NO][1]
	    # compressor
	    inputs_ccs["BOP_id"] = dfGen_ccs[(dfGen_ccs[!,:BOP].==1),:FLECCS_NO][1]
	end




	return inputs_ccs
end
