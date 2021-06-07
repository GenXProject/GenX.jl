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
	write_nse(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting non-served energy for every model zone, time step and cost-segment.
"""
function write_nse(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
    	SEG = inputs["SEG"] # Number of load curtailment segments
	# Non-served energy/demand curtailment by segment in each time step
	dfNse = DataFrame()
	dfTemp = Dict()
	for z in 1:Z
		dfTemp = DataFrame(Segment=zeros(SEG), Zone=zeros(SEG), AnnualSum = Array{Union{Missing,Float32}}(undef, SEG))
		dfTemp[!,:Segment] = (1:SEG)
		dfTemp[!,:Zone] = fill(z,(SEG))
		for i in 1:SEG
			if setup["ParameterScale"] ==1
				dfTemp[!,:AnnualSum][i] = sum(inputs["omega"].* (value.(EP[:vNSE])[i,:,z]))* ModelScalingFactor
			else
				dfTemp[!,:AnnualSum][i] = sum(inputs["omega"].* (value.(EP[:vNSE])[i,:,z]))
			end

		end
		dfTemp = hcat(dfTemp, convert(DataFrame, value.(EP[:vNSE])[:,:,z]))
		if z == 1
			dfNse = dfTemp
		else
			dfNse = vcat(dfNse,dfTemp)
		end
	end

	auxNew_Names=[Symbol("Segment");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfNse,auxNew_Names)
	total = convert(DataFrame, ["Total" 0 sum(dfNse[!,:AnnualSum]) fill(0.0, (1,T))])
	for t in 1:T
		total[!,t+3] .= sum(dfNse[!,Symbol("t$t")][1:Z])
	end
	rename!(total,auxNew_Names)
	dfNse = vcat(dfNse, total)

	CSV.write(string(path,sep,"nse.csv"),  dftranspose(dfNse, false), writeheader=false)
	return dfTemp
end
