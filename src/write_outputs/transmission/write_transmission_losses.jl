function write_transmission_losses(path::AbstractString, sep::AbstractString, inputs::Dict, EP::Model)
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	L = inputs["L"]     # Number of transmission lines

	# Power losses for transmission between zones at each time step
	dfTLosses = DataFrame(Line = 1:L, Sum = Array{Union{Missing,Float32}}(undef, L))
	tlosses = zeros(L,T)
	for i in 1:L
		if i in inputs["LOSS_LINES"]
			tlosses[i,:] = value.(EP[:vTLOSS])[i,:]
		end
		dfTLosses[!,:Sum][i] = sum(tlosses[i,:])
	end
	dfTLosses = hcat(dfTLosses, convert(DataFrame, tlosses))
	auxNew_Names=[Symbol("Line");Symbol("Sum");[Symbol("t$t") for t in 1:T]]
	rename!(dfTLosses,auxNew_Names)
	total = convert(DataFrame, ["Total" sum(dfTLosses[!,:Sum]) fill(0.0, (1,T))])
	for t in 1:T
		total[!,t+2] .= sum(dfTLosses[!,Symbol("t$t")][1:L])
	end
	rename!(total,auxNew_Names)
	dfTLosses = vcat(dfTLosses, total)

	CSV.write(string(path,sep,"tlosses.csv"), dftranspose(dfTLosses, false), writeheader=false)
end
