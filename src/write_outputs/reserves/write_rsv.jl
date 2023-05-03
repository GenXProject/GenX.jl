function write_rsv(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]

	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	RSV = inputs["RSV"]
	scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
	dfRsv = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone])
	rsv = zeros(G,T)
	unmet_vec = zeros(T)
	rsv[RSV, :] = value.(EP[:vRSV][RSV, :])
	unmet_vec[RSV] = value.(EP[:vUNMET_RSV][RSV])
	total_unmet = (sum(unmet_vec)*scale_factor)
	dfRsv.AnnualSum = (rsv*scale_factor) * inputs["omega"]
	dfRsv = hcat(dfRsv, DataFrame((rsv*scale_factor), :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfRsv,auxNew_Names)

	total = DataFrame(["Total" 0 sum(dfRsv.AnnualSum) zeros(1, T)], :auto)
	unmet = DataFrame(["unmet" 0 total_unmet zeros(1, T)], :auto)
	total[!, 4:T+3] .= sum(rsv, dims = 1)
	unmet[!, 4:T+3] .= transpose(unmet_vec)
	rename!(total,auxNew_Names)
	rename!(unmet,auxNew_Names)
	dfRsv = vcat(dfRsv, unmet, total)
	CSV.write(joinpath(path, "reg_dn.csv"), dftranspose(dfRsv, false), writeheader=false)
end
