function write_reg(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    REG = inputs["REG"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    resources = inputs["RESOURCE_NAMES"][REG]
    zones = inputs["R_ZONES"][REG]
    # Regulation contributions for each resource in each time step
    reg = value.(EP[:vREG][REG, :].data) * scale_factor

    dfReg = DataFrame(Resource = resources, Zone = zones)
    dfReg.AnnualSum = reg * inputs["omega"]

    filepath = joinpath(path, "reg.csv")
    if setup["WriteOutputs"] == "annual"
        write_annual(filepath, dfReg)
    else # setup["WriteOutputs"] == "full"
        write_fulltimeseries(filepath, reg, dfReg)
    end
    return nothing
end
