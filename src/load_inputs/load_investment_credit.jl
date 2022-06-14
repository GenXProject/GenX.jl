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
	load_investment_credit(setup::Dict, path::AbstractString, inputs::Dict)

Function for reading input parameters related to investment credit (e.g., Investment Tax Credit)
"""
function load_investment_credit(setup::Dict, path::AbstractString, inputs::Dict)
	IC = DataFrame(CSV.File(joinpath(path, "Investment_credit.csv"), header=true), copycols=true)
	NICC = size(collect(skipmissing(IC[!,:InvestmentCreditCategory])),1)
	inputs["NumberofInvestmentCreditCategory"] = NICC
    inputs["ICPercentage"] = IC[!,:Investment_Credit_percentage]
	println("Investment_credit.csv Successfully Read!")

    if setup["ParameterScale"] ==1
        inputs["dfGen"][!,:IC_Excluder_Discharge_perMWyr] ./= ModelScalingFactor
        inputs["dfGen"][!,:IC_Excluder_Energy_perMWhyr] ./= ModelScalingFactor
        inputs["dfGen"][!,:IC_Excluder_Charge_perMWyr] ./= ModelScalingFactor
    end

	return inputs
end
