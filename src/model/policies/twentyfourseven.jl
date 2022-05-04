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
	twentyfourseven(EP::Model, inputs::Dict, setup::Dict)
"""
function twentyfourseven(EP::Model, inputs::Dict, setup::Dict)
    dfGen = inputs["dfGen"]
    println("Twenty-four Seven Module")
    NumberofTFS = inputs["NumberofTFS"]
    ALLGEN = collect(1:inputs["G"])
    STOR_ALL = inputs["STOR_ALL"]
    FLEX = inputs["FLEX"]
    T = inputs["T"]
    @variable(EP, vEX[rpsh = 1:NumberofTFS, t = 1:T] >= 0) # exceedance
    @variable(EP, vSF[rpsh = 1:NumberofTFS, t = 1:T] >= 0) # shortfall
    @expression(EP, eCFE[rpsh = 1:NumberofTFS, t = 1:T], sum(dfGen[y, Symbol("RPSH_$rpsh")] * EP[:vP][y, t] for y in setdiff(ALLGEN, union(STOR_ALL, FLEX))))
    @expression(EP, eModifiedload[rpsh = 1:NumberofTFS, t = 1:T], (inputs["TFS_Load"][t, rpsh] + EP[:vZERO]))
    if !isempty(STOR_ALL)
        @expression(EP, eTFSStorage[rpsh = 1:NumberofTFS, t = 1:T], sum(dfGen[y, Symbol("RPSH_$rpsh")] * (EP[:vP][y, t] - EP[:vCHARGE][y, t]) for y in STOR_ALL))
        EP[:eModifiedload] -= EP[:eTFSStorage]
    end
    if !isempty(FLEX)
        @expression(EP, eTFSDR[rpsh = 1:NumberofTFS, t = 1:T], sum(dfGen[y, Symbol("RPSH_$rpsh")] * (EP[:vCHARGE_FLEX][y, t] - EP[:vP][y, t]) for y in FLEX))
        EP[:eModifiedload] -= EP[:eTFSDR]
    end

    if (NumberofTFS) > 1
        NumberofTFSPath = inputs["NumberofTFSPath"]
        @variable(EP, vTFSFlow[rpsh_path = 1:NumberofTFSPath, t = 1:T])
        @variable(EP, vTFSFlow_Sending[rpsh_path = 1:NumberofTFSPath, t = 1:T] >= 0)
        @constraint(EP, cTFSFlow_Upperbound[rpsh_path = 1:NumberofTFSPath, t = 1:T], EP[:vTFSFlow_Sending][rpsh_path, t] <= inputs["TFS_Network"][rpsh_path, :MaxFlow_Forward])
        @constraint(EP, cTFSFlow_Upperbound_byCFE[rpsh_path = 1:NumberofTFSPath, t = 1:T], EP[:vTFSFlow_Sending][rpsh_path, t] <= sum(EP[:eCFE][rpsh, t] for rpsh in inputs["TFS_Network"][findall(x -> x == rpsh_path, inputs["TFS_Network"][:, :RPSH_PathID]), :From]))
        @variable(EP, vTFSFlow_Receiving[rpsh_path = 1:NumberofTFSPath, t = 1:T] >= 0)
        
        @constraint(EP, cTFSFlow_Lowerbound[rpsh_path = 1:NumberofTFSPath, t = 1:T], EP[:vTFSFlow_Receiving][rpsh_path, t] <= inputs["TFS_Network"][rpsh_path, :MaxFlow_Backward])
        @constraint(EP, cTFSFlow_Lowerbound_byModifiedLoad[rpsh_path = 1:NumberofTFSPath, t = 1:T], EP[:vTFSFlow_Receiving][rpsh_path, t] <= sum(EP[:eModifiedload][rpsh, t] for rpsh in inputs["TFS_Network"][findall(x -> x == rpsh_path, inputs["TFS_Network"][:, :RPSH_PathID]), :To]))
    
        @constraint(EP, cTFSFlowRelation[rpsh_path = 1:NumberofTFSPath, t = 1:T], EP[:vTFSFlow][rpsh_path, t] == EP[:vTFSFlow_Sending][rpsh_path, t] - EP[:vTFSFlow_Receiving][rpsh_path, t])
    
        @expression(EP, eTFSNetExport[rpsh = 1:NumberofTFS, t = 1:T], (sum(EP[:vTFSFlow][rpsh_path, t] for rpsh_path in findall(x -> x == rpsh, inputs["TFS_Network"][:, :From])) -
                                                                       sum(EP[:vTFSFlow][rpsh_path, t] for rpsh_path in findall(x -> x == rpsh, inputs["TFS_Network"][:, :To]))))
        @constraint(EP, cRPSH_HourlyMatching[t = 1:T, rpsh = 1:NumberofTFS], - EP[:eModifiedload][rpsh, t] + eCFE[rpsh, t] - EP[:eTFSNetExport][rpsh, t] + EP[:vSF][rpsh, t] - EP[:vEX][rpsh, t] == 0)
    
        
        @expression(EP, eTFSTranscationCost[rpsh_path = 1:NumberofTFSPath, t = 1:T], ((EP[:vTFSFlow_Sending][rpsh_path, t] * inputs["TFS_Network"][rpsh_path, :HurdleRate_Forward]) +
                                                                                  (EP[:vTFSFlow_Receiving][rpsh_path, t] * inputs["TFS_Network"][rpsh_path, :HurdleRate_Backward])))
        @expression(EP, eTFSAnnualTranscationCost[rpsh_path = 1:NumberofTFSPath], sum(EP[:eTFSTranscationCost][rpsh_path, t] * inputs["omega"][t] for t in 1:T))
        @expression(EP, eTFSTotalTranscationCost, sum(EP[:eTFSAnnualTranscationCost][rpsh_path] for rpsh_path in 1:NumberofTFSPath))
        EP[:eObj] += eTFSTotalTranscationCost
    else
        @constraint(EP, cModifiedloadLowerbound[rpsh = 1:NumberofTFS, t = 1:T], EP[:eModifiedload][rpsh, t] >= 0)
        @constraint(EP, cRPSH_HourlyMatching[t = 1:T, rpsh = 1:NumberofTFS], - EP[:eModifiedload][rpsh, t] + eCFE[rpsh, t] + EP[:vSF][rpsh, t] - EP[:vEX][rpsh, t] == 0)
    end

    @constraint(EP, cRPSH_Exceedlimit[rpsh = 1:NumberofTFS], sum(inputs["omega"][t] * vEX[rpsh, t] for t = 1:T) <= inputs["TFS"][rpsh, :RPSH_EXLIMIT] * sum(inputs["omega"][t] * EP[:eModifiedload][rpsh, t] for t = 1:T))
    @constraint(EP, cRPSH_Shortfalllimit[rpsh = 1:NumberofTFS], sum(inputs["omega"][t] * inputs["TFS_SFDT"][t, rpsh] * vSF[rpsh, t] for t = 1:T) <= inputs["TFS"][rpsh, :RPSH_SFLIMIT] * sum(inputs["omega"][t] * EP[:eModifiedload][rpsh, t] for t = 1:T))

    return EP
end