function write_time_weights(path::AbstractString, sep::AbstractString, inputs::Dict)
	T = inputs["T"]     # Number of time steps (hours)
	# Save array of weights for each time period (when using time sampling)
	dfTimeWeights = DataFrame(Time=1:T, Weight=inputs["omega"])
	CSV.write(string(path,sep,"time_weights.csv"), dfTimeWeights)
end