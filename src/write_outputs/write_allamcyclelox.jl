
@doc raw"""
	write_capacity(path::AbstractString, inputs::Dict, setup::Dict, EP::Model))

Function for writing the diferent capacities for the FLECCS technologies (starting capacities or, existing capacities, retired capacities, and new-built capacities).
"""
function write_allam_capacity(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	# Capacity decisions
	gen = inputs["RESOURCES"]
	ALLAM_CYCLE_LOX = inputs["ALLAM_CYCLE_LOX"] 
    COMMIT_Allam = setup["UCommit"] > 1 ? ALLAM_CYCLE_LOX : Int[]
	MultiStage = setup["MultiStage"]

    # Allam cycle components
    # by default, i = 1 -> sCO2Turbine; i = 2 -> ASU; i = 3 -> LOX
    sco2turbine, asu, lox = 1, 2, 3
    # get component-wise data
    allam_dict = inputs["allam_dict"]

	capAllam_sco2turbine = zeros(size(inputs["RESOURCE_NAMES"]))
	capAllam_asu = zeros(size(inputs["RESOURCE_NAMES"]))
	capAllam_lox = zeros(size(inputs["RESOURCE_NAMES"]))

	# new cap
	for y in ALLAM_CYCLE_LOX
		if y in COMMIT_Allam
			capAllam_sco2turbine[y] = value.(EP[:vCAP_AllamCycleLOX])[y, sco2turbine]* allam_dict[y,"cap_size"][sco2turbine]
			capAllam_asu[y] = value.(EP[:vCAP_AllamCycleLOX])[y, asu]* allam_dict[y,"cap_size"][asu]
			capAllam_lox[y] = value.(EP[:vCAP_AllamCycleLOX])[y, lox]* allam_dict[y,"cap_size"][lox]
		else
			capAllam_sco2turbine[y] = value.(EP[:vCAP_AllamCycleLOX])[y, sco2turbine]
			capAllam_asu[y] = value.(EP[:vCAP_AllamCycleLOX])[y, asu]
			capAllam_lox[y] = value.(EP[:vCAP_AllamCycleLOX])[y, lox]
		end
	end

	# retired cap
	retcapAllam_sco2turbine = zeros(size(inputs["RESOURCE_NAMES"]))
	retcapAllam_asu = zeros(size(inputs["RESOURCE_NAMES"]))
	retcapAllam_lox = zeros(size(inputs["RESOURCE_NAMES"]))

	for y in ALLAM_CYCLE_LOX
		if y in COMMIT_Allam
			retcapAllam_sco2turbine[y] = value.(EP[:vRET_AllamCycleLOX])[y, sco2turbine]* allam_dict[y,"cap_size"][sco2turbine]
			retcapAllam_asu[y] = value.(EP[:vRET_AllamCycleLOX])[y, asu]* allam_dict[y,"cap_size"][asu]
			retcapAllam_lox[y] = value.(EP[:vRET_AllamCycleLOX])[y, lox]* allam_dict[y,"cap_size"][lox]
		else
			retcapAllam_sco2turbine[y] = value.(EP[:vRET_AllamCycleLOX])[y, sco2turbine]
			retcapAllam_asu[y] = value.(EP[:vRET_AllamCycleLOX])[y, asu]
			retcapAllam_lox[y] = value.(EP[:vRET_AllamCycleLOX])[y, lox]
		end
	end


	dfCapAllam = DataFrame(Resource = gen.resource[ALLAM_CYCLE_LOX],
		Zone = gen.zone[ALLAM_CYCLE_LOX],
		
		StartCap_sCO2turbine_MW_gross = MultiStage == 1 ? value.(EP[:vEXISTINGCAP_AllamCycleLOX]) : [allam_dict[y, "existing_cap"][sco2turbine] for y in ALLAM_CYCLE_LOX],
		StartCap_ASU_MW_gross = MultiStage == 1 ? value.(EP[:vEXISTINGCAP_AllamCycleLOX]) : [allam_dict[y, "existing_cap"][asu] for y in ALLAM_CYCLE_LOX],
		StartCap_LOX_t = MultiStage == 1 ? value.(EP[:vEXISTINGCAP_AllamCycleLOX]) : [allam_dict[y, "existing_cap"][lox] for y in ALLAM_CYCLE_LOX],
		
		NewCap_sCO2turbine_MW_gross = capAllam_sco2turbine[ALLAM_CYCLE_LOX],
		NewCap_ASU_MW_gross = capAllam_asu[ALLAM_CYCLE_LOX],
		NewCap_LOX_t = capAllam_lox[ALLAM_CYCLE_LOX],

		RetCap_sCO2turbine_MW_gross = retcapAllam_sco2turbine[ALLAM_CYCLE_LOX],
		RetCap_ASU_MW_gross = retcapAllam_asu[ALLAM_CYCLE_LOX],
		RetCap_LOX_t = retcapAllam_lox[ALLAM_CYCLE_LOX],

		EndCap_sCO2turbine_MW_gross = [value.(EP[:eTotalCap_AllamcycleLOX])[y,sco2turbine] for y in ALLAM_CYCLE_LOX],
		EndCap_ASU_MW_gross = [value.(EP[:eTotalCap_AllamcycleLOX])[y,asu] for y in ALLAM_CYCLE_LOX],
		EndCap_LOX_t = [value.(EP[:eTotalCap_AllamcycleLOX])[y,lox] for y in ALLAM_CYCLE_LOX]
	)


	if setup["ParameterScale"] ==1
		dfCapAllam.StartCap_sCO2turbine_MW_gross = dfCapAllam.StartCap_sCO2turbine_MW_gross* ModelScalingFactor
		dfCapAllam.RetCap_sCO2turbine_MW_gross = dfCapAllam.RetCap_sCO2turbine_MW_gross * ModelScalingFactor
		dfCapAllam.NewCap_sCO2turbine_MW_gross = dfCapAllam.NewCap_sCO2turbine_MW_gross * ModelScalingFactor
		dfCapAllam.EndCap_sCO2turbine_MW_gross = dfCapAllam.EndCap_sCO2turbine_MW_gross * ModelScalingFactor

		dfCapAllam.StartCap_ASU_MW_gross = dfCapAllam.StartCap_ASU_MW_gross* ModelScalingFactor
		dfCapAllam.RetCap_ASU_MW_gross = dfCapAllam.RetCap_ASU_MW_gross * ModelScalingFactor
		dfCapAllam.NewCap_ASU_MW_gross = dfCapAllam.NewCap_ASU_MW_gross * ModelScalingFactor
		dfCapAllam.EndCap_ASU_MW_gross = dfCapAllam.EndCap_ASU_MW_gross * ModelScalingFactor

		dfCapAllam.StartCap_LOX_t = dfCapAllam.StartCap_LOX_t * ModelScalingFactor
		dfCapAllam.RetCap_LOX_t = dfCapAllam.RetCap_LOX_t * ModelScalingFactor
		dfCapAllam.NewCap_LOX_t = dfCapAllam.NewCap_LOX_t * ModelScalingFactor
		dfCapAllam.EndCap_LOX_t = dfCapAllam.EndCap_LOX_t * ModelScalingFactor
	end

	total_allam = DataFrame(
			Resource = "Total", Zone = "n/a", 
			StartCap_sCO2turbine_MW_gross = sum(dfCapAllam[!,:StartCap_sCO2turbine_MW_gross]), 
			RetCap_sCO2turbine_MW_gross = sum(dfCapAllam[!,:RetCap_sCO2turbine_MW_gross]),
			NewCap_sCO2turbine_MW_gross = sum(dfCapAllam[!,:NewCap_sCO2turbine_MW_gross]), 
			EndCap_sCO2turbine_MW_gross = sum(dfCapAllam[!,:EndCap_sCO2turbine_MW_gross]),

			StartCap_ASU_MW_gross = sum(dfCapAllam[!,:StartCap_ASU_MW_gross]), 
			RetCap_ASU_MW_gross = sum(dfCapAllam[!,:RetCap_ASU_MW_gross]),
			NewCap_ASU_MW_gross = sum(dfCapAllam[!,:NewCap_ASU_MW_gross]), 
			EndCap_ASU_MW_gross = sum(dfCapAllam[!,:EndCap_ASU_MW_gross]),

			StartCap_LOX_t = sum(dfCapAllam[!,:StartCap_LOX_t]), 
			RetCap_LOX_t = sum(dfCapAllam[!,:RetCap_LOX_t]),
			NewCap_LOX_t = sum(dfCapAllam[!,:NewCap_LOX_t]), 
			EndCap_LOX_t = sum(dfCapAllam[!,:EndCap_LOX_t]),
		)

	dfCapAllam = vcat(dfCapAllam, total_allam)
	CSV.write(joinpath(path,"capacity_allam_cycle_lox.csv"), dfCapAllam)

	# also write the vOutput_AllamcycleLOX, vLOX_in, vLOX_out
	
	
end




function write_allam_output(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	ALLAM_CYCLE_LOX = inputs["ALLAM_CYCLE_LOX"] 
    # Allam cycle components
    # by default, i = 1 -> sCO2Turbine; i = 2 -> ASU; i = 3 -> LOX
    sco2turbine, asu, lox = 1, 2, 3

    # Power injected by each resource in each time step
    dfAllam_output = DataFrame(Resource = 
		[inputs["RESOURCE_NAMES"][ALLAM_CYCLE_LOX] .*"_sco2turbine_gross_power_mw";
		inputs["RESOURCE_NAMES"][ALLAM_CYCLE_LOX] .*"_asu_gross_power_mw";
		inputs["RESOURCE_NAMES"][ALLAM_CYCLE_LOX] .*"_net_power_output_mw";
		inputs["RESOURCE_NAMES"][ALLAM_CYCLE_LOX] .*"_storage_lox_t";
		inputs["RESOURCE_NAMES"][ALLAM_CYCLE_LOX] .*"_lox_in_t";
		inputs["RESOURCE_NAMES"][ALLAM_CYCLE_LOX] .*"_lox_out_t";
		inputs["RESOURCE_NAMES"][ALLAM_CYCLE_LOX] .*"_gox_t"])

	gross_power_sco2turbine = value.(EP[:vOutput_AllamcycleLOX])[:,sco2turbine,:]
	gross_power_asu = value.(EP[:vOutput_AllamcycleLOX])[:,asu,:]
	net_power_out = value.(EP[:vP_Allam])[:,:]
	lox_storage = value.(EP[:vOutput_AllamcycleLOX])[:,lox,:]
	lox_in = value.(EP[:vLOX_in])
	lox_out = value.(EP[:eLOX_out])
	gox = value.(EP[:vGOX])


    if setup["ParameterScale"] == 1
        gross_power_sco2turbine *= ModelScalingFactor
		gross_power_asu *= ModelScalingFactor
		net_power_out *= ModelScalingFactor
		lox_storage *= ModelScalingFactor
		lox_in *= ModelScalingFactor
		lox_out *= ModelScalingFactor
		gox *= ModelScalingFactor
    end

	allamoutput = [Array(gross_power_sco2turbine);
	Array(gross_power_asu);
	Array(net_power_out);
	Array(lox_storage);
	Array(lox_in);
	Array(lox_out);
	Array(gox)]

	final_allam = permutedims(DataFrame(hcat(Array(dfAllam_output), allamoutput), :auto))
    CSV.write(joinpath(path,"output_allam_cycle_lox.csv"), final_allam, writeheader = false)
end
