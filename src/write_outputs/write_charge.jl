@doc raw"""
	write_charge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the charging energy values of the different storage technologies.
"""
function write_charge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	resources = inputs["RESOURCES"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	STOR_ALL = inputs["STOR_ALL"]
	FLEX = inputs["FLEX"]
	ELECTROLYZER = inputs["ELECTROLYZER"]
	VRE_STOR = inputs["VRE_STOR"]
	VS_STOR = !isempty(VRE_STOR) ? inputs["VS_STOR"] : []
	
	# Power withdrawn to charge each resource in each time step
	dfCharge = DataFrame(Resource = inputs["RESOURCE_NAMES"], Zone = zone_id.(resources), AnnualSum = Array{Union{Missing,Float64}}(undef, G))
	charge = zeros(G,T)

	scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
	if !isempty(STOR_ALL)
	    charge[STOR_ALL, :] = value.(EP[:vCHARGE][STOR_ALL, :]) * scale_factor
	end
	if !isempty(FLEX)
	    charge[FLEX, :] = value.(EP[:vCHARGE_FLEX][FLEX, :]) * scale_factor
	end
	if !isempty(ELECTROLYZER)
	    charge[ELECTROLYZER, :] = value.(EP[:vUSE][ELECTROLYZER, :]) * scale_factor
	end
	if !isempty(VS_STOR)
		charge[VS_STOR, :] = value.(EP[:vCHARGE_VRE_STOR][VS_STOR, :]) * scale_factor
	end

	dfCharge.AnnualSum .= charge * inputs["omega"]
	dfCharge = hcat(dfCharge, DataFrame(charge, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfCharge,auxNew_Names)
	total = DataFrame(["Total" 0 sum(dfCharge[!,:AnnualSum]) fill(0.0, (1,T))], :auto)

	total[:, 4:T+3] .= sum(charge, dims = 1)
	rename!(total,auxNew_Names)
	dfCharge = vcat(dfCharge, total)
	CSV.write(joinpath(path, "charge.csv"), dftranspose(dfCharge, false), writeheader=false)
	return dfCharge
end
