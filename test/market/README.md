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
1. Set the market price to $100/MWh in all time steps and test for purchases in 9 time steps.
2. Set the market price to $30/MWh in all time steps with a purchase cap of 1 MW and test that 1 MWh
   is purchased in every hour.
3. Create a two-tier market with $30/MWh with 1 MW cap in the first tier and $50/MWh with 1 MW cap
   in the second tier and test that:
    - energy is purchased in every time step from the first tier
    - energy is purchased in nine time steps from the second tier