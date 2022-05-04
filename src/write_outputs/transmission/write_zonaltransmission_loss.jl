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

function write_zonal_transmission_losses(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of Zones

    dfZonalTransmissionLoss = DataFrame(Zone=1:Z, AnnualSum=zeros(Z))
    transmissionloss = 0.5 * value.(EP[:eTransLossByZone])
    if setup["ParameterScale"] == 1
        transmissionloss *= ModelScalingFactor
    end
    dfZonalTransmissionLoss.AnnualSum .= transmissionloss * inputs["omega"]
    dfZonalTransmissionLoss = hcat(dfZonalTransmissionLoss, DataFrame(transmissionloss, [Symbol("t$t") for t in 1:T]))
    auxNew_Names = [Symbol("Zone"); Symbol("AnnualSum"); [Symbol("t$t") for t in 1:T]]

    total = DataFrame(["Total" sum(dfZonalTransmissionLoss[!, :AnnualSum]) fill(0.0, (1, T))], auxNew_Names)
    total[:, 3:T+2] .= sum(transmissionloss, dims=1)
    
    dfZonalTransmissionLoss = vcat(dfZonalTransmissionLoss, total)

    CSV.write(joinpath(path, "zonaltransmissionlosses.csv"), dftranspose(dfZonalTransmissionLoss, false), writeheader=false)
    return dfZonalTransmissionLoss
end
