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
	write_esr_transmissionlosspayment(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting the renewable/clean credit revenue earned by each generator listed in the input file. 
    GenX will print this file only when RPS/CES is modeled and the shadow price can be obtained form the solver. 
    Each row corresponds to a generator, and each column starting from the 6th to the second last is the total revenue earned from each RPS constraint. 
    The revenue is calculated as the total annual generation (if elgible for the corresponding constraint) multiplied by the RPS/CES price. 
    The last column is the total revenue received from all constraint. The unit is \$.
"""
function write_esr_transmissionlosspayment(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    Z = inputs["Z"]
    nESR = inputs["nESR"]
    dfESRtransmissionlosspayment = DataFrame(Zone=1:Z, AnnualSum=zeros(Z))
    tempesrpayment = zeros(Z, nESR)
    tempesrpayment = (inputs["dfESR"] .* (value.(EP[:eTransLossByZone]))) .* repeat(transpose(dual.(EP[:cESRShare])), Z, 1)
    if setup["ParameterScale"] == 1
        tempesrpayment = tempesrpayment * (ModelScalingFactor^2)
    end
    dfESRtransmissionlosspayment.AnnualSum .= vec(sum(tempesrpayment, dims=2))
    dfESRtransmissionlosspayment = hcat(dfESRtransmissionlosspayment, DataFrame(tempesrpayment, [Symbol("ESR_$i") for i in 1:nESR]))
    CSV.write(string(path, sep, "ESR_TransmissionlossPayment.csv"), dfESRtransmissionlosspayment)
    return dfESRtransmissionlosspayment
end
