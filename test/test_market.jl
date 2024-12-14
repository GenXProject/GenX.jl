module TestMarket

using Test

include(joinpath(@__DIR__, "utilities.jl"))

# obj_true = 395.171391
test_path = "market"

# Define test inputs
genx_setup = Dict(
    "Market" => 1
)

# We run several tests with different market prices by copying the market_price_scenarios into
# system/Market_data.csv.
scenarios_path = joinpath(@__DIR__, "market", "market_price_scenarios")
market_data_path = joinpath(@__DIR__, "market", "system", "Market_data.csv")

price_csvs = [
    joinpath(scenarios_path, "one_tier_30.csv")
]

for price_csv in price_csvs
    cp(price_csv, market_data_path)
    
    # Run the case and get the objective value and tolerance
    EP, inputs, _ = redirect_stdout(devnull) do
        run_genx_case_testing(test_path, genx_setup)
    end

    # $30/MWh with 1 MW market limit means that every hour 1 MWh is purchased
    if endswith(price_csv, "one_tier_30.csv")
        @test JuMP.value(EP[:eMarketPurchasesCost]) / 30 ≈ 8760.0
    end

    obj_test = objective_value(EP)
    
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