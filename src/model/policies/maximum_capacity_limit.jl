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
	maximum_capacity_limit(EP::Model, inputs::Dict)
    The maximum capacity limit constraint allows for modeling maximum deployment of a certain technology or set of eligible technologies across the eligible model zones. 
    This is just the opposite of minimum capacity requirement constraint.
"""
function maximum_capacity_limit!(EP::Model, inputs::Dict, setup::Dict)

    println("Maxmimum Capacity limit Module")
    NumberOfMaxCapReqs = inputs["NumberOfMaxCapReqs"]
    G = inputs["G"]
    
    ### Expressions ###
    @expression(EP, eMaxCapRes[maxcap = 1:NumberOfMaxCapReqs], 0)

    @expression(EP, eMaxCapResInvest[maxcap = 1:NumberOfMaxCapReqs], sum(dfGen[y,Symbol("MaxCapTag_$maxcap")] * EP[:eTotalCap][y] for y in 1:G))
    # EP[:eMaxCapRes] += eMaxCapResInvest
    add_to_expression!.(EP[:eMaxCapRes], EP[:eMaxCapResInvest])

    ### Constraint ###
    @constraint(EP, cZoneMaxCapReq[maxcap = 1:NumberOfMaxCapReqs], EP[:eMaxCapRes][maxcap] <= inputs["MaxCapReq"][maxcap])

end