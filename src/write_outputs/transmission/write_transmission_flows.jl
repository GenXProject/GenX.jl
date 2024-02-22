function write_transmission_flows(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	# Transmission related values
	T = inputs["T"]     # Number of time steps (hours)
	L = inputs["L"]     # Number of transmission lines
	# Power flows on transmission lines at each time step
	dfFlow = DataFrame(Line = 1:L)
	flow = value.(EP[:vFLOW])
	if setup["ParameterScale"] == 1
	    flow *= ModelScalingFactor
	end

	dfFlow.AnnualSum = flow * inputs["omega"]

	filepath = joinpath(path, "flow.csv")	
	if setup["WriteOutputs"] == "annual"
		total = DataFrame(["Total" sum(dfFlow.AnnualSum)], [:Line, :AnnualSum])
		dfFlow = vcat(dfFlow, total)
		CSV.write(filepath, dfFlow)
	else 	# setup["WriteOutputs"] == "full" 
		dfFlow = hcat(dfFlow, DataFrame(flow, :auto))
		auxNew_Names=[Symbol("Line");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
		rename!(dfFlow,auxNew_Names)
		total = DataFrame(["Total" sum(dfFlow.AnnualSum) fill(0.0, (1,T))], auxNew_Names)
		total[:, 3:T+2] .= sum(flow, dims = 1)
		dfFlow = vcat(dfFlow, total)
		CSV.write(filepath, dftranspose(dfFlow, false), writeheader=false)
	end
	return nothing
end
