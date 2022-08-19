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

function write_storagelosses(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    G = inputs["G"]
    STOR_ALL = inputs["STOR_ALL"]     # Number of transmission lines
    dfStorageLoss = DataFrame(Resource = inputs["RESOURCES"], AnnualSum = zeros(G))
    dfStorageLoss.AnnualSum[STOR_ALL] .+= value.(EP[:eELOSS][STOR_ALL]).data

    if setup["VreStor"] == 1
        VRE_STOR = inputs["VRE_STOR"]
        dfStorageLoss_VRE_STOR = DataFrame(Resource = inputs["RESOURCES_VRE_STOR"], AnnualSum = zeros(VRE_STOR))
        dfStorageLoss_VRE_STOR.AnnualSum .+= value.(EP[:eELOSS_VRE_STOR]).data
        dfStorageLoss = vcat(dfStorageLoss, dfStorageLoss_VRE_STOR)
    end

    if setup["ParameterScale"] == 1
        dfStorageLoss.AnnualSum .*= ModelScalingFactor
    end

    total = DataFrame(["Total" sum(dfStorageLoss[!, :AnnualSum])], [Symbol("Resource"); Symbol("AnnualSum")])
    dfStorageLoss = vcat(dfStorageLoss, total)

    CSV.write(joinpath(path, "storagelosses.csv"), dfStorageLoss)
    return dfStorageLoss
end
