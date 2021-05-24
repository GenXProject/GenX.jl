@doc raw"""
	load_period_map(setup::Dict,path::AbstractString,sep::AbstractString, inputs::Dict)

Function for reading input parameters related to mapping of representative time periods to full chronological time series
"""
function load_period_map(setup::Dict,path::AbstractString,sep::AbstractString, inputs::Dict)
	data_directory = joinpath(path, setup["TimeDomainReductionFolder"])
	if setup["TimeDomainReduction"] == 1  && isfile(joinpath(data_directory,"Period_map.csv"))  # Use Time Domain Reduced data for GenX
		inputs["Period_Map"] = DataFrame(CSV.File(string(joinpath(data_directory,"Period_map.csv")), header=true), copycols=true)
	else
		inputs["Period_Map"] = DataFrame(CSV.File(string(path,sep,"Period_map.csv"), header=true), copycols=true)
	end

	println("Period_map.csv Successfully Read!")

	return inputs
end
