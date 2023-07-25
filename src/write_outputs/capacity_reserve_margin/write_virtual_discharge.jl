@doc raw"""
	write_virtual_discharge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
Function for writing the "virtual" discharge of each storage technology. Virtual discharge is used to
	allow storage resources to contribute to the capacity reserve margin without actually discharging.
"""
function write_virtual_discharge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	STOR_ALL = inputs["STOR_ALL"]
	VRE_STOR = inputs["VRE_STOR"]

	dfVirtualDischarge = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], AnnualSum = Array{Union{Missing,Float64}}(undef, G))
	virtual_discharge = zeros(G,T)

	scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
	if !isempty(STOR_ALL)
	    virtual_discharge[STOR_ALL, :] = (value.(EP[:vCAPRES_discharge][STOR_ALL, :]).data - value.(EP[:vCAPRES_charge][STOR_ALL, :]).data) * scale_factor
	end
    if !isempty(VRE_STOR)
		DC_DISCHARGE = inputs["VS_STOR_DC_DISCHARGE"]
		DC_CHARGE = inputs["VS_STOR_DC_CHARGE"]
		AC_DISCHARGE = inputs["VS_STOR_AC_DISCHARGE"]
		AC_CHARGE = inputs["VS_STOR_AC_CHARGE"]
		dfVRE_STOR = inputs["dfVRE_STOR"]
	    virtual_discharge[DC_DISCHARGE, :] .+= (value.(EP[:vCAPRES_DC_DISCHARGE][DC_DISCHARGE, :]).data .* dfVRE_STOR[(dfVRE_STOR.STOR_DC_DISCHARGE.!=0), :EtaInverter]) * scale_factor
		virtual_discharge[DC_CHARGE, :] .-= (value.(EP[:vCAPRES_DC_CHARGE][DC_CHARGE, :]).data ./ dfVRE_STOR[(dfVRE_STOR.STOR_DC_CHARGE.!=0), :EtaInverter]) * scale_factor
		virtual_discharge[AC_DISCHARGE, :] .+= (value.(EP[:vCAPRES_AC_DISCHARGE][AC_DISCHARGE, :]).data) * scale_factor
		virtual_discharge[AC_CHARGE, :] .-= (value.(EP[:vCAPRES_AC_CHARGE][AC_CHARGE, :]).data) * scale_factor
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