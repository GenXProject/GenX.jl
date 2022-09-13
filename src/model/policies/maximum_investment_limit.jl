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
	maximum_investment_limit!(EP::Model, inputs::Dict)
    The maximum capacity limit constraint allows for modeling maximum investment 
        of a certain technology or set of eligible technologies across 
        the eligible model zones. 
"""
function maximum_investment_limit!(EP::Model, inputs::Dict, setup::Dict)

    println("Maxmimum Investment limit Module")
    NoMaxReq = inputs["NumberOfMaxInvReq"]
    G = inputs["G"]
    dfGen = inputs["dfGen"]
    ### Variable ###
    @variable(EP, vMaxInv_slack[maxinv = 1:NoMaxReq] >=0)

    ### Expressions ###
    @expression(EP, eCMaxInv_slack[maxinv = 1:NoMaxReq], 
        inputs["MaxInvPriceCap"][maxinv] * EP[:vMaxInv_slack][maxinv])
    @expression(EP, eTotalCMaxInv_slack, 
        sum(EP[:eCMaxInv_slack][maxinv] for maxinv = 1:NoMaxReq))
    add_to_expression!(EP[:eObj], EP[:eTotalCMaxInv_slack])

    @expression(EP, eMaxInvRes[maxinv = 1:NoMaxReq], 1*EP[:vZERO])

    @expression(EP, eMaxInvResInvest[maxinv = 1:NoMaxReq], 
        sum(dfGen[y,Symbol("MaxInvTag_$maxinv")] * EP[:eInvCap][y] for y in 1:G))
    add_to_expression!.(EP[:eMaxInvRes], EP[:eMaxInvResInvest])

    ### Constraint ###
    @constraint(EP, cZoneMaxInvReq[maxinv = 1:NoMaxReq], 
        EP[:eMaxInvRes][maxinv] <= (inputs["MaxInvReq"][maxinv] + 
            EP[:vMaxInv_slack][maxinv]))

end