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

function write_zonal_energyconsumption(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    Z = inputs["Z"]     # Number of zones
    STOR_ALL = inputs["STOR_ALL"]
    dfEnergyConsumption = DataFrame(Zone = 1:Z, AnnualSum = zeros(Z), OriginalLoad = zeros(Z), NSE = zeros(Z), StorageLosses = zeros(Z), TransmissionLosses = zeros(Z))
    dfEnergyConsumption.OriginalLoad .+= (transpose(inputs["pD"]) * inputs["omega"])
    dfEnergyConsumption.NSE .-= (transpose(value.(EP[:eZonalNSE])) * inputs["omega"])
    if !isempty(STOR_ALL)
        dfEnergyConsumption.StorageLosses .+= vec(value.(EP[:eStorageLossByZone]))
    end
    if Z > 1
        dfEnergyConsumption.TransmissionLosses .+= vec(value.(EP[:eTransLossByZoneYear]))
    end
    if setup["ParameterScale"] == 1
        dfEnergyConsumption.OriginalLoad .*= ModelScalingFactor
        dfEnergyConsumption.NSE .*= ModelScalingFactor
        dfEnergyConsumption.StorageLosses .*= ModelScalingFactor
        dfEnergyConsumption.TransmissionLosses .*= ModelScalingFactor
    end
    dfEnergyConsumption.AnnualSum = dfEnergyConsumption.OriginalLoad + dfEnergyConsumption.NSE + dfEnergyConsumption.StorageLosses + dfEnergyConsumption.TransmissionLosses


    CSV.write(joinpath(path, "zonalenergyconsumption.csv"), dfEnergyConsumption)
    return dfEnergyConsumption
end
