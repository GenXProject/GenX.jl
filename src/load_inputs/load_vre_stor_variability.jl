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
	load_vre_stor_variability(setup::Dict, path::AbstractString, sep::AbstractString, inputs_vre_stor::Dict)

Function for reading input parameters related to hourly maximum capacity factors for co-located and co-optimized generators
"""
function load_vre_stor_variability(setup::Dict, path::AbstractString, sep::AbstractString, inputs_vre_stor::Dict)

	# Hourly capacity factors
	# data_directory = chop(replace(path, pwd() => ""), head = 1, tail = 0)
	data_directory = joinpath(path, setup["TimeDomainReductionFolder"])
	if setup["TimeDomainReduction"] == 1  && isfile(joinpath(data_directory,"Load_data.csv")) && isfile(joinpath(data_directory,"Vre_and_storage_variability.csv")) && isfile(joinpath(data_directory,"Fuels_data.csv")) # Use Time Domain Reduced data for GenX
		vre_stor_var = DataFrame(CSV.File(string(joinpath(data_directory,"Vre_and_storage_variability.csv")), header=true), copycols=true)
	else # Run without Time Domain Reduction OR Getting original input data for Time Domain Reduction
		vre_stor_var = DataFrame(CSV.File(string(path,sep,"Vre_and_storage_variability.csv"), header=true), copycols=true)
	end

	# Reorder DataFrame to R_ID order (order provided in Vre_and_storage_data.csv)
	select!(vre_stor_var, [:Time_Index; Symbol.(inputs_vre_stor["RESOURCES_VRE_STOR"]) ])

	# Maximum power output and variability of each energy resource
	inputs_vre_stor["pP_Max_VRE_STOR"] = transpose(convert(Matrix{Float64}, vre_stor_var[1:inputs_vre_stor["T"],2:(inputs_vre_stor["VRE_STOR"]+1)]))

	println("Vre_and_storage_variability.csv Successfully Read!")

	return inputs_vre_stor
end
