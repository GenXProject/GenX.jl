# test/market/
GenX inputs to test the market capability. 

For now only supporting/testing single stage and single zone.

General notes on the test scenario:
- The demand is set to 1 GW in every hour.
- Fuel cost is set to 5 $/MMBtu in all time steps.
- There is only one resource, a thermal generator.
- Without the market mode the LMP is $40.7/MWh in all but 9 time steps, 8 of which the cost is the
  VoLL of $9,000/MWh and 1 of which the cost is $4,053.30/MWh.

Based on the prices without the market we test a few cases:
1. Set the market price to $30/MWh in all time steps with a purchase cap of 1 MW and test that 1 MWh
   is purchased in every hour and more.
1. Add a $100/MWh price tier limited to 2.5 MW in all time steps and test that:
    - energy is purchased in every time step from the first tier
    - no energy is purchased from the second tier
    - prices are set to $100/MWh in some time steps
    - no prices are set to the VoLL

The test Market_data.csv were made like so:
```julia
using DataFrames
using CSV

df = DataFrame(
    import_limit_MW_1 = vcat([1], fill(missing, 8759)), 
    price_per_MWh_1 = repeat([30.0], 8760)
)
CSV.write("market_price_scenarios/one_tier_30.csv", df)


df = DataFrame(
    import_limit_MW_1 = vcat([1], fill(missing, 8759)), 
    import_limit_MW_2 = vcat([2.5], fill(missing, 8759)),
    price_per_MWh_1 = repeat([30.0], 8760),
    price_per_MWh_2 = repeat([100.0], 8760),
)
CSV.write("market_price_scenarios/two_tier_30_100.csv", df)

```