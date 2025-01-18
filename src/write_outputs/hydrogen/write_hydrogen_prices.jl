function write_hydrogen_prices(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    NumberOfH2DemandReqs = inputs["NumberOfH2DemandReqs"]
    dfHydrogenPrice = DataFrame(
        H2_Demand = [Symbol("H2_Demand_$h2demand") for h2demand in 1:NumberOfH2DemandReqs],
        Hydrogen_Price_Per_Tonne = convert(
            Array{Float64}, dual.(EP[:cZoneH2DemandReq]) ))
    CSV.write(joinpath(path, "hydrogen_prices.csv"), dfHydrogenPrice)

    return nothing
end
