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

function write_time_weights(path::AbstractString, sep::AbstractString, inputs::Dict)
	T = inputs["T"]     # Number of time steps (hours)
	# Save array of weights for each time period (when using time sampling)
	dfTimeWeights = DataFrame(Time=1:T, Weight=inputs["omega"])
	CSV.write(string(path,sep,"time_weights.csv"), dfTimeWeights)
end
