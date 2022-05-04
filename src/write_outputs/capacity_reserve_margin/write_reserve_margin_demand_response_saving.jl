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
	write_reserve_margin_payment(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting the capacity revenue earned by each generator listed in the input file. 
    GenX will print this file only when capacity reserve margin is modeled and the shadow price can be obtained form the solver. 
    Each row corresponds to a zone, and each column starting from the 3rd to the last is the total payment from each capacity reserve margin constraint. 
    As a reminder, GenX models the capacity reserve margin (aka capacity market) at the time-dependent level, and each constraint either stands for an overall market or a locality constraint.
"""
function write_reserve_margin_demand_response_saving(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    Z = inputs["Z"]     # Number of zonests
    SEG = inputs["SEG"]
    dfResDRSaving = DataFrame(Zone = 1:Z, AnnualSum = zeros(Z))
    for i in 1:inputs["NCapacityReserveMargin"]
        pariticpatingzone = zeros(Z)
        pariticpatingzone[findall(x -> x > 0, inputs["dfCapRes"][:, i])] .= 1
        resdrsaving = (transpose(value.(EP[:eDemandResponse])) .* pariticpatingzone) * dual.(EP[:cCapacityResMargin][i, :])
        if setup["ParameterScale"] == 1
            resdrsaving *= ModelScalingFactor^2
        end
        dfResDRSaving.AnnualSum .+= resdrsaving
        dfResDRSaving = hcat(dfResDRSaving, DataFrame([resdrsaving], [Symbol("CapRes_$i")]))
    end
    CSV.write(joinpath(path, "ReserveMarginDemandResponseSaving.csv"), dfResDRSaving)
    return dfResDRSaving
end
