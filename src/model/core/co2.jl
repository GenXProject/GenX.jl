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

@doc raw""" CO2 emissions and CO2 capture"""
function co2(EP::Model, inputs::Dict, setup::Dict)

	println("C02 Module")

	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones

	### Expressions ###
	# CO emissions from power plants in "Generator_data.csv"
	@expression(EP, eEmissionsByPlant[y=1:G,t=1:T],
	if setup["PieceWiseHeatRate"] ==1
		if y in inputs["COMMIT"]
			(1 - dfGen[!,:CO2_Capture_Rate][y])*(dfGen[!,:CO2_per_MMBTU][y]*EP[:vFuel][y,t] + dfGen[!,:CO2_per_Start][y]*EP[:vSTART][y,t])
		end
	else
		if y in inputs["COMMIT"]
			(1 - dfGen[!,:CO2_Capture_Rate][y])*(dfGen[!,:CO2_per_MWh][y]*EP[:vP][y,t] + dfGen[!,:CO2_per_Start][y]*EP[:vSTART][y,t])
		else
			(1 - dfGen[!,:CO2_Capture_Rate][y])*dfGen[!,:CO2_per_MWh][y]*EP[:vP][y,t]
		end
	end)
	@expression(EP, eEmissionsByZone[z=1:Z, t=1:T], sum(eEmissionsByPlant[y,t] for y in dfGen[(dfGen[!,:Zone].==z),:R_ID]))

    # CO2  captured from power plants in "Generator_data.csv"
    @expression(EP, eEmissionsCaptureByPlant[y=1:G,t=1:T],
    if setup["PieceWiseHeatRate"] ==1
	    if y in inputs["COMMIT"]
	    	(dfGen[!,:CO2_Capture_Rate][y])*(dfGen[!,:CO2_per_MMBTU][y]*EP[:vFuel][y,t]  + dfGen[!,:CO2_per_Start][y]*EP[:vSTART][y,t])
    	end
    else
	    if y in inputs["COMMIT"]
		    (dfGen[!,:CO2_Capture_Rate][y])*(dfGen[!,:CO2_per_MWh][y]*EP[:vP][y,t] + dfGen[!,:CO2_per_Start][y]*EP[:vSTART][y,t])
	    else
		     dfGen[!,:CO2_per_MWh][y]*EP[:vP][y,t]*(dfGen[!,:CO2_Capture_Rate][y])
	    end
    end)

    @expression(EP, eEmissionsCaptureByZone[z=1:Z, t=1:T], sum(eEmissionsCaptureByPlant[y,t] for y in dfGen[(dfGen[!,:Zone].==z),:R_ID]) )


    # add CO2 sequestration cost to objective function

    @expression(EP, eCCO2Sequestration[z=1:Z, t = 1:T],  sum(inputs["omega"][t] * eEmissionsCaptureByPlant[y,t] * dfGen[!,:CO2_Sequestration_Per_ton][y] for y in dfGen[(dfGen[!,:Zone].==z),:R_ID]))

	@expression(EP, eTotaleCCO2Sequestration,sum(eCCO2Sequestration[z, t] for z in 1:Z, t in 1:T))

	EP[:eObj] += eTotaleCCO2Sequestration



	return EP

end
