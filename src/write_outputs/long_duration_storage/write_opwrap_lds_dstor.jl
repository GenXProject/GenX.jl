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

function write_opwrap_lds_dstor(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    ## Extract data frames from input dictionary
    dfGen = inputs["dfGen"]
    W = inputs["REP_PERIOD"]     # Number of subperiods
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    STOR_LONG_DURATION = inputs["STOR_LONG_DURATION"]
    #Excess inventory of storage period built up during representative period w
    dfdStorage = DataFrame(Resource=inputs["RESOURCES"], Zone=dfGen[!, :Zone])
    dsoc = zeros(G, W)
    dsoc[STOR_LONG_DURATION, :] = value.(EP[:vdSOC][STOR_LONG_DURATION, :])
    dfdStorage = hcat(dfdStorage, DataFrame(dsoc, [Symbol("w$t") for t in 1:W]))
    CSV.write(joinpath(path, "dStorage.csv"), dftranspose(dfdStorage, false), writeheader=false)
end
