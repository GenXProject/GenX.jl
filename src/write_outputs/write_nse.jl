function write_nse(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
    	SEG = inputs["SEG"] # Number of load curtailment segments
	# Non-served energy/demand curtailment by segment in each time step
	dfNse = DataFrame()
	dfTemp = Dict()
	for z in 1:Z
		dfTemp = DataFrame(Segment=zeros(SEG), Zone=zeros(SEG), AnnualSum = Array{Union{Missing,Float32}}(undef, SEG))
		dfTemp[!,:Segment] = (1:SEG)
		dfTemp[!,:Zone] = fill(z,(SEG))
		for i in 1:SEG
			if setup["ParameterScale"] ==1
				dfTemp[!,:AnnualSum][i] = sum(inputs["omega"].* (value.(EP[:vNSE])[i,:,z]))* ModelScalingFactor
			else
				dfTemp[!,:AnnualSum][i] = sum(inputs["omega"].* (value.(EP[:vNSE])[i,:,z]))
			end

		end
		dfTemp = hcat(dfTemp, convert(DataFrame, value.(EP[:vNSE])[:,:,z]))
		if z == 1
			dfNse = dfTemp
		else
			dfNse = vcat(dfNse,dfTemp)
		end
	end

	auxNew_Names=[Symbol("Segment");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfNse,auxNew_Names)
	total = convert(DataFrame, ["Total" 0 sum(dfNse[!,:AnnualSum]) fill(0.0, (1,T))])
	for t in 1:T
		total[!,t+3] .= sum(dfNse[!,Symbol("t$t")][1:Z])
	end
	rename!(total,auxNew_Names)
	dfNse = vcat(dfNse, total)

	CSV.write(string(path,sep,"nse.csv"),  dftranspose(dfNse, false), writeheader=false)
	return dfTemp
end
