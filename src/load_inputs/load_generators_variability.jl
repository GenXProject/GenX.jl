"""
GenX: An Configurable Capacity Expansion Model
Copyright (C) 2021,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

@doc raw"""
	load_generators_variability(setup::Dict, path::AbstractString, inputs_genvar::Dict)

Function for reading input parameters related to hourly maximum capacity factors for all generators (plus storage and flexible demand resources)
"""
function load_generators_variability(setup::Dict, path::AbstractString, inputs_genvar::Dict)

	# Hourly capacity factors
	#data_directory = chop(replace(path, pwd() => ""), head = 1, tail = 0)
	data_directory = joinpath(path, setup["TimeDomainReductionFolder"])
	if setup["TimeDomainReduction"] == 1  && isfile(joinpath(data_directory,"Load_data.csv")) && isfile(joinpath(data_directory,"Generators_variability.csv")) && isfile(joinpath(data_directory,"Fuels_data.csv")) # Use Time Domain Reduced data for GenX
		gen_var = DataFrame(CSV.File(joinpath(data_directory,"Generators_variability.csv"), header=true), copycols=true)
	else # Run without Time Domain Reduction OR Getting original input data for Time Domain Reduction
		gen_var = DataFrame(CSV.File(joinpath(path,"Generators_variability.csv"), header=true), copycols=true)
	end

	# Reorder DataFrame to R_ID order (order provided in Generators_data.csv)
	select!(gen_var, [:Time_Index; Symbol.(inputs_genvar["RESOURCES"]) ])

	# Maximum power output and variability of each energy resource
	inputs_genvar["pP_Max"] = transpose(Matrix{Float64}(gen_var[1:inputs_genvar["T"],2:(inputs_genvar["G"]+1)]))

	println("Generators_variability.csv Successfully Read!")

	return inputs_genvar
end
