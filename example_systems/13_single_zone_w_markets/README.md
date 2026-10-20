# Single Zone with Markets

A one-year example with hourly resolution, containing one zone (MA) representing Massachusetts. The three resources are natural gas, solar PV, and lithium-ion battery storage. The zone can buy from and sell to an external market, with import and export limits of 5,000 MW each, set in `Zones_markets.csv`. Buy and sell decisions depend on the hourly market prices in `Market_price.csv`.

Market emissions are specified in `Market_emissions.csv` as hourly CO<sub>2</sub> emission rates (tCO<sub>2</sub>/MWh) applied to energy imported from the market. Only imports are assigned emissions. Exports are not credited, because the emissions from exported energy are already counted at the generating resources within the zone, so including them again would double count.

To run the model, first navigate to the example directory:

- Using a Julia REPL:
```bash
$ julia
julia> cd("example_systems/12_single_zone_w_markets/")
```

- Using a terminal or command prompt:
```bash
$ cd example_systems/12_single_zone_w_markets/
```

Next, ensure that your settings in `settings/genx_settings.yml` are correct. The default settings use the solver `HiGHS`, time domain reduced input data (`TimeDomainReduction: 1`), the markets module (`Markets: 1`), and the minimum capacity requirement policy (`MinCapReq: 1`) as specified in `policies/Minimum_capacity_requirement.csv`. Other optional policies include a capacity reserve margin, an energy share requirement (such as renewable portfolio standard (RPS) or clean electricity standard (CES) policies), a CO2 emissions cap, and a maximum capacity requirement policy (see the documentation for more details). For this example, a rate-based carbon cap of 50 gCO<sub>2</sub> per kWh is specified in `policies/CO2_cap.csv`.

Once the settings are confirmed, run the model with the `Run.jl` script in the example directory:

- Using a Julia REPL (recommended):
```julia
julia> include("Run.jl")
```

- Using a terminal or command prompt:
```bash
$ julia Run.jl
```

Once the model has completed, results will be written to the `results` directory.