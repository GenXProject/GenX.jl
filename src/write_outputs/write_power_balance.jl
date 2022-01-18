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

function write_power_balance(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	SEG = inputs["SEG"] # Number of load curtailment segments
	STOR_ALL = inputs["STOR_ALL"]
	FLEX = inputs["FLEX"]
	## Power balance for each zone
	dfPowerBalance = Array{Any}
	rowoffset=3
	for z in 1:Z
	   	dfTemp1 = Array{Any}(nothing, T+rowoffset, 10)
	   	dfTemp1[1,1:size(dfTemp1,2)] = ["Generation", "Storage_Discharge", "Storage_Charge",
	           "Flexible_Demand_Defer", "Flexible_Demand_Stasify",
	           "Demand_Response", "Nonserved_Energy",
			   "Transmission_NetExport", "Transmission_Losses",
	           "Demand"]
	   	dfTemp1[2,1:size(dfTemp1,2)] = repeat([z],size(dfTemp1,2))
	   	for t in 1:T
	     	dfTemp1[t+rowoffset,1]= sum(value.(EP[:vP][dfGen[(dfGen[!,:THERM].==1) .&  (dfGen[!,:Zone].==z),:][!,:R_ID],t])) +
		 		sum(value.(EP[:vP][dfGen[(dfGen[!,:VRE].==1) .&  (dfGen[!,:Zone].==z),:][!,:R_ID],t])) +
				sum(value.(EP[:vP][dfGen[(dfGen[!,:MUST_RUN].==1) .&  (dfGen[!,:Zone].==z),:][!,:R_ID],t])) +
				sum(value.(EP[:vP][dfGen[(dfGen[!,:HYDRO].>=1) .&  (dfGen[!,:Zone].==z),:][!,:R_ID],t]))
	     	dfTemp1[t+rowoffset,2] = sum(value.(EP[:vP][dfGen[(dfGen[!,:STOR].>=1) .&  (dfGen[!,:Zone].==z),:][!,:R_ID],t]))
	     	dfTemp1[t+rowoffset,3] = 0
	     	if !isempty(intersect(dfGen[dfGen.Zone.==z,:R_ID],STOR_ALL))
	     	    dfTemp1[t+rowoffset,3] = -sum(value.(EP[:vCHARGE][y,t]) for y in intersect(dfGen[dfGen.Zone.==z,:R_ID],STOR_ALL))
	     	end
	     	dfTemp1[t+rowoffset,4] = 0
	     	if !isempty(intersect(dfGen[dfGen.Zone.==z,:R_ID],FLEX))
	     	    dfTemp1[t+rowoffset,4] = sum(value.(EP[:vCHARGE_FLEX][y,t]) for y in intersect(dfGen[dfGen.Zone.==z,:R_ID],FLEX))
	     	end
	     	dfTemp1[t+rowoffset,5] = -sum(value.(EP[:vP][dfGen[(dfGen[!,:FLEX].>=1) .&  (dfGen[!,:Zone].==z),:][!,:R_ID],t]))
	     	if SEG>1
	       		dfTemp1[t+rowoffset,6] = sum(value.(EP[:vNSE][2:SEG,t,z]))
	     	else
	       		dfTemp1[t+rowoffset,6]=0
	     	end
	     	dfTemp1[t+rowoffset,7] = value(EP[:vNSE][1,t,z])
	     	dfTemp1[t+rowoffset,8] = 0
	     	dfTemp1[t+rowoffset,9] = 0
		#=
	     	if setup["NetworkExpansion"] == 1
	     	    dfTemp1[t+rowoffset,8] = value(EP[:ePowerBalanceNetExportFlows][t,z])
	     	    dfTemp1[t+rowoffset,9] = -1/2 * value(EP[:eLosses_By_Zone][z,t])
	     	end
		=#
		if Z>=2
			dfTemp1[t+rowoffset,8] = value(EP[:ePowerBalanceNetExportFlows][t,z])
			dfTemp1[t+rowoffset,9] = -1/2 * value(EP[:eLosses_By_Zone][z,t])
		end
	     	dfTemp1[t+rowoffset,10] = -inputs["pD"][t,z]

			if setup["ParameterScale"] == 1
				dfTemp1[t+rowoffset,1] = dfTemp1[t+rowoffset,1] * ModelScalingFactor
				dfTemp1[t+rowoffset,2] = dfTemp1[t+rowoffset,2] * ModelScalingFactor
				dfTemp1[t+rowoffset,3] = dfTemp1[t+rowoffset,3] * ModelScalingFactor
				dfTemp1[t+rowoffset,4] = dfTemp1[t+rowoffset,4] * ModelScalingFactor
				dfTemp1[t+rowoffset,5] = dfTemp1[t+rowoffset,5] * ModelScalingFactor
				dfTemp1[t+rowoffset,6] = dfTemp1[t+rowoffset,6] * ModelScalingFactor
				dfTemp1[t+rowoffset,7] = dfTemp1[t+rowoffset,7] * ModelScalingFactor
				dfTemp1[t+rowoffset,8] = dfTemp1[t+rowoffset,8] * ModelScalingFactor
				dfTemp1[t+rowoffset,9] = dfTemp1[t+rowoffset,9] * ModelScalingFactor
				dfTemp1[t+rowoffset,10] = dfTemp1[t+rowoffset,10] * ModelScalingFactor
			end
	   	end
		if z==1
			dfPowerBalance =  hcat(vcat(["", "Zone", "AnnualSum"], ["t$t" for t in 1:T]), dfTemp1)
		else
		    dfPowerBalance = hcat(dfPowerBalance, dfTemp1)
		end
	end
	for c in 2:size(dfPowerBalance,2)
	   	dfPowerBalance[rowoffset,c]=sum(inputs["omega"].*dfPowerBalance[(rowoffset+1):size(dfPowerBalance,1),c])
	end
	dfPowerBalance = DataFrame(dfPowerBalance, :auto)
	CSV.write(joinpath(path, "power_balance.csv"), dfPowerBalance, writeheader=false)
end
