@doc raw"""
	write_subsidy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting subsidy revenue earned if a generator specified `Min_Cap` is provided in the input file, or if a generator is subject to a Minimum Capacity Requirement constraint. The unit is \$.
"""
function write_subsidy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    G = inputs["G"]

    dfSubRevenue = DataFrame(Region = dfGen[!, :region], Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], Cluster = dfGen[!, :cluster], R_ID=dfGen[!, :R_ID], SubsidyRevenue = zeros(G))
    MIN_CAP = dfGen[(dfGen[!, :Min_Cap_MW].>0), :R_ID]
    dfSubRevenue.SubsidyRevenue[MIN_CAP] .= (value.(EP[:eTotalCap])[MIN_CAP]) .* (dual.(EP[:cMinCap][MIN_CAP])).data

    if setup["ParameterScale"] == 1
        dfSubRevenue.SubsidyRevenue *= ModelScalingFactor^2 #convert from Million US$ to US$
    end

    CSV.write(joinpath(path, "SubsidyRevenue.csv"), dfSubRevenue)
    return dfSubRevenue
end

