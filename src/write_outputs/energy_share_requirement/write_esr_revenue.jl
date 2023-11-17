@doc raw"""
	write_esr_revenue(path::AbstractString, inputs::Dict, setup::Dict, dfPower::DataFrame, dfESR::DataFrame)

Function for reporting the renewable/clean credit revenue earned by each generator listed in the input file. GenX will print this file only when RPS/CES is modeled and the shadow price can be obtained form the solver. Each row corresponds to a generator, and each column starting from the 6th to the second last is the total revenue earned from each RPS constraint. The revenue is calculated as the total annual generation (if elgible for the corresponding constraint) multiplied by the RPS/CES price. The last column is the total revenue received from all constraint. The unit is \$.
"""
function write_esr_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]
	dfESRRev = DataFrame(Region = dfGen[!,:region], Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], Cluster = dfGen[!,:cluster], AnnualSum = zeros(G))

	for i in 1:inputs["nESR"]
	    tempesrrevenue = zeros(G)
	    tempesrrevenue = (value.(EP[:vP]) * inputs["omega"]) .* dfGen[:, Symbol("ESR_$i")] .* dual.(EP[:cESRShare][i])
	    if setup["ParameterScale"] == 1
	        tempesrrevenue *= (ModelScalingFactor^2)
	    end
	    dfESRRev.AnnualSum .+= tempesrrevenue
	    dfESRRev = hcat(dfESRRev, DataFrame([tempesrrevenue], [Symbol("ESR_$i")]))
	end
	CSV.write(joinpath(path, "ESR_Revenue.csv"), dfESRRev)
	return dfESRRev
end
