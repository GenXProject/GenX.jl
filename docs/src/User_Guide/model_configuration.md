# Model settings parameters

The first step in configuring a GenX model is to specify the model settings parameters. These parameters are specified in a `genx_settings.yml` file inside a `settings` folder which must be located in the current working directory. Settings include those related to model structure, solution strategy and outputs, policy constraints, and others. In particular:
- Model structure related settings parameters affect the formulation of the model constraints and objective function. 
- Computational performance related parameters affect the accuracy of the solution.
- Policy related parameters specify the policy type and policy goal. 
- Network related parameters specify settings related to transmission network expansion and losses.
Note that all settings parameters are case sensitive.

(Optional) The user can also select the output files that they want to export using the `output_settings.yml` file. This file containes a list of `yes/no` options for each output file, and should be located in the `settings` folder. By default, if `output_settings.yml` is not included, GenX will export all output files. 

The following tables summarize the model settings parameters and their default/possible values.

## 1. Model structure related settings parameters

|**Parameter** | **Description**|
| :------------ | :-----------|
|UCommit | Select technical resolution of of modeling thermal generators.|
||0 = no unit commitment.|
||1 = unit commitment with integer clustering.|
||2 = unit commitment with linearized clustering.|
|OperationalReserves | Flag for modeling operational reserves .|
||0 = No operational reserves considered. |
||1 = Consider regulation (primary) and spinning (secondary) reserves. |
|StorageLosses | Flag to account for storage related losses.|
||0 = VRE and CO2 constraints DO NOT account for energy lost. |
||1 = constraints account for energy lost. |
|TimeDomainReduction | 1 = Use time domain reduced inputs available in the folder with the name defined by settings parameter `TimeDomainReductionFolder`. If such a folder does not exist or it is empty, time domain reduction will reduce the input data and save the results there.|
||0 = Use the data in the main case folder; do not perform clustering.|
|VirtualChargeDischargeCost | Hypothetical cost of charging and discharging storage resources (in $/MWh).|
|StorageVirtualDischarge | Flag to enable contributions that a storage device makes to the capacity reserve margin without generating power.|
||1 = activate the virtual discharge of storage resources.|
||0 = do not activate the virtual discharge of storage resources.|
|LDSAdditionalConstraints | Flag to activate additional constraints for long duration storage resources to prevent violation of SoC limits in non-representative periods.|
||1 = activate additional constraints.|
||0 = do not activate additional constraints.|
|HourlyMatching| Constraint to match generation from clean sources with hourly consumption.|
||1 = Constraint is active.|
||0 = Constraint is not active.|
|HydrogenHourlyMatching | Flag to allow hydrogen production to contribute to the hourly clean supply matching constraint.|
||1 = Hydrogen production contributes to the hourly clean supply matching constraint.|
||0 = Hydrogen production does not contribute to the hourly clean supply matching constraint.|

## 2. Solution strategy

|**Parameter** | **Description**|
| :------------ | :-----------|
|ParameterScale | Flag to turn on parameter scaling wherein demand, capacity and power variables defined in GW rather than MW. This flag aides in improving the computational performance of the model. |
||1 = Scaling is activated. |
||0 = Scaling is not activated. |
|ObjScale| Parameter value to scale the objective function during optimization.|
|MultiStage | Model multiple planning stages |
||1 = Model multiple planning stages as specified in `multi_stage_settings.yml` |
||0 = Model single planning stage |
|ModelingToGenerateAlternatives | Modeling to Generate Alternative Algorithm. For details, see [here](https://genxproject.github.io/GenX/dev/additional_features/#Modeling-to-Generate-Alternatives)|
||1 = Use the algorithm. |
||0 = Do not use the algorithm. |
|ModelingtoGenerateAlternativeSlack | value used to define the maximum deviation from the least-cost solution as a part of Modeling to Generate Alternative Algorithm. Can take any real value between 0 and 1. |
|MGAAnnualGeneration| Flag to switch between different MGA formulations.|
||1 = Create constraint weighing annual generation.|
||0 = Create constraint without weighing annual generation.|
|MethodofMorris | Method of Morris algorithm |
||1 = Use the algorithm. |
||0 = Do not use the algorithm. |

## 3. Policy related

|**Parameter** | **Description**|
| :------------ | :-----------|
|CO2Cap | Flag for specifying the type of CO2 emission limit constraint.|
|| 0 = no CO2 emission limit|
|| 1 = mass-based emission limit constraint|
|| 2 = demand + rate-based emission limit constraint|
|| 3 = generation + rate-based emission limit constraint|
|EnergyShareRequirement | Flag for specifying regional renewable portfolio standard (RPS) and clean energy standard policy (CES) related constraints.|
|| Default = 0 (No RPS or CES constraints).|
|| 1 = activate energy share requirement related constraints. |
|CapacityReserveMargin | Flag for Capacity Reserve Margin constraints. |
|| Default = 0 (No Capacity Reserve Margin constraints)|
|| 1 = activate Capacity Reserve Margin related constraints |
|MinCapReq | Minimum technology carve out requirement constraints.|
|| 1 = if one or more minimum technology capacity constraints are specified|
|| 0 = otherwise|
|MaxCapReq | Maximum system-wide technology capacity limit constraints.|
|| 1 = if one or more maximum technology capacity constraints are specified|
|| 0 = otherwise|
|HydrogenMinimumProduction | Hydrogen production requirements from electrolyzers.|
|1 = Constraint is active.|
||0 = Constraint is not active.| 

## 4. Network related

|**Parameter** | **Description**|
| :------------ | :-----------|
|NetworkExpansion | Flag for activating or deactivating inter-regional transmission expansion.|
||1 = active|
||0 = modeling single zone or for multi-zone problems in which inter regional transmission expansion is not allowed.|
| DC\_OPF | Flag for using the DC-OPF formulation for calculating transmission line MW flows and imposing constraints.|
||1 = use DC-OPF formulation|
||0 = do not use DC-OPF formulation|
|Trans\_Loss\_Segments | Number of segments to use in piece-wise linear approximation of losses.|
||1: linear|
||>=2: piece-wise quadratic|
|IncludeLossesInESR | Flag for including transmission losses and storage losses as part of ESR.|
||1 = include losses in ESR|
||0 = do not include losses in ESR|

## 5. Outputs

|**Parameter** | **Description**|
| :------------ | :-----------|
|PrintModel | Flag for printing the model equations as .lp file.|
||1 = including the model equation as an output|
||0 = the model equation won't be included as an output|
|WriteShadowPrices | Get the optimal values of dual variables of various model related constraints, including to estimate electricity prices, stored value of energy and the marginal CO2 prices.|
| WriteOutputs | Flag for writing the model outputs with hourly resolution or just the annual sum.|
|| "full" = write the model outputs with hourly resolution.|
|| "annual" = write only the annual sum of the model outputs.|
| OutputFullTimeSeries | Flag for writing the full time series of the model outputs.|
||1 = write the full time series of the model outputs.|
||0 = write only the reduced time series of the model outputs.|
| OutputFullTimeSeriesFolder | Name of the folder where the full time series of the model outputs will be stored inside the results directory (default: Full_TimeSeries).|
|OverwriteResults | Flag for overwriting the output results from the previous run.|
||1 = overwrite the results.|
||0 = do not overwrite the results.|

## 6. Solver related

|**Parameter** | **Description**|
| :------------ | :-----------|
|Solver | OPTIONAL name of solver. Default is "HiGHS" effectively. It is necessary to set `Solver: "Gurobi"` when [reusing the same gurobi environment for multiple solves](https://github.com/jump-dev/Gurobi.jl?tab=readme-ov-file#reusing-the-same-gurobi-environment-for-multiple-solves).
|EnableJuMPStringNames | Flag to enable/disable JuMP string names to improve the performance.|
||1 = enable JuMP string names.|
||0 = disable JuMP string names.|
|ComputeConflicts | Flag to enable the computation of conflicts in case of infeasibility of the model (Note: the chosen solver must support this feature).|
||1 = enable the computation of conflicts.|
||0 = disable the computation of conflicts.|

## 7. Folder structure related

|**Parameter** | **Description**|
| :------------ | :-----------|
|SystemFolder | Name of the folder inside the current working directory where the input data for the system is stored (default = "system").|
|PoliciesFolder | Name of the folder inside the current working directory where the input data for policies is stored (default = "policies").|
|ResourcesFolder | Name of the folder inside the current working directory where the input data for resources is stored (default = "resources").|
|ResourcePoliciesFolder | Name of the folder inside the `ResourcesFolder` where the input data for resource policy assignments is stored (default = "policy_assignments").|
|TimeDomainReductionFolder | Name of the folder inside the current working directory where time domain reduced input data is stored.|

The next step in configuring a GenX model is to specify the solver settings parameters using a `[solver_name]_settings.yml` file inside the `settings` folder. The solver settings parameters are solver specific and are described in the following section.
