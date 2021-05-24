function write_transmission_flows(path::AbstractString, sep::AbstractString, inputs::Dict, EP::Model)
	# Transmission related values
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	L = inputs["L"]     # Number of transmission lines
	# Power flows on transmission lines at each time step
	dfFlow = DataFrame(Line = 1:L, Sum = Array{Union{Missing,Float32}}(undef, L))
	for i in 1:L
		dfFlow[!,:Sum][i] = sum(value.(EP[:vFLOW])[i,:])
	end
	dfFlow = hcat(dfFlow, convert(DataFrame, value.(EP[:vFLOW])))
	auxNew_Names=[Symbol("Line");Symbol("Sum");[Symbol("t$t") for t in 1:T]]
	rename!(dfFlow,auxNew_Names)
	total = convert(DataFrame, ["Total" sum(dfFlow[!,:Sum]) fill(0.0, (1,T))])
	for t in 1:T
		total[!,t+2] .= sum(dfFlow[!,Symbol("t$t")][1:L])
	end
	rename!(total,auxNew_Names)
	dfFlow = vcat(dfFlow, total)

	CSV.write(string(path,sep,"flow.csv"), dftranspose(dfFlow, false), writeheader=false)
end