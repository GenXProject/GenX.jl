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
2. Add a $100/MWh price tier limited to 2.5 MW in all time steps and test that:
    - energy is purchased in every time step from the first tier
    - no energy is purchased from the second tier
    - prices are set to $100/MWh in some time steps
    - no prices are set to the VoLL
3. Model a two tier market with the first tier price greater than $40.7/MWh so that there is a
   benefit to selling energy up to the limit. And set the second tier price below $40.7/MWh so that
   there is a benefit of buying energy up to the limit. (Recall that the market tiers are proxies
   for transmission connections so buying in one tier and selling in another is normal.)

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


df = DataFrame(
    import_limit_MW_1 = vcat([1], fill(missing, 8759)), 
    import_limit_MW_2 = vcat([2.5], fill(missing, 8759)),
    price_per_MWh_1 = repeat([50.0], 8760),
    price_per_MWh_2 = repeat([30.0], 8760),
)
CSV.write("market_price_scenarios/two_tier_50_30.csv", df)

# make a price differential to test storage
hours = 1:24  # 24 hourly values
peak = 300    # Maximum value
min_val = 10  # Minimum value

# Amplitude and vertical shift
amplitude = (peak - min_val) / 2
vertical_shift = (peak + min_val) / 2

# Phase adjustment
peak_hour = 17
phase_shift = (peak_hour - 1) * 2π / 24  # Align the peak at the 17th hour

# Sine function
sin_price = vertical_shift .+ amplitude .* sin.(2π * (hours .- 1) / 24 .+ phase_shift)

df = DataFrame(
    import_limit_MW_1 = vcat([1], fill(missing, 8759)), 
    price_per_MWh_1 = repeat(sin_price, 365)
)
CSV.write("market_price_scenarios/sin_price.csv", df)

```