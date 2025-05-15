@doc raw"""
	write_utes_capacity(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

This function writes the different capacities for the Allam Cycle LOX technologies (starting capacities or, existing capacities, retired capacities, and new-built capacities) to the `capacity_allam_cycle_lox.csv` file.
"""
function write_capacity_utes(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	# Capacity decisions
	gen = inputs["RESOURCES"]
	UTES = inputs["UTES"]     # Number of UTES resources
	MultiStage = setup["MultiStage"]

    # UTES components
    # by default, i = 1 -> dry cooler; i = 2 -> chiller; i = 3 -> thermal storage; i = 4 -> pump in the tertiary loop; 
    dry_cooler, chiller, storage, pump = 1, 2, 3, 4

    # get component-wise data
    utes_dict = inputs["utes_dict"]

	G = inputs["G"]
	capUTES_dry_cooler = zeros(G)
	capUTES_chiller = zeros(G)
	capUTES_storage = zeros(G)
    capUTES_pump = zeros(G)

	# new cap
	for y in UTES
		capUTES_dry_cooler[y] = value.(EP[:vCAP_UTES])[y, dry_cooler]
        capUTES_chiller[y] = value.(EP[:vCAP_UTES])[y, chiller]
        capUTES_storage[y] = value.(EP[:vCAP_UTES])[y, storage]
        capUTES_pump[y] = value.(EP[:vCAP_UTES])[y, pump]
	end

	# retired cap
    retcapUTES_dry_cooler = zeros(G)
    retcapUTES_chiller = zeros(G)
    retcapUTES_storage = zeros(G)
    retcapUTES_pump = zeros(G)

	for y in UTES
		retcapUTES_dry_cooler[y] = value.(EP[:vRETCAP_UTES])[y, dry_cooler]
        retcapUTES_chiller[y] = value.(EP[:vRETCAP_UTES])[y, chiller]
        retcapUTES_storage[y] = value.(EP[:vRETCAP_UTES])[y, storage]
        retcapUTES_pump[y] = value.(EP[:vRETCAP_UTES])[y, pump]
    end


	dfCapUTES = DataFrame(Resource = resource_name.(gen[UTES]),
		Zone = zone_id.(gen[UTES]),
		
		StartCap_Dry_Cooler_MW = [utes_dict[y, "existing_cap"][dry_cooler] for y in UTES],
        StartCap_Chiller_MW = [utes_dict[y, "existing_cap"][chiller] for y in UTES],
        StartCap_Storage_kg = [utes_dict[y, "existing_cap"][storage] for y in UTES],
        StartCap_Pump_MW = [utes_dict[y, "existing_cap"][pump] for y in UTES],

        NewCap_Dry_Cooler_MW = capUTES_dry_cooler[UTES],
        NewCap_Chiller_MW = capUTES_chiller[UTES],
        NewCap_Storage_kg = capUTES_storage[UTES],
        NewCap_Pump_MW = capUTES_pump[UTES],

        RetCap_Dry_Cooler_MW = retcapUTES_dry_cooler[UTES],
        RetCap_Chiller_MW = retcapUTES_chiller[UTES],
        RetCap_Storage_kg = retcapUTES_storage[UTES],
        RetCap_Pump_MW = retcapUTES_pump[UTES],

        EndCap_Dry_Cooler_MW = [value.(EP[:eTotalCap_UTES])[y, dry_cooler] for y in UTES],
        EndCap_Chiller_MW = [value.(EP[:eTotalCap_UTES])[y, chiller] for y in UTES],
        EndCap_Storage_kg = [value.(EP[:eTotalCap_UTES])[y, storage] for y in UTES],
        EndCap_Pump_MW = [value.(EP[:eTotalCap_UTES])[y, pump] for y in UTES],
    )

	if setup["ParameterScale"] == 1
		columns_to_scale = [
			:StartCap_Dry_Cooler_MW,
            :RetCap_Dry_Cooler_MW,
            :NewCap_Dry_Cooler_MW,
            :EndCap_Dry_Cooler_MW,
            :StartCap_Chiller_MW,
            :RetCap_Chiller_MW,
            :NewCap_Chiller_MW,
            :EndCap_Chiller_MW,
            :StartCap_Storage_kg,
            :RetCap_Storage_kg,
            :NewCap_Storage_kg,
            :EndCap_Storage_kg,
            :StartCap_Pump_MW,
            :RetCap_Pump_MW,
            :NewCap_Pump_MW,
            :EndCap_Pump_MW,
        ]

		scale_columns!(dfCapUTES, columns_to_scale, ModelScalingFactor)
	end

	total_utes = DataFrame(
		Resource = "Total", Zone = "n/a", 
		StartCap_Dry_Cooler_MW = sum(dfCapUTES[!,:StartCap_Dry_Cooler_MW]),
        NewCap_Dry_Cooler_MW = sum(dfCapUTES[!,:NewCap_Dry_Cooler_MW]),
        RetCap_Dry_Cooler_MW = sum(dfCapUTES[!,:RetCap_Dry_Cooler_MW]),
        EndCap_Dry_Cooler_MW = sum(dfCapUTES[!,:EndCap_Dry_Cooler_MW]),

        StartCap_Chiller_MW = sum(dfCapUTES[!,:StartCap_Chiller_MW]),
        NewCap_Chiller_MW = sum(dfCapUTES[!,:NewCap_Chiller_MW]),
        RetCap_Chiller_MW = sum(dfCapUTES[!,:RetCap_Chiller_MW]),
        EndCap_Chiller_MW = sum(dfCapUTES[!,:EndCap_Chiller_MW]),

        StartCap_Storage_kg = sum(dfCapUTES[!,:StartCap_Storage_kg]),
        NewCap_Storage_kg = sum(dfCapUTES[!,:NewCap_Storage_kg]),
        RetCap_Storage_kg = sum(dfCapUTES[!,:RetCap_Storage_kg]),
        EndCap_Storage_kg = sum(dfCapUTES[!,:EndCap_Storage_kg]),

        StartCap_Pump_MW = sum(dfCapUTES[!,:StartCap_Pump_MW]),
        NewCap_Pump_MW = sum(dfCapUTES[!,:NewCap_Pump_MW]),
        RetCap_Pump_MW = sum(dfCapUTES[!,:RetCap_Pump_MW]),
        EndCap_Pump_MW = sum(dfCapUTES[!,:EndCap_Pump_MW]),
	)

	dfCapUTES = vcat(dfCapUTES, total_utes)
	CSV.write(joinpath(path,"capacity_UTES.csv"), dfCapUTES)

end