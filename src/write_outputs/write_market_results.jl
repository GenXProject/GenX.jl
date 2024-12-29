@doc raw"""
	write_market_results(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the market results.
"""
function write_market_results(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    M = length(inputs[MARKET_LIMITS])  # number of market price tiers

    mwh_purchases = Dict()
    for m=1:M
        mwh_purchases["total_purchases_mwh_tier_$m"] = sum(
            JuMP.value.(EP[:vMarketPurchaseMW][:, m,])
        )
    end
    mwh_purchases["total_purchases_mwh"] = sum(values(mwh_purchases))

    df = DataFrame(mwh_purchases)
    df[!, "total_mwh_sales"] = [sum(JuMP.value.(EP[:vMarketSaleMW][:, SELL_TIER]))]
    df[!, "total_sales_benefit"] = [JuMP.value(EP[:eMarketSalesBenefit])]
    df[!, "total_purchases_cost"] = [JuMP.value(EP[:eMarketPurchasesCost])]
    CSV.write(joinpath(path, "market_results.csv"), df)
end