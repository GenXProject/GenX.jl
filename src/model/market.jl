"""
    add_known_price_market_model(EP::Model, inputs::Dict, setup::Dict)

Given market price forecasts this method adds the constraints and objective terms to account for
energy market sales and purchases. For each price vector there is a MW limit of import capacity
meant to represent a transmission limit. The model is only allowed to sell into the first price
vector. 

TODO need to limit the selling quantity in relation to the buying quantity?

The inputs for this market model have the following columns:

    import_limit_MW_1, ..., import_limit_MW_N, price_per_MWh_1, ..., price_per_MWh_N

"""
function add_known_price_market_model!(EP::Model, inputs::Dict, setup::Dict)

        T = inputs["T"]     # Number of time steps (hours)
        Z = inputs["Z"]     # Number of zones

        if Z != 1
            throw(ErrorException("The market model is only implemented for single zone models."))
        end
        if setup["TimeDomainReduction"] == 1
            throw(ErrorException("TimeDomainReduction is not supported in the market model."))
        end

        M = length(inputs[MARKET_LIMITS])  # number of market price tiers

        # the market purchases are non-negative and no greater than the MARKET_LIMITS
        @variable(EP, 0 <= vMarketPurchaseMW[t = 1:T, z = 1:Z, m = 1:M] <= inputs[MARKET_LIMITS][m])

        # the market sales are non-negative and no greater than the MARKET_LIMITS for tier 1
        # NOTE need the z index to add to load balance convention
        @variable(EP, 0 <= vMarketSaleMW[t = 1:T, z=1:Z] <= inputs[MARKET_LIMITS][SELL_TIER])
        
        # Sum purchases across market tiers to add the purchases to the load balance
        # NOTE need the z index to add to load balance convention
        @expression(EP, eMarketPurchasesMWh[t = 1:T, z = 1:Z],
            sum(vMarketPurchaseMW[t, z, m] for m = 1:M)
        )

        @expression(EP, eMarketPurchasesCost,
            sum(
                vMarketPurchaseMW[t, z, m] * inputs[MARKET_PRICES][m][t]
            for t = 1:T, z = 1:Z, m = 1:M)
        )

        @expression(EP, eMarketSalesBenefit,
            sum(
                vMarketSaleMW[t, z] * inputs[MARKET_PRICES][SELL_TIER][t]
            for t = 1:T, z = 1:Z)
        )

        # add energy purchased to the load balance 
        add_similar_to_expression!(EP[:ePowerBalance], eMarketPurchasesMWh)
        add_similar_to_expression!(EP[:ePowerBalance], -vMarketSaleMW)

        add_to_expression!(EP[:eObj], eMarketPurchasesCost)
        add_to_expression!(EP[:eObj], -eMarketSalesBenefit)

        @debug("Market model added.")
end