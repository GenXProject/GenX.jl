# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added
- Add objective scaler for addressing problem ill-conditioning (#667)

## [0.4.0] - 2024-03-18

### Added
- Feature CO2 and fuel module (#536)
  Adds a fuel module which enables modeling of fuel usage via (1) a constant heat rate and (2)
  piecewise-linear approximation of heat rate curves.
  Adds a CO2 module that determines the CO2 emissions based on fuel consumption, CO2 capture
  fraction, and whether the feedstock is biomass.
- Enable thermal power plants to burn multiple fuels (#586)
- Feature electrolysis basic (#525)
  Adds hydrogen electrolyzer model which enables the addition of hydrogen electrolyzer
  demands along with optional clean supply constraints.
- Add ability of storage to contribute to capacity reserves (#475)
- Add Co-located VRE+Storage Module (#523)
- Add output for dual of capacity constraint (#473)
- Add PR template (#516)
- Validation ensures that resource flags (THERM, HYDRO, LDS etc) are self-consistent (#513).
- Maintenance formulation for thermal-commit plants (#556).
- Add new tests for GenX: three-zone, multi-stage, electrolyzer, VRE+storage,
  piecewise_fuel+CO2, and TDR (#563 and #578).
- Added a DC OPF method (#543) to calculate power flows across all lines
- Added write_operating_reserve_price_revenue.jl to compute annual operating reserve and regulation revenue.
  Added the operating reserve and regulation revenue to net revenue (PR # 611)
- Add functions to compute conflicting constraints when model is infeasible if supported by the solver (#624).
- New settings parameter, VirtualChargeDischargeCost to test script and VREStor example case. The PR 608 attempts to
  introduce this parameter as cost of virtual charging and discharging to avoid unusual results (#608).
- New settings parameter, StorageVirtualDischarge, to turn storage virtual charging and discharging off if desired by the user (#638).
- Add module to retrofit existing resources with new technologies (#600).
- Formatted the code and added a format check to the CI pipeline (#673).

### Fixed
- Set MUST_RUN=1 for RealSystemExample/small_hydro plants (#517).
  Previously these plants had no resource flag set, and so they did not contribute to the power balance.
  As these plants are now useful, the objective in these cases is slightly lower.
- Assign correct investment cost per stage in objective function initialization for multi-stage runs (#530)
- Fix name of Fixed_OM_Cost_Charge_per_MWyr when reading from Generators_data in multistage code. (#533)
  Previously there was a typo in this in the multistage code that led to a silent bug, which affects outputs,
  for anyone running non-myopic multistage GenX with asymmetric storage.
- Fix computation of cumulative minimum capacity retirements in multistage GenX (#514)
- Fix access of eELOSSByZone expr before initialization (#541)
- Correctly write unmet reserves (in reg_dn.csv) (#575)
- Correctly scale total reserves column (in reg_dn.csv) (#594)
- Add validation for `Reg_Max` and `Rsv_Max` columns in `Generators_data.csv` when `MUST_RUN` is set to 1 (#576)
- Fix scaling of transmission losses in write_transmission_losses.jl (#621)
- Fix cost assignment to virtual storage charge/discharge - issue #604 (#608)
- Fix modeling of hydro reservoir with long duration storage (#572).
- Fix update of starting transmission capacity in multistage GenX
- Fix write_status with UCommit = WriteShadowPrices = 1 (#645)

### Changed
- Use add_to_expression! instead of the += and -= operators for memory performance improvements (#498).
- Generally, 'demand' is now used where (electrical) 'load' was used previously (#397).
- `Load_data.csv` is being renamed to `Demand_data.csv`.
- `Load_MW_z*` columns in that file are renamed to `Demand_MW_z*`.
- In `Reserves.csv`, `Reg_Req_Percent_Load` and `Rsv_Req_Percent_Load` are renamed to `..._Demand`.
- `Load` and `LoadWeight` keys in the `time_domain_reduction_settings.yml` file are renamed to `Demand`, `DemandWeight`.
- The `New_Build` column in `Generators_data.csv` has been separated into two: `New_Build` and `Can_Retire` (#392).
  Values in each column are {0,1}.
- Separate proprietary JuMP solvers from the GenX package.
  This allows users of Gurobi or CPLEX to use them without modifying
  the source code of the GenX package directly. This is a key step in publishing
  GenX as a proper Julia package. This does require change to the Run.jl files,
  to specify the solver. (#531)
- In the examples, change Reg_Max and Rsv_Max of any MUST_RUN generators to 0.
  This mitigates but does not fully fix (#576).
- Expressions of virtual charging and discharging costs in storage_all.jl and vre_stor.jl
- The input file `Generators_data.csv` has been split into different files, one for each type of generator.
  The new files are: `Thermal.csv`, `Hydro.csv`, `Vre.csv`, `Storage.csv`, `Flex_demand.csv`, `Must_run.csv`,
  `Electrolyzer.csv`, and `Vre_stor.csv`. The examples have been updated, and new tests have been added to
  check the new data format (#612).
- The settings parameter `Reserves` has been renamed to `OperationalReserves`, `Reserves.csv` to
  `Operational_reserves.csv`, and the `.jl` files contain the word `reserves` have been renamed to
  `operational_reserves` (#641).
- New folder structure for a GenX case. The input files are now organized in the following folders: `settings`, 
  `policies`, `resources` and `system`. The examples and tests have been updated to reflect this change. 
- New folder structure implemented for `example_system`. This folder now consists of nine separate folders each pertaining to a different case study example,
  ranging from the ISONE three zones, with singlestage, multistage, electrolyzers, all the way to the 9 bus IEEE case for running DC-OPF.

### Deprecated
- The above `load` keys, which generally refer to electrical demand, are being deprecated.
  Users should update their case files.
  For now this is done in a backward-compatible manner, and @info reminders are written to the log to prompt the user to update.
  "Load" now typically refers only to the transferrence of data from files to memory,
  except for a few places such as the common term "value of lost load" which refers to non-served demand (#397).
- `New_Build = -1` in `Generators_data.csv`: instead, use `New_Build = 0` and `Can_Retire = 0`.
- The matrix-style input of the grid for Network.csv is deprecated in favor a column-style input.
  Instead of columns z1, z2, ... with entries -1, 0, 1, use two columns: Start_Zone, End_Zone (#591).

## [0.3.6] - 2023-08-01

### Fixed

- Order of slack policy constraint declarations (#464)
- Sign error in the Maximum Capacity Requirement slack constraint term (#461)
- Remove outdated HiGHS setting `simplex_dualise_strategy` (#489)
- Fix bug in LDES outputs (#472)
- Updated README with new instructions for running GenX through Julia REPL terminal (#492)
- Fix factor of 0.5 when writing out transmission losses. (#480)
- Fix summation error when a set of hours is empty (in thermal_commit.jl).
- Fix access to eELOSSByZone expr before initialization (#541)
- Fix modeling of hydro reservoir with long duration storage (#572).
- Fix computation of cumulative minimum capacity retirements in multistage GenX (#514)
- Fix update of starting transmission capacity in multistage GenX

### Changed

- Eliminate 'Axis contains one element' warning (seen when LDS is used) by combining two constraints (#496).

## [0.3.5] - 2023-05-18

### Added

- Added ability to apply run_timedomainreduction to multistage problems (#443).
- Added a description of how to use time domain reduction (#426).
- Validation: against trying to perform time domain reduction (clustering)
  on data which has already been clustered.
- This changelog (#424).

### Fixed

- Added ability for CPLEX handle the Pre_Solve key (#467).
- run_timedomainreduction did not support multi-stage problems (#441).
- Not having a changelog (#423).

### Changed

- The columns `Rep_Periods`, `Timesteps_per_Rep_Period`, and `Sub_Weights` are now required in `Load_data.csv`
  for all cases (#426).

### Removed

- The settings key `OperationsWrapping`. Its functionality has now been folded into the
  `TimeDomainReduction` setting. Using the key now will print a gentle warning (#426).

## [0.3.4] - 2023-04-28

### Added

- Validation of the time basis in `load_data.csv` (#413).
- Arbitrary option keys can be passed to Solvers (#356).
- Validation for OperationWrapping and TimeDomainReduction settings (#337).
- Ability to use *'slack variables'* to violate policy constraints---at a cost (#328, #435).
- Documented minimum up & down-time constraints (#324).
- Validation preventing two columns of input data with the same name (#309).
- Fuel type `None` is no longer need to be listed as a column in `fuels_data.csv`, e.g. for solar panels (#303).
- Non-varying generators (e.g. thermal generators) no longer need to be listed in `generators_variability.csv` (#303).
- Ability to load the transmission network representation from lists rather than a matrix (#292).
- Maximum Capacity Requirement *policy constraint*.
- New `run_genx_case!` function for use in scripts.
- New `run_timedomainreduction!` function for pre-clustering a case.
- Improved documentation.

### Fixed

- Corrected the interaction of Reserves and Regulation policies with ramp rates (#415).
- Removed the useless `MinCapTag` column from examples (#380).
- Removed invalid `BarObjRng` key from gurobi settings (#374).
- Default `crossover` or `run_crossover` settings (#363).
- HYDRO resources now allow the period map to be loaded (#362).
- Numbering in documentation (#330).
- Correct scaling of emission outputs (#322).
- Add transmission losses to ESR constraints (#320).
- Author's name spelling in docs (#317).
- Unset executable bits on files (#297).
- Morris method example now runs.
- Various other settings issues with example cases.

### Changed

- Simplified the `Simple_Test_Case` example (#414).
- SmallNewEngland/Onezone example now uses linearized unit committment by default (#404).
- Removed the unused dependency BenchmarkTools (#381).

### Removed

- The unmaintained MonteCarlo code (#357).
- License blocks from most file headers (#353).
- Extra `LDS` columns from several examples (#312).
- SCIP from the Project and from documentation.

