@doc raw"""
	write_angles(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting the bus angles for each model zone and time step if the DC_OPF flag is activated
"""
function write_angles(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones

    dfAngles = DataFrame(Zone = 1:Z)
    angles = value.(EP[:vANGLE])
    dfAngles = hcat(dfAngles, DataFrame(angles, :auto))

    auxNew_Names = [Symbol("Zone"); [Symbol("t$t") for t in 1:T]]
    rename!(dfAngles, auxNew_Names)

    ## Linear configuration final output
    CSV.write(joinpath(path, "angles.csv"),
        dftranspose(dfAngles, false),
        writeheader = false)
    return nothing
end
