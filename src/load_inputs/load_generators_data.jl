@doc raw"""
	load_generators_data!(setup::Dict, path::AbstractString, inputs_gen::Dict, fuel_costs::Dict, fuel_CO2::Dict)

Function for reading input parameters related to electricity generators (plus storage and flexible demand resources)
"""
function load_generators_data!(setup::Dict, path::AbstractString, inputs_gen::Dict, fuel_costs::Dict, fuel_CO2::Dict)

    filename = "Generators_data.csv"
    gen_in = load_dataframe(joinpath(path, filename))


    # Store DataFrame of generators/resources input data for use in model
    inputs_gen["dfGen"] = gen_in

    # initial screen that resources are valid
    resources = dataframerow_to_dict.(eachrow(gen_in))
    validate_resources(resources)
    inputs_gen["resources_d"] = resources

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

	# Set of hydrogen electolyzer resources (optional set):
	if "ELECTROLYZER" in names(gen_in)
		inputs_gen["ELECTROLYZER"] = gen_in[gen_in.ELECTROLYZER.>=1,:R_ID]
	else
		inputs_gen["ELECTROLYZER"] = Vector()
	end

	# Set of retrofit resources (optional set)
	if !("RETRO" in names(gen_in))
		gen_in[!, "RETRO"] = zero(gen_in[!, "R_ID"])
	end
		
	inputs_gen["RETRO"] = gen_in[gen_in.RETRO.==1,:R_ID]
    # Disable Retrofit while it's under development
    if !(isempty(inputs_gen["RETRO"]))
        error("The Retrofits feature, which is activated by nonzero data in a 'RETRO' column in Generators_data.csv, is under development and is not ready for public use. Disable this message to enable this *experimental* feature.")
    end

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

					   :Hydrogen_MWh_Per_Tonne,	   	   # to GWh/t
                      ]

    for column in columns_to_scale
        if string(column) in names(gen_in)
            gen_in[!, column] /= scale_factor
        end
    end

	if setup["UCommit"] >= 1
		start_cost = convert(Array{Float64}, gen_in[!,:Start_Cost_per_MW])
		inputs_gen["C_Start"] = zeros(Float64, G, inputs_gen["T"])
	end

	# scale the start costs 
	for g in 1:G
		if g in inputs_gen["COMMIT"]
			# Start-up cost is sum of fixed cost per start startup.
			inputs_gen["C_Start"][g,:] .= gen_in[g,:Cap_Size] * ( start_cost[g])
		end
	end

	load_vre_stor_data!(inputs_gen, setup, path)

	
	# write zeros if col names are not in the gen_in dataframe
	required_cols_for_co2 = ["Biomass", "CO2_Capture_Fraction", "CO2_Capture_Fraction_Startup", "CCS_Disposal_Cost_per_Metric_Ton"]
	for col in required_cols_for_co2
		ensure_column!(gen_in, col, 0)
	end
	
	# Scale CCS_Disposal_Cost_per_Metric_Ton for CCS units 
	gen_in.CCS_Disposal_Cost_per_Metric_Ton /= scale_factor

	# get R_ID when fuel is not None
	inputs_gen["HAS_FUEL"] = gen_in[(gen_in[!,:Fuel] .!= "None"),:R_ID]

	# Piecewise fuel usage option
	if setup["UCommit"] > 0
		process_piecewisefuelusage!(inputs_gen, scale_factor)
	end

	println(filename * " Successfully Read!")
end


@doc raw"""
	check_vre_stor_validity(df::DataFrame, setup::Dict)

Function for checking that no other technology flags have been activated and specific data inputs
	have been zeroed for the co-located VRE-STOR module
"""
function check_vre_stor_validity(df::DataFrame, setup::Dict)
	# Determine if any VRE-STOR resources exist
	vre_stor = is_nonzero(df, :VRE_STOR)
	r_id = df[:, :R_ID]

	error_strings = String[]

	function error_feedback(data::Vector{Int}, col::Symbol)::String
		string("Generators ", data, ", marked as VRE-STOR, have ", col, " ≠ 0. ", col, " must be 0.")
	end

	function check_any_nonzero_with_vre_stor!(error_strings::Vector{String}, df::DataFrame, col::Symbol)
		check = vre_stor .& is_nonzero(df, col)
		if any(check)
			e = error_feedback(r_id[check], col)
			push!(error_strings, e)
		end
	end

	# Confirm that any other flags/inputs are not activated (all other flags should be activated in the vre_stor_data.csv)
	check_any_nonzero_with_vre_stor!(error_strings, df, :Var_OM_Cost_per_MWh_In)
	if setup["EnergyShareRequirement"]==1
		nESR = count(occursin.("ESR_", names(df)))
		for i in 1:nESR
			check_any_nonzero_with_vre_stor!(error_strings, df, Symbol(string("ESR_",i)))
		end
	end
	if setup["CapacityReserveMargin"]==1
		nCapRes = count(occursin.("CapRes_", names(df)))
		for i in 1:nCapRes
			check_any_nonzero_with_vre_stor!(error_strings, df, Symbol(string("CapRes_",i)))
		end
	end

	return error_strings
end

@doc raw"""
	summarize_errors(error_strings::Vector{String})

Function for printing out to user how many errors there were in the configuration of the generators data
"""
function summarize_errors(error_strings::Vector{String})
	if !isempty(error_strings)
		println(length(error_strings), " problem(s) in the configuration of the generators:")
		for es in error_strings
			println(es)
		end
		error("There were errors in the configuration of the generators.")
	end
end

@doc raw"""
    split_storage_resources!(df::DataFrame, inputs::Dict, setup::Dict)

For co-located VRE-storage resources, this function returns the storage type 
	(1. long-duration or short-duration storage, 2. symmetric or asymmetric storage)
    for charging and discharging capacities
"""
function split_storage_resources!(df::DataFrame, inputs::Dict, setup::Dict)

	# All Storage Resources
	inputs["VS_STOR"] = union(df[df.STOR_DC_CHARGE.>=1,:R_ID], df[df.STOR_AC_CHARGE.>=1,:R_ID], 
		df[df.STOR_DC_DISCHARGE.>=1,:R_ID], df[df.STOR_AC_DISCHARGE.>=1,:R_ID])
	STOR = inputs["VS_STOR"]

	# Storage DC Discharge Resources
	inputs["VS_STOR_DC_DISCHARGE"] = df[(df.STOR_DC_DISCHARGE.>=1),:R_ID]
	inputs["VS_SYM_DC_DISCHARGE"] = df[df.STOR_DC_DISCHARGE.==1,:R_ID]
	inputs["VS_ASYM_DC_DISCHARGE"] = df[df.STOR_DC_DISCHARGE.==2,:R_ID]

	# Storage DC Charge Resources
	inputs["VS_STOR_DC_CHARGE"] = df[(df.STOR_DC_CHARGE.>=1),:R_ID]
	inputs["VS_SYM_DC_CHARGE"] = df[df.STOR_DC_CHARGE.==1,:R_ID]
    inputs["VS_ASYM_DC_CHARGE"] = df[df.STOR_DC_CHARGE.==2,:R_ID]

	# Storage AC Discharge Resources
	inputs["VS_STOR_AC_DISCHARGE"] = df[(df.STOR_AC_DISCHARGE.>=1),:R_ID]
	inputs["VS_SYM_AC_DISCHARGE"] = df[df.STOR_AC_DISCHARGE.==1,:R_ID]
	inputs["VS_ASYM_AC_DISCHARGE"] = df[df.STOR_AC_DISCHARGE.==2,:R_ID]

	# Storage AC Charge Resources
	inputs["VS_STOR_AC_CHARGE"] = df[(df.STOR_AC_CHARGE.>=1),:R_ID]
	inputs["VS_SYM_AC_CHARGE"] = df[df.STOR_AC_CHARGE.==1,:R_ID]
	inputs["VS_ASYM_AC_CHARGE"] = df[df.STOR_AC_CHARGE.==2,:R_ID]

	# Storage LDS & Non-LDS Resources
	inputs["VS_LDS"] = df[(df.LDS_VRE_STOR.!=0),:R_ID]
	inputs["VS_nonLDS"] = setdiff(STOR, inputs["VS_LDS"])

    # Symmetric and asymmetric storage resources
	inputs["VS_ASYM"] = union(inputs["VS_ASYM_DC_CHARGE"], inputs["VS_ASYM_DC_DISCHARGE"], 
		inputs["VS_ASYM_AC_DISCHARGE"], inputs["VS_ASYM_AC_CHARGE"])
	inputs["VS_SYM_DC"] = intersect(inputs["VS_SYM_DC_CHARGE"], inputs["VS_SYM_DC_DISCHARGE"])
    inputs["VS_SYM_AC"] = intersect(inputs["VS_SYM_AC_CHARGE"], inputs["VS_SYM_AC_DISCHARGE"])

    # Send warnings for symmetric/asymmetric resources
    if (!isempty(setdiff(inputs["VS_SYM_DC_DISCHARGE"], inputs["VS_SYM_DC_CHARGE"])) 
		|| !isempty(setdiff(inputs["VS_SYM_DC_CHARGE"], inputs["VS_SYM_DC_DISCHARGE"])) 
		|| !isempty(setdiff(inputs["VS_SYM_AC_DISCHARGE"], inputs["VS_SYM_AC_CHARGE"])) 
		|| !isempty(setdiff(inputs["VS_SYM_AC_CHARGE"], inputs["VS_SYM_AC_DISCHARGE"])))
        @warn("Symmetric capacities must both be DC or AC.")
    end

	# Send warnings for battery resources discharging
	if !isempty(intersect(inputs["VS_STOR_DC_DISCHARGE"], inputs["VS_STOR_AC_DISCHARGE"]))
		@warn("Both AC and DC discharging functionalities are turned on.")
	end

	# Send warnings for battery resources charging
	if !isempty(intersect(inputs["VS_STOR_DC_CHARGE"], inputs["VS_STOR_AC_CHARGE"]))
		@warn("Both AC and DC charging functionalities are turned on.")
	end
end

@doc raw"""
	load_vre_stor_data!(inputs_gen::Dict, setup::Dict, path::AbstractString)

Function for reading input parameters related to co-located VRE-storage resources
"""
function load_vre_stor_data!(inputs_gen::Dict, setup::Dict, path::AbstractString)
	
	error_strings = String[]
	dfGen = inputs_gen["dfGen"]
	inputs_gen["VRE_STOR"] = "VRE_STOR" in names(dfGen) ? dfGen[dfGen.VRE_STOR.==1,:R_ID] : Int[]

	# Check if VRE-STOR resources exist
	if !isempty(inputs_gen["VRE_STOR"])

		# Check input data format
		vre_stor_errors = check_vre_stor_validity(dfGen, setup)
		append!(error_strings, vre_stor_errors)

		vre_stor_in = DataFrame(CSV.File(joinpath(path,"Vre_and_stor_data.csv"), header=true), copycols=true)

		## Defining all sets

		# New build and retirement resources
		new_build_resources = dfGen[dfGen.New_Build.==1,:R_ID]
		retirement_resources = dfGen[dfGen.New_Build.!=-1,:R_ID]

		# Solar PV Resources
		inputs_gen["VS_SOLAR"] = vre_stor_in[(vre_stor_in.SOLAR.!=0),:R_ID]

		# DC Resources
		inputs_gen["VS_DC"] = union(vre_stor_in[vre_stor_in.STOR_DC_DISCHARGE.>=1,:R_ID], vre_stor_in[vre_stor_in.STOR_DC_CHARGE.>=1,:R_ID], vre_stor_in[vre_stor_in.SOLAR.!=0,:R_ID])

		# Wind Resources
		inputs_gen["VS_WIND"] = vre_stor_in[(vre_stor_in.WIND.!=0),:R_ID]

		# Storage Resources
		split_storage_resources!(vre_stor_in, inputs_gen, setup)

		# Set of all VRE-STOR resources eligible for new solar capacity
		inputs_gen["NEW_CAP_SOLAR"] = intersect(new_build_resources, vre_stor_in[vre_stor_in.SOLAR.!=0,:R_ID], vre_stor_in[vre_stor_in.Max_Cap_Solar_MW.!=0,:R_ID])
		# Set of all VRE_STOR resources eligible for solar capacity retirements
		inputs_gen["RET_CAP_SOLAR"] = intersect(retirement_resources,  vre_stor_in[vre_stor_in.SOLAR.!=0,:R_ID], vre_stor_in[vre_stor_in.Existing_Cap_Solar_MW.>=0,:R_ID])
		# Set of all VRE-STOR resources eligible for new wind capacity
		inputs_gen["NEW_CAP_WIND"] = intersect(new_build_resources, vre_stor_in[vre_stor_in.WIND.!=0,:R_ID], vre_stor_in[vre_stor_in.Max_Cap_Wind_MW.!=0,:R_ID])
		# Set of all VRE_STOR resources eligible for wind capacity retirements
		inputs_gen["RET_CAP_WIND"] = intersect(retirement_resources, vre_stor_in[vre_stor_in.WIND.!=0,:R_ID], vre_stor_in[vre_stor_in.Existing_Cap_Wind_MW.>=0,:R_ID])
		# Set of all VRE-STOR resources eligible for new inverter capacity
		inputs_gen["NEW_CAP_DC"] = intersect(new_build_resources, vre_stor_in[vre_stor_in.Max_Cap_Inverter_MW.!=0,:R_ID], inputs_gen["VS_DC"])
		# Set of all VRE_STOR resources eligible for inverter capacity retirements
		inputs_gen["RET_CAP_DC"] = intersect(retirement_resources, vre_stor_in[vre_stor_in.Existing_Cap_Inverter_MW.>=0,:R_ID], inputs_gen["VS_DC"])
		# Set of all storage resources eligible for new energy capacity
		inputs_gen["NEW_CAP_STOR"] = intersect(new_build_resources, dfGen[dfGen.Max_Cap_MWh.!=0,:R_ID], inputs_gen["VS_STOR"])
		# Set of all storage resources eligible for energy capacity retirements
		inputs_gen["RET_CAP_STOR"] = intersect(retirement_resources, dfGen[dfGen.Existing_Cap_MWh.>=0,:R_ID], inputs_gen["VS_STOR"])
		if !isempty(inputs_gen["VS_ASYM"])
			# Set of asymmetric charge DC storage resources eligible for new charge capacity
			inputs_gen["NEW_CAP_CHARGE_DC"] = intersect(new_build_resources, vre_stor_in[vre_stor_in.Max_Cap_Charge_DC_MW.!=0,:R_ID], inputs_gen["VS_ASYM_DC_CHARGE"]) 
			# Set of asymmetric charge DC storage resources eligible for charge capacity retirements
			inputs_gen["RET_CAP_CHARGE_DC"] = intersect(retirement_resources, vre_stor_in[vre_stor_in.Existing_Cap_Charge_DC_MW.>=0,:R_ID], inputs_gen["VS_ASYM_DC_CHARGE"])
			# Set of asymmetric discharge DC storage resources eligible for new discharge capacity
			inputs_gen["NEW_CAP_DISCHARGE_DC"] = intersect(new_build_resources, vre_stor_in[vre_stor_in.Max_Cap_Discharge_DC_MW.!=0,:R_ID], inputs_gen["VS_ASYM_DC_DISCHARGE"]) 
			# Set of asymmetric discharge DC storage resources eligible for discharge capacity retirements
			inputs_gen["RET_CAP_DISCHARGE_DC"] = intersect(retirement_resources, vre_stor_in[vre_stor_in.Existing_Cap_Discharge_DC_MW.>=0,:R_ID], inputs_gen["VS_ASYM_DC_DISCHARGE"]) 
			# Set of asymmetric charge AC storage resources eligible for new charge capacity
			inputs_gen["NEW_CAP_CHARGE_AC"] = intersect(new_build_resources, vre_stor_in[vre_stor_in.Max_Cap_Charge_AC_MW.!=0,:R_ID], inputs_gen["VS_ASYM_AC_CHARGE"]) 
			# Set of asymmetric charge AC storage resources eligible for charge capacity retirements
			inputs_gen["RET_CAP_CHARGE_AC"] = intersect(retirement_resources, vre_stor_in[vre_stor_in.Existing_Cap_Charge_AC_MW.>=0,:R_ID], inputs_gen["VS_ASYM_AC_CHARGE"]) 
			# Set of asymmetric discharge AC storage resources eligible for new discharge capacity
			inputs_gen["NEW_CAP_DISCHARGE_AC"] = intersect(new_build_resources, vre_stor_in[vre_stor_in.Max_Cap_Discharge_AC_MW.!=0,:R_ID], inputs_gen["VS_ASYM_AC_DISCHARGE"]) 
			# Set of asymmetric discharge AC storage resources eligible for discharge capacity retirements
			inputs_gen["RET_CAP_DISCHARGE_AC"] = intersect(retirement_resources, vre_stor_in[vre_stor_in.Existing_Cap_Discharge_AC_MW.>=0,:R_ID], inputs_gen["VS_ASYM_AC_DISCHARGE"]) 
		end 

		# Names for systemwide resources
		inputs_gen["RESOURCES_VRE_STOR"] = collect(skipmissing(vre_stor_in[!,:Resource][1:size(inputs_gen["VRE_STOR"])[1]]))

		# Names for writing outputs
		inputs_gen["RESOURCES_SOLAR"] = vre_stor_in[(vre_stor_in.SOLAR.!=0), :Resource]
		inputs_gen["RESOURCES_WIND"] = vre_stor_in[(vre_stor_in.WIND.!=0), :Resource]
		inputs_gen["RESOURCES_DC_DISCHARGE"] = vre_stor_in[(vre_stor_in.STOR_DC_DISCHARGE.!=0), :Resource]
		inputs_gen["RESOURCES_AC_DISCHARGE"] = vre_stor_in[(vre_stor_in.STOR_AC_DISCHARGE.!=0), :Resource]
		inputs_gen["RESOURCES_DC_CHARGE"] = vre_stor_in[(vre_stor_in.STOR_DC_CHARGE.!=0), :Resource]
		inputs_gen["RESOURCES_AC_CHARGE"] = vre_stor_in[(vre_stor_in.STOR_AC_CHARGE.!=0), :Resource]
		inputs_gen["ZONES_SOLAR"] = vre_stor_in[(vre_stor_in.SOLAR.!=0), :Zone]
		inputs_gen["ZONES_WIND"] = vre_stor_in[(vre_stor_in.WIND.!=0), :Zone]
		inputs_gen["ZONES_DC_DISCHARGE"] = vre_stor_in[(vre_stor_in.STOR_DC_DISCHARGE.!=0), :Zone]
		inputs_gen["ZONES_AC_DISCHARGE"] = vre_stor_in[(vre_stor_in.STOR_AC_DISCHARGE.!=0), :Zone]
		inputs_gen["ZONES_DC_CHARGE"] = vre_stor_in[(vre_stor_in.STOR_DC_CHARGE.!=0), :Zone]
		inputs_gen["ZONES_AC_CHARGE"] = vre_stor_in[(vre_stor_in.STOR_AC_CHARGE.!=0), :Zone]

		# Scale the parameters as needed
		if setup["ParameterScale"] == 1
			columns_to_scale = [:Existing_Cap_Inverter_MW,
								:Existing_Cap_Solar_MW,
								:Existing_Cap_Wind_MW,
								:Existing_Cap_Charge_DC_MW,
								:Existing_Cap_Charge_AC_MW,
								:Existing_Cap_Discharge_DC_MW,
								:Existing_Cap_Discharge_AC_MW,
								:Min_Cap_Inverter_MW,
								:Max_Cap_Inverter_MW,
								:Min_Cap_Solar_MW,
								:Max_Cap_Solar_MW,
								:Min_Cap_Wind_MW,
								:Max_Cap_Wind_MW,
								:Min_Cap_Charge_AC_MW,
								:Max_Cap_Charge_AC_MW,
								:Min_Cap_Charge_DC_MW,
								:Max_Cap_Charge_DC_MW,
								:Min_Cap_Discharge_AC_MW,
								:Max_Cap_Discharge_AC_MW,
								:Min_Cap_Discharge_DC_MW,
								:Max_Cap_Discharge_DC_MW,
								:Inv_Cost_Inverter_per_MWyr,
								:Fixed_OM_Inverter_Cost_per_MWyr,
								:Inv_Cost_Solar_per_MWyr,
								:Fixed_OM_Solar_Cost_per_MWyr,
								:Inv_Cost_Wind_per_MWyr,
								:Fixed_OM_Wind_Cost_per_MWyr,
								:Inv_Cost_Discharge_DC_per_MWyr,
								:Fixed_OM_Cost_Discharge_DC_per_MWyr,
								:Inv_Cost_Charge_DC_per_MWyr,
								:Fixed_OM_Cost_Charge_DC_per_MWyr,
								:Inv_Cost_Discharge_AC_per_MWyr,
								:Fixed_OM_Cost_Discharge_AC_per_MWyr,
								:Inv_Cost_Charge_AC_per_MWyr,
								:Fixed_OM_Cost_Charge_AC_per_MWyr,
								:Var_OM_Cost_per_MWh_Solar,
								:Var_OM_Cost_per_MWh_Wind,
								:Var_OM_Cost_per_MWh_Charge_DC,
								:Var_OM_Cost_per_MWh_Discharge_DC,
								:Var_OM_Cost_per_MWh_Charge_AC,
								:Var_OM_Cost_per_MWh_Discharge_AC]
			vre_stor_in[!, columns_to_scale] ./= ModelScalingFactor

			# Scale for multistage feature 
			if setup["MultiStage"] == 1
				columns_to_scale_multistage = [:Min_Retired_Cap_Inverter_MW,
											   :Min_Retired_Cap_Solar_MW,
											   :Min_Retired_Cap_Wind_MW,
											   :Min_Retired_Cap_Charge_DC_MW,
											   :Min_Retired_Cap_Charge_AC_MW,
											   :Min_Retired_Cap_Discharge_DC_MW,
											   :Min_Retired_Cap_Discharge_AC_MW]
				vre_stor_in[!, columns_to_scale_multistage] ./= ModelScalingFactor
			end
		end
		inputs_gen["dfVRE_STOR"] = vre_stor_in
		println("Vre_and_stor_data.csv Successfully Read!")
	else
		inputs_gen["dfVRE_STOR"] = DataFrame()
	end
	summarize_errors(error_strings)
end


function process_piecewisefuelusage!(inputs::Dict, scale_factor)
	gen_in = inputs["dfGen"]
	inputs["PWFU_Num_Segments"] = 0
	inputs["THERM_COMMIT_PWFU"] = Int64[]

	if any(occursin.(Ref("PWFU_"), names(gen_in)))
		heat_rate_mat = extract_matrix_from_dataframe(gen_in, "PWFU_Heat_Rate_MMBTU_per_MWh")
		load_point_mat = extract_matrix_from_dataframe(gen_in, "PWFU_Load_Point_MW")
		
		# check data input 
		validate_piecewisefuelusage!(heat_rate_mat, load_point_mat)

        # determine if a generator contains piecewise fuel usage segment based on non-zero heatrate
		gen_in.HAS_PWFU = any(heat_rate_mat .!= 0 , dims = 2)[:]
		num_segments =  size(heat_rate_mat)[2]

		# translate the inital fuel usage, heat rate, and load points into intercept for each segment
		fuel_usage_zero_load = gen_in[!,"PWFU_Fuel_Usage_Zero_Load_MMBTU_per_h"]
		# construct a matrix for intercept
		intercept_mat = zeros(size(heat_rate_mat))
		# PWFU_Fuel_Usage_MMBTU_per_h is always the intercept of the first segment
		intercept_mat[:,1] = fuel_usage_zero_load

		# create a function to compute intercept if we have more than one segment
		function calculate_intercepts(slope, intercept_1, load_point)
			m, n = size(slope)
			# Initialize the intercepts matrix with zeros
			intercepts = zeros(m, n)
			# The first segment's intercepts should be intercept_1 vector
			intercepts[:, 1] = intercept_1
			# Calculate intercepts for the other segments using the load points (i.e., intersection points)
			for j in 1:n-1
				for i in 1:m
					current_slope = slope[i, j+1]
					previous_slope = slope[i, j]
					# If the current slope is 0, then skip the calculation and return 0
					if current_slope == 0
						intercepts[i, j+1] = 0.0
					else
						# y = a*x + b; => b = y - ax
						# Calculate y-coordinate of the intersection
						y = previous_slope * load_point[i, j] + intercepts[i, j]	
						# determine the new intercept
						b = y - current_slope * load_point[i, j]
						intercepts[i, j+1] = b
					end
				end
			end	 
			return intercepts
		end
		
		if num_segments > 1
			# determine the intercept for the rest of segment if num_segments > 1
			intercept_mat = calculate_intercepts(heat_rate_mat, fuel_usage_zero_load, load_point_mat)
		end

		# create a PWFU_data that contain processed intercept and slope (i.e., heat rate)
		intercept_cols = [Symbol("PWFU_Intercept_", i) for i in 1:num_segments]
		intercept_df = DataFrame(intercept_mat, Symbol.(intercept_cols))
		slope_cols = Symbol.(filter(colname -> startswith(string(colname),"PWFU_Heat_Rate_MMBTU_per_MWh"),names(gen_in)))
		slope_df = DataFrame(heat_rate_mat, Symbol.(slope_cols))
		PWFU_data = hcat(slope_df, intercept_df)
		# no need to scale sclope, but intercept should be scaled when parameterscale is on (MMBTU -> billion BTU)
		PWFU_data[!, intercept_cols] ./= scale_factor

		inputs["slope_cols"] = slope_cols
		inputs["intercept_cols"] = intercept_cols
		inputs["PWFU_data"] = PWFU_data
		inputs["PWFU_Num_Segments"] =num_segments
		inputs["THERM_COMMIT_PWFU"] = intersect(gen_in[gen_in.THERM.==1,:R_ID], gen_in[gen_in.HAS_PWFU,:R_ID])
	end
end

function validate_piecewisefuelusage!(heat_rate_mat, load_point_mat)
	# it's possible to construct piecewise fuel consumption with n of heat rate and n-1 of load point. 
	# if a user feed n of heat rate and more than n of load point, throw a error message, and then use 
	# n of heat rate and n-1 load point to construct the piecewise fuel usage fuction  
	if size(heat_rate_mat)[2] < size(load_point_mat)[2]
		@error """ The numbers of heatrate data are less than load points, we found $(size(heat_rate_mat)[2]) of heat rate,
		and $(size(load_point_mat)[2]) of load points. We will just use $(size(heat_rate_mat)[2]) of heat rate, and $(size(heat_rate_mat)[2]-1)
		load point to create piecewise fuel usage
		"""
	end

	# check if values for piecewise fuel consumption make sense. Negative heat rate or load point are not allowed
	if any(heat_rate_mat .< 0) | any(load_point_mat .< 0)
		@error """ Neither heat rate nor load point can be negative
		"""
		error("Invalid inputs detected for piecewise fuel usage")
	end
	# for non-zero values, heat rates and load points should follow an increasing trend 
	if any([any(diff(filter(!=(0), row)) .< 0) for row in eachrow(heat_rate_mat)]) 
		@error """ Heat rates should follow an increasing trend
		"""
		error("Invalid inputs detected for piecewise fuel usage")
	elseif  any([any(diff(filter(!=(0), row)) .< 0) for row in eachrow(load_point_mat)])
		@error """load points should follow an increasing trend
		"""
		error("Invalid inputs detected for piecewise fuel usage")
	end
end