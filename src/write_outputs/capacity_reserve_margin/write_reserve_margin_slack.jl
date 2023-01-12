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

function write_reserve_margin_slack(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    NCRM = inputs["NCapacityReserveMargin"]
    T = inputs["T"]     # Number of time steps (hours)
    dfResMar_slack = DataFrame(CRM_Constraint = [Symbol("CapRes_$res") for res = 1:NCRM], 
                                AnnualSum = value.(EP[:eCapResSlack_Year]),
                                Penalty = value.(EP[:eCCapResSlack]))
    temp_ResMar_slack = value.(EP[:vCapResSlack])
    if setup["ParameterScale"] == 1
        dfResMar_slack.AnnualSum .*= ModelScalingFactor # Convert GW to MW
        dfResMar_slack.Penalty .*= ModelScalingFactor^2 # Convert Million $ to $
        temp_ResMar_slack .*= ModelScalingFactor # Convert GW to MW
    end
    dfResMar_slack = hcat(dfResMar_slack, DataFrame(temp_ResMar_slack, [Symbol("t$t") for t in 1:T]))
    CSV.write(joinpath(path, "ReserveMargin_prices_and_penalties.csv"), dftranspose(dfResMar_slack, false), writeheader=false)
    return dfResMar_slack
end

