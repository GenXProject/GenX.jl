@doc raw"""
	write_market_results(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the market results.
"""
function write_market_results(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    M = length(inputs[MARKET_LIMITS])  # number of market price tiers
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    mwh_purchases = Dict()
    for m=1:M
        mwh_purchases["total_purchases_mwh_tier_$m"] = sum(
            JuMP.value.(EP[:vMarketPurchaseMW][:, :, m])
        ) * scale_factor
    end
    mwh_purchases["total_purchases_mwh"] = sum(values(mwh_purchases))

    df = DataFrame(mwh_purchases)
    df[!, "total_mwh_sales"] = [sum(JuMP.value.(EP[:vMarketSaleMW][:, SELL_TIER]))] * scale_factor
    df[!, "total_sales_benefit"] = [JuMP.value(EP[:eMarketSalesBenefit])] * scale_factor^2
    df[!, "total_purchases_cost"] = [JuMP.value(EP[:eMarketPurchasesCost])] * scale_factor^2
    CSV.write(joinpath(path, "market_results.csv"), df)
end