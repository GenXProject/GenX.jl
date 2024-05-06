@doc raw"""
	write_virtual_discharge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the "virtual" discharge of each storage technology. Virtual discharge is used to
	allow storage resources to contribute to the capacity reserve margin without actually discharging.
"""
function write_virtual_discharge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    STOR_ALL = inputs["STOR_ALL"]

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    resources = inputs["RESOURCE_NAMES"][STOR_ALL]
    zones = inputs["R_ZONES"][STOR_ALL]
    virtual_discharge = (value.(EP[:vCAPRES_discharge][STOR_ALL, :].data) -
                         value.(EP[:vCAPRES_charge][STOR_ALL, :].data)) * scale_factor

    dfVirtualDischarge = DataFrame(Resource = resources, Zone = zones)
    dfVirtualDischarge.AnnualSum .= virtual_discharge * inputs["omega"]

    filepath = joinpath(path, "virtual_discharge.csv")
    if setup["WriteOutputs"] == "annual"
        write_annual(filepath, dfVirtualDischarge)
    else # setup["WriteOutputs"] == "full"
        write_fulltimeseries(filepath, virtual_discharge, dfVirtualDischarge)
    end
    return nothing
end
