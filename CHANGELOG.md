# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## [0.3.7] - 2024-04-02

### Fixed

- Add check on COMMIT_ZONE set in write_costs (#507) 
- Access to eELOSSByZone expr before initialization (#541)
- Scaling of transmission losses in tlosses.csv (#622) 
- Correct tracking of current investment stage by SDDP (#628) 
- Computation of cumulative minimum capacity retirements in multistage GenX (#631)
- Modeling of hydro reservoir with long duration storage (#632)
- Update of starting transmission capacity in multistage GenX (#633)

## [0.3.6] - 2023-08-01

### Fixed

- Order of slack policy constraint declarations (#464)
- Sign error in the Maximum Capacity Requirement slack constraint term (#461)
- Remove outdated HiGHS setting `simplex_dualise_strategy` (#489)
- Fix bug in LDES outputs (#472)
- Updated README with new instructions for running GenX through Julia REPL terminal (#492)
- Fix factor of 0.5 when writing out transmission losses. (#480)
- Fix summation error when a set of hours is empty (in thermal_commit.jl).

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

