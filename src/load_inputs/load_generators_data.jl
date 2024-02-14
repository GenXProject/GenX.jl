@doc raw"""
	load_generators_data!(setup::Dict, path::AbstractString, inputs_gen::Dict, fuel_costs::Dict, fuel_CO2::Dict)

Function for reading input parameters related to electricity generators (plus storage and flexible demand resources)
"""
function load_generators_data!(setup::Dict, path::AbstractString, inputs_gen::Dict, fuel_costs::Dict, fuel_CO2::Dict)

    filename = "Generators_data.csv"
    gen_in = load_dataframe(joinpath(path, filename))

    # Store DataFrame of generators/resources input data for use in model
    inputs_gen["dfGen"] = gen_in

    # Number of resources (generators, storage, DR, and DERs)
    G = nrow(gen_in)
    inputs_gen["G"] = G

    # Add Resource IDs after reading to prevent user errors
    gen_in[!,:R_ID] = 1:G

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
	## Defining sets of generation and storage resources

	# Set of storage resources with symmetric charge/discharge capacity
	inputs_gen["STOR_SYMMETRIC"] = gen_in[gen_in.STOR.==1,:R_ID]
	# Set of storage resources with asymmetric (separte) charge/discharge capacity components
	inputs_gen["STOR_ASYMMETRIC"] = gen_in[gen_in.STOR.==2,:R_ID]
	# Set of all storage resources
	inputs_gen["STOR_ALL"] = union(inputs_gen["STOR_SYMMETRIC"],inputs_gen["STOR_ASYMMETRIC"])

	# Set of storage resources with long duration storage capabilitites
	inputs_gen["STOR_HYDRO_LONG_DURATION"] = gen_in[(gen_in.LDS.==1) .& (gen_in.HYDRO.==1),:R_ID]
	inputs_gen["STOR_HYDRO_SHORT_DURATION"] = gen_in[(gen_in.LDS.==0) .& (gen_in.HYDRO.==1),:R_ID]
	inputs_gen["STOR_LONG_DURATION"] = gen_in[(gen_in.LDS.==1) .& (gen_in.STOR.>=1),:R_ID]
	inputs_gen["STOR_SHORT_DURATION"] = gen_in[(gen_in.LDS.==0) .& (gen_in.STOR.>=1),:R_ID]

	# Set of all reservoir hydro resources
	inputs_gen["HYDRO_RES"] = gen_in[(gen_in[!,:HYDRO].==1),:R_ID]
	# Set of reservoir hydro resources modeled with known reservoir energy capacity
	if !isempty(inputs_gen["HYDRO_RES"])
		inputs_gen["HYDRO_RES_KNOWN_CAP"] = intersect(gen_in[gen_in.Hydro_Energy_to_Power_Ratio.>0,:R_ID], inputs_gen["HYDRO_RES"])
	end

	# Set of flexible demand-side resources
	inputs_gen["FLEX"] = gen_in[gen_in.FLEX.==1,:R_ID]

	# Set of must-run plants - could be behind-the-meter PV, hydro run-of-river, must-run fossil or thermal plants
	inputs_gen["MUST_RUN"] = gen_in[gen_in.MUST_RUN.==1,:R_ID]

	# Set of controllable variable renewable resources
	inputs_gen["VRE"] = gen_in[gen_in.VRE.>=1,:R_ID]

	# Set of retrofit resources
	if !("RETRO" in names(gen_in))
		gen_in[!, "RETRO"] = zero(gen_in[!, "R_ID"])
	end
		
	inputs_gen["RETRO"] = gen_in[gen_in.RETRO.==1,:R_ID]

	# Set of thermal generator resources
	if setup["UCommit"]>=1
		# Set of thermal resources eligible for unit committment
		inputs_gen["THERM_COMMIT"] = gen_in[gen_in.THERM.==1,:R_ID]
		# Set of thermal resources not eligible for unit committment
		inputs_gen["THERM_NO_COMMIT"] = gen_in[gen_in.THERM.==2,:R_ID]
	else # When UCommit == 0, no thermal resources are eligible for unit committment
		inputs_gen["THERM_COMMIT"] = Int64[]
		inputs_gen["THERM_NO_COMMIT"] = union(gen_in[gen_in.THERM.==1,:R_ID], gen_in[gen_in.THERM.==2,:R_ID])
	end
	inputs_gen["THERM_ALL"] = union(inputs_gen["THERM_COMMIT"],inputs_gen["THERM_NO_COMMIT"])

	# For now, the only resources eligible for UC are themal resources
	inputs_gen["COMMIT"] = inputs_gen["THERM_COMMIT"]

	if setup["Reserves"] >= 1
		# Set for resources with regulation reserve requirements
		inputs_gen["REG"] = gen_in[(gen_in[!,:Reg_Max].>0),:R_ID]
		# Set for resources with spinning reserve requirements
		inputs_gen["RSV"] = gen_in[(gen_in[!,:Rsv_Max].>0),:R_ID]
	end

	# Set of all resources eligible for new capacity
	inputs_gen["NEW_CAP"] = intersect(gen_in[gen_in.New_Build.==1,:R_ID], gen_in[gen_in.Max_Cap_MW.!=0,:R_ID])
	# Set of all resources eligible for capacity retirements
	inputs_gen["RET_CAP"] = intersect(gen_in[gen_in.New_Build.!=-1,:R_ID], gen_in[gen_in.Existing_Cap_MW.>=0,:R_ID])

	# Set of all storage resources eligible for new energy capacity
	inputs_gen["NEW_CAP_ENERGY"] = intersect(gen_in[gen_in.New_Build.==1,:R_ID], gen_in[gen_in.Max_Cap_MWh.!=0,:R_ID], inputs_gen["STOR_ALL"])
	# Set of all storage resources eligible for energy capacity retirements
	inputs_gen["RET_CAP_ENERGY"] = intersect(gen_in[gen_in.New_Build.!=-1,:R_ID], gen_in[gen_in.Existing_Cap_MWh.>=0,:R_ID], inputs_gen["STOR_ALL"])

	# Set of asymmetric charge/discharge storage resources eligible for new charge capacity
	inputs_gen["NEW_CAP_CHARGE"] = intersect(gen_in[gen_in.New_Build.==1,:R_ID], gen_in[gen_in.Max_Charge_Cap_MW.!=0,:R_ID], inputs_gen["STOR_ASYMMETRIC"])
	# Set of asymmetric charge/discharge storage resources eligible for charge capacity retirements
	inputs_gen["RET_CAP_CHARGE"] = intersect(gen_in[gen_in.New_Build.!=-1,:R_ID], gen_in[gen_in.Existing_Charge_Cap_MW.>=0,:R_ID], inputs_gen["STOR_ASYMMETRIC"])

	# Names of resources
	inputs_gen["RESOURCES"] = gen_in[!,:Resource]
	# Zones resources are located in
	zones = gen_in[!,:Zone]
	# Resource identifiers by zone (just zones in resource order + resource and zone concatenated)
	inputs_gen["R_ZONES"] = zones
	inputs_gen["RESOURCE_ZONES"] = inputs_gen["RESOURCES"] .* "_z" .* string.(zones)

	# Retrofit Information
	if !isempty(inputs_gen["RETRO"]) # If there are any retrofit technologies in consideration, read relevant data
		inputs_gen["NUM_RETROFIT_SOURCES"] = gen_in[!,:Num_RETRO_Sources]   # Number of retrofit sources for this technology (0 if not a retrofit technology)
		max_retro_sources = maximum(inputs_gen["NUM_RETROFIT_SOURCES"])

		source_cols = [ Symbol(string("Retro",i,"_Source")) for i in 1:max_retro_sources ]
		efficiency_cols = [ Symbol(string("Retro",i,"_Efficiency")) for i in 1:max_retro_sources ]
		inv_cap_cols = [ Symbol(string("Retro",i,"_Inv_Cost_per_MWyr")) for i in 1:max_retro_sources ]

		sources = [ gen_in[!,c] for c in source_cols ]
		inputs_gen["RETROFIT_SOURCES"] = [ [ sources[i][y] for i in 1:max_retro_sources if sources[i][y] != "None" ] for y in 1:G ]  # The origin technologies that can be retrofitted into this new technology
		inputs_gen["RETROFIT_SOURCE_IDS"] = [ [ findall(x->x==sources[i][y],inputs_gen["RESOURCES"])[1] for i in 1:max_retro_sources if sources[i][y] != "None" ] for y in 1:G ] # The R_IDs of these origin technologies

		efficiencies = [ gen_in[!,c] for c in efficiency_cols ]
		inputs_gen["RETROFIT_EFFICIENCIES"] = [ [ efficiencies[i][y] for i in 1:max_retro_sources if efficiencies[i][y] != 0 ] for y in 1:G ]  # The efficiencies of each retrofit by source (ratio of outgoing to incoming nameplate capacity)
		inv_cap = [ gen_in[!,c] for c in inv_cap_cols ]
		inv_cap /= scale_factor

		inputs_gen["RETROFIT_INV_CAP_COSTS"] = [ [ inv_cap[i][y] for i in 1:max_retro_sources if inv_cap[i][y] >= 0 ] for y in 1:G ]  # The set of investment costs (capacity $/MWyr) of each retrofit by source
	end

    # See documentation for descriptions of each column
    # Generally, these scalings converts energy and power units from MW to GW
    # and $/MW to $M/GW. Both are done by dividing the values by 1000.
    columns_to_scale = [:Existing_Charge_Cap_MW,       # to GW
                       :Existing_Cap_MWh,              # to GWh
                       :Existing_Cap_MW,               # to GW

                       :Cap_Size,                      # to GW

                       :Min_Cap_MW,                    # to GW
                       :Min_Cap_MWh,                   # to GWh
                       :Min_Charge_Cap_MW,             # to GWh

                       :Max_Cap_MW,                    # to GW
                       :Max_Cap_MWh,                   # to GWh
                       :Max_Charge_Cap_MW,             # to GW

                       :Inv_Cost_per_MWyr,             # to $M/GW/yr
                       :Inv_Cost_per_MWhyr,            # to $M/GWh/yr
                       :Inv_Cost_Charge_per_MWyr,      # to $M/GW/yr

                       :Fixed_OM_Cost_per_MWyr,        # to $M/GW/yr
                       :Fixed_OM_Cost_per_MWhyr,       # to $M/GWh/yr
                       :Fixed_OM_Cost_Charge_per_MWyr, # to $M/GW/yr

                       :Var_OM_Cost_per_MWh,           # to $M/GWh
                       :Var_OM_Cost_per_MWh_In,        # to $M/GWh

                       :Reg_Cost,                      # to $M/GW
                       :Rsv_Cost,                      # to $M/GW

                       :Min_Retired_Cap_MW,            # to GW
                       :Min_Retired_Charge_Cap_MW,     # to GW
                       :Min_Retired_Energy_Cap_MW,     # to GW

                       :Start_Cost_per_MW,             # to $M/GW
                      ]

    for column in columns_to_scale
        if string(column) in names(gen_in)
            gen_in[!, column] /= scale_factor
        end
    end

# Dharik - Done, we have scaled fuel costs above so any parameters on per MMBtu do not need to be scaled
	if setup["UCommit"]>=1
		# Fuel consumed on start-up (million BTUs per MW per start) if unit commitment is modelled
		start_fuel = convert(Array{Float64}, gen_in[!,:Start_Fuel_MMBTU_per_MW])
		# Fixed cost per start-up ($ per MW per start) if unit commitment is modelled
		start_cost = convert(Array{Float64}, gen_in[!,:Start_Cost_per_MW])
		inputs_gen["C_Start"] = zeros(Float64, G, inputs_gen["T"])
		gen_in[!,:CO2_per_Start] = zeros(Float64, G)
	end

	# Heat rate of all resources (million BTUs/MWh)
	heat_rate = convert(Array{Float64}, gen_in[!,:Heat_Rate_MMBTU_per_MWh])
	# Fuel used by each resource
	fuel_type = gen_in[!,:Fuel]
	# Maximum fuel cost in $ per MWh and CO2 emissions in tons per MWh
	inputs_gen["C_Fuel_per_MWh"] = zeros(Float64, G, inputs_gen["T"])
	gen_in[!,:CO2_per_MWh] = zeros(Float64, G)
	for g in 1:G
		# NOTE: When Setup[ParameterScale] =1, fuel costs are scaled in fuels_data.csv, so no if condition needed to scale C_Fuel_per_MWh
		inputs_gen["C_Fuel_per_MWh"][g,:] = fuel_costs[fuel_type[g]].*heat_rate[g]
		gen_in[g,:CO2_per_MWh] = fuel_CO2[fuel_type[g]]*heat_rate[g]
		gen_in[g,:CO2_per_MWh] *= scale_factor
		# kton/MMBTU * MMBTU/MWh = kton/MWh, to get kton/GWh, we need to mutiply 1000
		if g in inputs_gen["COMMIT"]
			# Start-up cost is sum of fixed cost per start plus cost of fuel consumed on startup.
			# CO2 from fuel consumption during startup also calculated

			inputs_gen["C_Start"][g,:] = gen_in[g,:Cap_Size] * (fuel_costs[fuel_type[g]] .* start_fuel[g] .+ start_cost[g])
			# No need to re-scale C_Start since Cap_size, fuel_costs and start_cost are scaled When Setup[ParameterScale] =1 - Dharik
			gen_in[g,:CO2_per_Start]  = gen_in[g,:Cap_Size]*(fuel_CO2[fuel_type[g]]*start_fuel[g])
			gen_in[g,:CO2_per_Start] *= scale_factor
			# Setup[ParameterScale] =1, gen_in[g,:Cap_Size] is GW, fuel_CO2[fuel_type[g]] is ktons/MMBTU, start_fuel is MMBTU/MW,
			#   thus the overall is MTons/GW, and thus gen_in[g,:CO2_per_Start] is Mton, to get kton, change we need to multiply 1000
			# Setup[ParameterScale] =0, gen_in[g,:Cap_Size] is MW, fuel_CO2[fuel_type[g]] is tons/MMBTU, start_fuel is MMBTU/MW,
			#   thus the overall is MTons/GW, and thus gen_in[g,:CO2_per_Start] is ton
		end
	end
	println(filename * " Successfully Read!")
end
