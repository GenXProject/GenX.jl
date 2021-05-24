@doc raw"""
	load_fuels_data(setup::Dict, path::AbstractString, sep::AbstractString, inputs_fuel::Dict)

Function for reading input parameters related to fuel costs and CO$_2$ content of fuels
"""
function load_fuels_data(setup::Dict, path::AbstractString, sep::AbstractString, inputs_fuel::Dict)

	# Fuel related inputs - read in different files depending on if time domain reduction is activated or not
	#data_directory = chop(replace(path, pwd() => ""), head = 1, tail = 0)
	data_directory = joinpath(path, setup["TimeDomainReductionFolder"])
	if setup["TimeDomainReduction"] == 1  && isfile(joinpath(data_directory,"Load_data.csv")) && isfile(joinpath(data_directory,"Generators_variability.csv")) && isfile(joinpath(data_directory,"Fuels_data.csv")) # Use Time Domain Reduced data for GenX
		fuels_in = DataFrame(CSV.File(string(joinpath(data_directory,"Fuels_data.csv")), header=true), copycols=true)
	else  # Run without Time Domain Reduction OR Getting original input data for Time Domain Reduction
		fuels_in = DataFrame(CSV.File(string(path,sep,"Fuels_data.csv"), header=true), copycols=true)
	end

	# Fuel costs .&  CO2 emissions rate for each fuel type (stored in dictionary objects)
	fuels = names(fuels_in)[2:end] # fuel type indexes
	costs = convert(Matrix, fuels_in[2:end,2:end])
	# New addition for variable fuel price
	CO2_content = fuels_in[1,2:end] # tons CO2/MMBtu
	fuel_costs = Dict{AbstractString,Array{Float64}}()
	fuel_CO2 = Dict{AbstractString,Float64}()
	for i = 1:length(fuels)
		if setup["ParameterScale"] ==1
			fuel_costs[string(fuels[i])] = costs[:,i]/ModelScalingFactor
			fuel_CO2[string(fuels[i])] = CO2_content[i]/ModelScalingFactor # kton/MMBTU
		else
			fuel_costs[string(fuels[i])] = costs[:,i]
			fuel_CO2[string(fuels[i])] = CO2_content[i] # ton/MMBTU
		end
	end

	inputs_fuel["fuels"] = fuels
	inputs_fuel["fuel_costs"] = fuel_costs
	inputs_fuel["fuel_CO2"] = fuel_CO2

	println("Fuels_data.csv Successfully Read!")

	return inputs_fuel, fuel_costs, fuel_CO2
end
