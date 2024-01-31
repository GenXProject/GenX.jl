function write_start(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	COMMIT = inputs["COMMIT"]
	# Startup state for each resource in each time step
	start = value.(EP[:vSTART][COMMIT, :].data)
	resources = inputs["RESOURCES"][COMMIT]
	zones = dfGen[COMMIT, :Zone]

	dfStart = DataFrame(Resource = resources, Zone = zones)
	dfStart.AnnualSum = start * inputs["omega"]

	filepath = joinpath(path, "start.csv")
	if setup["WriteOutputs"] == "annual"
		write_annual(filepath, dfStart)
	else 	# setup["WriteOutputs"] == "full"	
		write_fulltimeseries(filepath, start, dfStart)
	end
	return nothing
end