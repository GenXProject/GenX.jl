@doc raw"""
	load_generators_variability(setup::Dict, path::AbstractString, sep::AbstractString, inputs_genvar::Dict)

Function for reading input parameters related to hourly maximum capacity factors for all generators (plus storage and flexible demand resources)
"""
function load_generators_variability(setup::Dict, path::AbstractString, sep::AbstractString, inputs_genvar::Dict)

	# Hourly capacity factors
	#data_directory = chop(replace(path, pwd() => ""), head = 1, tail = 0)
	data_directory = joinpath(path, setup["TimeDomainReductionFolder"])
	if setup["TimeDomainReduction"] == 1  && isfile(joinpath(data_directory,"Load_data.csv")) && isfile(joinpath(data_directory,"Generators_variability.csv")) && isfile(joinpath(data_directory,"Fuels_data.csv")) # Use Time Domain Reduced data for GenX
		gen_var = DataFrame(CSV.File(string(joinpath(data_directory,"Generators_variability.csv")), header=true), copycols=true)
	else # Run without Time Domain Reduction OR Getting original input data for Time Domain Reduction
		gen_var = DataFrame(CSV.File(string(path,sep,"Generators_variability.csv"), header=true), copycols=true)
	end

	# Reorder DataFrame to R_ID order (order provided in Generators_data.csv)
	select!(gen_var, [:Time_Index; Symbol.(inputs_genvar["RESOURCES"]) ])

	# Maximum power output and variability of each energy resource
	inputs_genvar["pP_Max"] = transpose(convert(Matrix{Float64}, gen_var[1:inputs_genvar["T"],2:(inputs_genvar["G"]+1)]))

	println("Generators_variability.csv Successfully Read!")

	return inputs_genvar
end
