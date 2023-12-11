@doc raw"""
	write_virtual_discharge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the "virtual" discharge of each storage technology. Virtual discharge is used to
	allow storage resources to contribute to the capacity reserve margin without actually discharging.
"""
function write_virtual_discharge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	resources = inputs["RESOURCES"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	STOR_ALL = inputs["STOR_ALL"]

	dfVirtualDischarge = DataFrame(Resource = inputs["RESOURCE_NAMES"], Zone = zone_id.(resources), AnnualSum = Array{Union{Missing,Float64}}(undef, G))
	virtual_discharge = zeros(G,T)

	scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
	if !isempty(STOR_ALL)
	    virtual_discharge[STOR_ALL, :] = (value.(EP[:vCAPRES_discharge][STOR_ALL, :]).data - value.(EP[:vCAPRES_charge][STOR_ALL, :]).data) * scale_factor
	end

	dfVirtualDischarge.AnnualSum .= virtual_discharge * inputs["omega"]
	dfVirtualDischarge = hcat(dfVirtualDischarge, DataFrame(virtual_discharge, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfVirtualDischarge,auxNew_Names)
	total = DataFrame(["Total" 0 sum(dfVirtualDischarge[!,:AnnualSum]) fill(0.0, (1,T))], :auto)

	total[:, 4:T+3] .= sum(virtual_discharge, dims = 1)
	rename!(total,auxNew_Names)
	dfVirtualDischarge = vcat(dfVirtualDischarge, total)
	CSV.write(joinpath(path, "virtual_discharge.csv"), dftranspose(dfVirtualDischarge, false), writeheader=false)
	return dfVirtualDischarge
end
