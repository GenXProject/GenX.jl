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
	fleccs(EP::Model, inputs::Dict, UCommit::Int, Reserves::Int)

The fleccs module determines which flecce deisng should be implemented
fleccs1 = conventional NGCC-CCS
fleccs2 = NGCC coupled with solvent storate
fleccs3 = NGCC coupled with thermal storage
fleccs4 = NGCC coupled with H2 storage
fleccs5 = NGCC coupled with DAC (GT+Upitt)
fleccs6 = NGCC coupled  with DAC (MIT)
fleccs6 = Allam cycle coupled with CO2 storage
"""

function fleccs(EP::Model, inputs::Dict, FLECCS::Int,  UCommit::Int, Reserves::Int, CostCO2::Int, ParameterScale::Int)
	# load fleccs fixed and investment module
	println("load fleccs module")

	#EP = fleccs_fix(EP, inputs, FLECCS,  UCommit, Reserves)

	EP = fleccs_fix(EP, inputs, FLECCS,  UCommit, Reserves)

	if FLECCS ==1
		EP = fleccs1(EP, inputs, FLECCS, UCommit, Reserves)
	elseif FLECCS ==2
		EP = fleccs2(EP, inputs, FLECCS,UCommit, Reserves, CostCO2, ParameterScale)
	elseif FLECCS ==3
		EP = fleccs3(EP, inputs, FLECCS, UCommit, Reserves)
	elseif FLECCS ==4
		EP = fleccs4(EP, inputs, FLECCS, UCommit, Reserves)
	elseif FLECCS ==5
		EP = fleccs5(EP, inputs,  FLECCS,UCommit, Reserves)
	elseif FLECCS ==6
		EP = fleccs6(EP, inputs, FLECCS, UCommit, Reserves)
	end
end
