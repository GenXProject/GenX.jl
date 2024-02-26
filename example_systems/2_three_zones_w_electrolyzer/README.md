# Small New England: Three Zones with electrolyzer

**Electrolyzer** a one-year example with hourly resolution, contains zones representing Massachusetts, Connecticut, and Maine and is designed to show the electrolyzer feature in GenX. The sixteen represented resources include natural gas, solar PV, wind, electrolyzer and lithium-ion battery storage.

To run the model, first navigate to the example directory at `GenX/examples/SmallNewEngland_ThreeZones/Electrolyzer`:

`cd("examples/SmallNewEngland_ThreeZones/Electrolyzer")`
   
Next, ensure that your settings in `Settings/GenX_settings.yml` are correct. The default settings use time domain reduced input data (`TimeDomainReduction: 1`), and an energy square requirement as specified in the `Energy_share_requirement.csv` file. Other optional policies include minimum capacity requirements, a capacity reserve margin, and more.

Once the settings are confirmed, run the model with the `Run.jl` script in the example directory:

`include("Run.jl")`

Once the model has completed, results will write to the `Results` directory.
