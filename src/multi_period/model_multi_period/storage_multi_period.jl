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
	storage_multi_period(EP::Model, inputs::Dict, Reserves::Int, OperationWrapping::Int, LongDurationStorage::Int, MultiPeriodSettingsDict::Dict)

This function is identical to storage(), except calls multi-period investment energy and charge methods.
"""
function storage_multi_period(EP::Model, inputs::Dict, Reserves::Int, OperationWrapping::Int, LongDurationStorage::Int, MultiPeriodSettingsDict::Dict)

	println("Storage Resources Multi-Period Module")

	G = inputs["G"]

	if !isempty(inputs["STOR_ALL"])
		EP = investment_energy_multi_period(EP, inputs, MultiPeriodSettingsDict)
		EP = storage_all(EP, inputs, Reserves, OperationWrapping, LongDurationStorage)

		# Include LongDurationStorage only when modeling representative periods and long-duration storage
		if OperationWrapping == 1 && LongDurationStorage == 1
			EP = long_duration_storage(EP, inputs)
		end
	end

	if !isempty(inputs["STOR_ASYMMETRIC"])
		EP = investment_charge_multi_period(EP, inputs,MultiPeriodSettingsDict)
		EP = storage_asymmetric(EP, inputs, Reserves)
	end

	if !isempty(inputs["STOR_SYMMETRIC"])
		EP = storage_symmetric(EP, inputs, Reserves)
	end

	return EP
end
