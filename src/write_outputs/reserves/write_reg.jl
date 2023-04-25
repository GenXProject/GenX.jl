function write_reg(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]

	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	REG = inputs["REG"]
	scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
	# Regulation contributions for each resource in each time step
	dfReg = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone])
	reg = zeros(G,T)
	reg[REG, :] = value.(EP[:vREG][REG, :])
	dfReg.AnnualSum = (reg*scale_factor) * inputs["omega"]
	dfReg = hcat(dfReg, DataFrame(reg*scale_factor, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfReg,auxNew_Names)

	total = DataFrame(["Total" 0 sum(dfReg.AnnualSum) fill(0.0, (1,T))], :auto)
	total[!, 4:T+3] .= sum(reg, dims = 1)
	rename!(total,auxNew_Names)
	dfReg = vcat(dfReg, total)
	CSV.write(joinpath(path, "reg.csv"), dftranspose(dfReg, false), writeheader=false)
end
