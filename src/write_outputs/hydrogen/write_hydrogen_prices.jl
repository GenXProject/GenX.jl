function write_hydrogen_prices(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	gen = inputs["RESOURCES"]
	ELECTROLYZERS = inputs["ELECTROLYZER"]      # Set of electrolyzers connected to the grid (indices)
	VRE_STOR = inputs["VRE_STOR"] 	            # Set of VRE-STOR generators (indices)
    gen_VRE_STOR = gen.VreStorage               # Set of VRE-STOR generators (objects)

	if !isempty(VRE_STOR)
		VS_ELEC = inputs["VS_ELEC"]             # Set of VRE-STOR co-located electrolyzers (indices)
	else
		VS_ELEC = Vector{Int}[]
	end

	scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor^2 : 1  # If ParameterScale==1, costs are in millions of $
	
	NumberOfH2DemandReqs = inputs["NumberOfH2DemandReqs"]
	dfHydrogenPrice = DataFrame(
		H2_Demand = [Symbol("H2_Demand_$h2demand") for h2demand in 1:NumberOfH2DemandReqs],
		Hydrogen_Price_Per_Tonne = convert(Array{Float64}, dual.(EP[:cZoneH2DemandReq])*scale_factor))
	CSV.write(joinpath(path, "hydrogen_prices.csv"), dfHydrogenPrice)
	
	return nothing
end
