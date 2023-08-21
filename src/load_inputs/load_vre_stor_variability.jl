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
	load_vre_stor_variability!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to hourly maximum capacity factors for the solar PV 
	(DC capacity factors) component and wind (AC capacity factors) component of co-located
	generators
"""
function load_vre_stor_variability!(setup::Dict, path::AbstractString, inputs::Dict)

	# Hourly capacity factors
	data_directory = joinpath(path, setup["TimeDomainReductionFolder"])
    if setup["TimeDomainReduction"] == 1  && time_domain_reduced_files_exist(data_directory)
		my_dir = data_directory
	else
        my_dir = path
	end
	filename1 = "Vre_and_stor_solar_variability.csv"
	vre_stor_solar = load_dataframe(joinpath(my_dir, filename1))

	filename2 = "Vre_and_stor_wind_variability.csv"
	vre_stor_wind = load_dataframe(joinpath(my_dir, filename2))

	all_resources = inputs["RESOURCES"]

	function ensure_column_zeros!(vre_stor_df, all_resources)
		existing_variability = names(vre_stor_df)
		for r in all_resources
			if r ∉ existing_variability
				ensure_column!(vre_stor_df, r, 0.0)
			end
		end
	end

	ensure_column_zeros!(vre_stor_solar, all_resources)
	ensure_column_zeros!(vre_stor_wind, all_resources)

	# Reorder DataFrame to R_ID order (order provided in Vre_and_stor_data.csv)
	select!(vre_stor_solar, [:Time_Index; Symbol.(all_resources) ])
	select!(vre_stor_wind, [:Time_Index; Symbol.(all_resources) ])

	# Maximum power output and variability of each energy resource
	inputs["pP_Max_Solar"] = transpose(Matrix{Float64}(vre_stor_solar[1:inputs["T"],2:(inputs["G"]+1)]))
	inputs["pP_Max_Wind"] = transpose(Matrix{Float64}(vre_stor_wind[1:inputs["T"],2:(inputs["G"]+1)]))

	println(filename1 * " Successfully Read!")
	println(filename2 * " Successfully Read!")
end
