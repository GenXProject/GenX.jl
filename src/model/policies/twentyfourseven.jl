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
	twentyfourseven!(EP::Model, inputs::Dict, setup::Dict)
"""
function twentyfourseven!(EP::Model, inputs::Dict, setup::Dict)
    dfGen = inputs["dfGen"]
    println("Twenty-four Seven Module")
    NumberofTFS = inputs["NumberofTFS"]
    if NumberofTFS > 1
        NumberofTFSPath = inputs["NumberofTFSPath"]
    end
    ALLGEN = collect(1:inputs["G"])
    STOR_ALL = inputs["STOR_ALL"]
    FLEX = inputs["FLEX"]
    T = inputs["T"]
    ## Define Variables
    @variable(EP, vEX[rpsh = 1:NumberofTFS, t = 1:T] >= 0) # excess
    @variable(EP, vSF[rpsh = 1:NumberofTFS, t = 1:T] >= 0) # shortfall, also known as gridsupply
    if NumberofTFS > 1
        @variable(EP, vTFSFlow_Sending[rpsh_path = 1:NumberofTFSPath, t = 1:T] >= 0) # positive flow from sending end to receiving end
        @variable(EP, vTFSFlow_Receiving[rpsh_path = 1:NumberofTFSPath, t = 1:T] >= 0) # positive flow from receiving end to sending end
    end

    ## Define Expressions
    # Total generation of power plant that participants in the TEAC/24x7 program
    @expression(EP, eCFE[rpsh = 1:NumberofTFS, t = 1:T], EP[:vZERO] + sum(dfGen[y, Symbol("RPSH_$rpsh")] * EP[:vP][y, t] for y in setdiff(ALLGEN, union(STOR_ALL, FLEX))))
    # Modified load: this is the load after the modification of the demand flexiblity and storage facilities;
    # In TEAC/24x7 framework, storage is at the load side
    @expression(EP, eModifiedload[rpsh = 1:NumberofTFS, t = 1:T], (inputs["TFS_Load"][t, rpsh] + EP[:vZERO]))
    if !isempty(STOR_ALL)
        @expression(EP, eTFSStorage[rpsh = 1:NumberofTFS, t = 1:T], sum(dfGen[y, Symbol("RPSH_$rpsh")] * (EP[:vP][y, t] - EP[:vCHARGE][y, t]) for y in STOR_ALL) - EP[:vZERO])
        EP[:eModifiedload] -= EP[:eTFSStorage]
    end
    if !isempty(FLEX)
        @expression(EP, eTFSDR[rpsh = 1:NumberofTFS, t = 1:T], sum(dfGen[y, Symbol("RPSH_$rpsh")] * (EP[:vCHARGE_FLEX][y, t] - EP[:vP][y, t]) for y in FLEX) - EP[:vZERO])
        EP[:eModifiedload] -= EP[:eTFSDR]
    end
    @expression(EP, eConsumedCFE[rpsh = 1:NumberofTFS, t = 1:T], EP[:eCFE][rpsh, t] - EP[:vEX][rpsh, t] + ((1 - inputs["TFS_SFDT"][t, rpsh]) * EP[:vSF][rpsh, t]))
    
    if NumberofTFS > 1
        # Net TEAC flow on a path is equal to the net of the flow in the opposite direction
        @expression(EP, eTFSFlow[rpsh_path = 1:NumberofTFSPath, t = 1:T], EP[:vTFSFlow_Sending][rpsh_path, t] - EP[:vTFSFlow_Receiving][rpsh_path, t])
        # The net export of a path is equal to the sum of outbound flow and the inbound flow
        @expression(EP, eTFSNetExport[rpsh = 1:NumberofTFS, t = 1:T], (sum(EP[:eTFSFlow][rpsh_path, t] for rpsh_path in findall(x -> x == rpsh, inputs["TFS_Network"][:, :From])) - 
                                                                        sum(EP[:eTFSFlow][rpsh_path, t] for rpsh_path in findall(x -> x == rpsh, inputs["TFS_Network"][:, :To]))))
        # The net export is taken out of the consumed CFE
        EP[:eConsumedCFE] -= EP[:eTFSNetExport]
        # This expression calcualte the friction cost on each path at each hour
        @expression(EP, eTFSTranscationCost[rpsh_path = 1:NumberofTFSPath, t = 1:T], ((EP[:vTFSFlow_Sending][rpsh_path, t] * inputs["TFS_Network"][rpsh_path, :HurdleRate_Forward]) +
                                                                                  (EP[:vTFSFlow_Receiving][rpsh_path, t] * inputs["TFS_Network"][rpsh_path, :HurdleRate_Backward])))
        # this expression calculate the annual friction cost on each path
        @expression(EP, eTFSAnnualTranscationCost[rpsh_path = 1:NumberofTFSPath], sum(EP[:eTFSTranscationCost][rpsh_path, t] * inputs["omega"][t] for t in 1:T))
        # this expression calculate the total friction cost on each path
        @expression(EP, eTFSTotalTranscationCost, sum(EP[:eTFSAnnualTranscationCost][rpsh_path] for rpsh_path in 1:NumberofTFSPath))
        EP[:eObj] += EP[:eTFSTotalTranscationCost]
    end
    
    ## Define constraints
    # Excess limit constraint
    @constraint(EP, cRPSH_Exceedlimit[rpsh = 1:NumberofTFS], sum(inputs["omega"][t] * EP[:vEX][rpsh, t] for t = 1:T) <= inputs["TFS"][rpsh, :RPSH_EXLIMIT] * sum(inputs["omega"][t] * EP[:eModifiedload][rpsh, t] for t = 1:T))
    # Shortfall Limit constraint, equivalent to Target Constraint below
    @constraint(EP, cRPSH_Shortfalllimit[rpsh = 1:NumberofTFS], sum(inputs["omega"][t] * inputs["TFS_SFDT"][t, rpsh] * EP[:vSF][rpsh, t] for t = 1:T) <= inputs["TFS"][rpsh, :RPSH_SFLIMIT] * sum(inputs["omega"][t] * EP[:eModifiedload][rpsh, t] for t = 1:T))
    # @constraint(EP, cRPSH_CFETarget[rpsh = 1:NumberofTFS], sum(inputs["omega"][t] * EP[:eConsumedCFE][rpsh, t] for t = 1:T) >= (1 - inputs["TFS"][rpsh, :RPSH_SFLIMIT]) * sum(inputs["omega"][t] * EP[:eModifiedload][rpsh, t] for t = 1:T))
    
    if NumberofTFS > 1
        # TEAC flow from the sending end to receiving end of a path must be lower than a predefined upper bound, like transmisison power flow
        @constraint(EP, cTFSFlow_Upperbound[rpsh_path = 1:NumberofTFSPath, t = 1:T], EP[:vTFSFlow_Sending][rpsh_path, t] <= inputs["TFS_Network"][rpsh_path, :MaxFlow_Forward])
        # TEAC flow from the sending end to receiving end of a path must be lower than the total CFE generation of the sending end; 
        # this constraint assumes the network is constructed in a bilateral way.
        @constraint(EP, cTFSFlow_Upperbound_byCFE[rpsh_path = 1:NumberofTFSPath, t = 1:T], EP[:vTFSFlow_Sending][rpsh_path, t] <= sum(EP[:eCFE][rpsh, t] for rpsh in inputs["TFS_Network"][findall(x -> x == rpsh_path, inputs["TFS_Network"][:, :RPSH_PathID]), :From]))
        # TEAC flow from the receiving end to sending end of a path must be lower than a predefined upper bound, like transmisison power flow
        @constraint(EP, cTFSFlow_Lowerbound[rpsh_path = 1:NumberofTFSPath, t = 1:T], EP[:vTFSFlow_Receiving][rpsh_path, t] <= inputs["TFS_Network"][rpsh_path, :MaxFlow_Backward])
        # TEAC flow from the receiving end to sending end of a path must be lower than the modified load of the receiving end;
        # this constraint assumes the network is constructed in a bilateral way.        
        @constraint(EP, cTFSFlow_Lowerbound_byModifiedLoad[rpsh_path = 1:NumberofTFSPath, t = 1:T], EP[:vTFSFlow_Receiving][rpsh_path, t] <= sum(EP[:eModifiedload][rpsh, t] for rpsh in inputs["TFS_Network"][findall(x -> x == rpsh_path, inputs["TFS_Network"][:, :RPSH_PathID]), :To]))
        # this is the hourly matching constraint accounting for the net export
        @constraint(EP, cRPSH_HourlyMatching[t = 1:T, rpsh = 1:NumberofTFS], -EP[:eModifiedload][rpsh, t] + EP[:eCFE][rpsh, t] - EP[:eTFSNetExport][rpsh, t] + EP[:vSF][rpsh, t] - EP[:vEX][rpsh, t] == 0)

    else
        # modified load cannot be lower than zero
        @constraint(EP, cModifiedloadLowerbound[rpsh = 1:NumberofTFS, t = 1:T], EP[:eModifiedload][rpsh, t] >= 0)
        # this is the hourly matching constraint
        @constraint(EP, cRPSH_HourlyMatching[t = 1:T, rpsh = 1:NumberofTFS], -EP[:eModifiedload][rpsh, t] + EP[:eCFE][rpsh, t] + EP[:vSF][rpsh, t] - EP[:vEX][rpsh, t] == 0)
    end
    return EP
end