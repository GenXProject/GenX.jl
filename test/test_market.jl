module TestMarket
# see the test/market/README.md for more details on these tests.
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
    joinpath(scenarios_path, "one_tier_30.csv"),
    joinpath(scenarios_path, "two_tier_30_100.csv"),
    joinpath(scenarios_path, "two_tier_50_30.csv"),
]

for price_csv in price_csvs
    cp(price_csv, market_data_path; force=true)
    
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
        # no sales b/c $30/MWh is less than the LMP at all times
        @test JuMP.value(EP[:eMarketSalesBenefit]) ≈ 0
    end


    if endswith(price_csv, "two_tier_30_100.csv")
        @test sum(JuMP.value.(EP[:vMarketPurchaseMW][:, 1])) ≈ inputs[GenX.MARKET_LIMITS][1] * 8760.0
        # it's cheaper to make the gas gen bigger than buy $100/MWh energy
        @test sum(JuMP.value.(EP[:vMarketPurchaseMW][:, 2])) ≈ 0
        # no more prices at VoLL with the option to buy $100/MWh energy
        n_prices_100 = sum((lmp ≈ 100.0 for lmp in LMPs))
        @test n_prices_100 > 9
        n_prices_VoLL = sum((lmp ≈ inputs["Voll"][1] for lmp in LMPs))
        @test n_prices_VoLL == 0
        # no sales b/c $30/MWh is less than the LMP at all times
        @test JuMP.value(EP[:eMarketSalesBenefit]) ≈ 0
    end


    if endswith(price_csv, "two_tier_50_30.csv")
        # selling energy in every time step in tier 1
        @test sum(JuMP.value.(EP[:vMarketSaleMW][:, 1])) ≈ inputs[GenX.MARKET_LIMITS][1] * 8760.0
        # buying energy in every time step in tier 2
        @test sum(JuMP.value.(EP[:vMarketPurchaseMW][:, 2])) ≈ inputs[GenX.MARKET_LIMITS][2] * 8760.0

        market_costs = JuMP.value(EP[:eMarketPurchasesCost])
        @test market_costs ≈ inputs[GenX.MARKET_LIMITS][2] * 8760.0 * inputs[GenX.MARKET_PRICES][2][1]

        benefit = JuMP.value(EP[:eMarketSalesBenefit])
        @test benefit ≈ inputs[GenX.MARKET_PRICES][1][1] * 8760.0
    end

   
    rm(market_data_path)
end

end
