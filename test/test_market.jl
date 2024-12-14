module TestMarket

using Test
include(joinpath(@__DIR__, "utilities.jl"))


test_path = "market"

# Get baseline results to test against
EP_no_market, _, _ = redirect_stdout(devnull) do
    run_genx_case_testing(test_path, Dict())
end
base_line_cost = JuMP.objective_value(EP_no_market)
base_line_LMPs = JuMP.dual.(EP_no_market[:cPowerBalance])


genx_setup = Dict(
    "Market" => 1
)

# We run several tests with different market prices by copying the market_price_scenarios into
# system/Market_data.csv.
scenarios_path = joinpath(@__DIR__, test_path, "market_price_scenarios")
market_data_path = joinpath(@__DIR__, test_path, "system", "Market_data.csv")

price_csvs = [
    joinpath(scenarios_path, "one_tier_30.csv")
]

for price_csv in price_csvs
    cp(price_csv, market_data_path)
    
    # Run the case and get the objective value and tolerance
    EP, inputs, _ = redirect_stdout(devnull) do
        run_genx_case_testing(test_path, genx_setup)
    end
    LMPs = JuMP.dual.(EP[:cPowerBalance])

    # $30/MWh with 1 MW market limit means that every hour 1 MWh is purchased
    # savings are the difference of sum(base_line_LMPs) and 8760 MWh * $30/MWh
    if endswith(price_csv, "one_tier_30.csv")
        market_costs = JuMP.value(EP[:eMarketPurchasesCost])
        @test all(price ≈ 30.0 for price in inputs[GenX.MARKET_PRICES][1])
        @test market_costs / inputs[GenX.MARKET_PRICES][1][1] ≈ 8760.0
        @test all((
            purchase ≈ inputs[GenX.MARKET_LIMITS][1] 
            for purchase in JuMP.value.(EP[:vMarketPurchaseMW])
        ))
        savings = sum(base_line_LMPs) - market_costs
        @test JuMP.objective_value(EP) + savings ≈ base_line_cost
    end
   
    rm(market_data_path)
end

# optimal_tol_rel = get_attribute(EP, "ipm_optimality_tolerance")
# optimal_tol = optimal_tol_rel * obj_test  # Convert to absolute tolerance

# # Test the objective value
# test_result = @test obj_test≈obj_true atol=optimal_tol

# # Round objective value and tolerance. Write to test log.
# obj_test = round_from_tol!(obj_test, optimal_tol)
# optimal_tol = round_from_tol!(optimal_tol, optimal_tol)
# write_testlog(test_path, obj_test, optimal_tol, test_result)


end