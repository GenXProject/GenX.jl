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
|TimeDomainReductionFolder | Name of the folder insie the current working directory where time domain reduced input data is stored.|
|VirtualChargeDischargeCost | Hypothetical cost of charging and discharging storage resources (in $/MWh).|

## 2. Solution strategy

|**Parameter** | **Description**|
| :------------ | :-----------|
|ParameterScale | Flag to turn on parameter scaling wherein demand, capacity and power variables defined in GW rather than MW. This flag aides in improving the computational performance of the model. |
||1 = Scaling is activated. |
||0 = Scaling is not activated. |
|MultiStage | Model multiple planning stages |
||1 = Model multiple planning stages as specified in `multi_stage_settings.yml` |
||0 = Model single planning stage |
|ModelingToGenerateAlternatives | Modeling to Generate Alternative Algorithm. For details, see [here](https://genxproject.github.io/GenX/dev/additional_features/#Modeling-to-Generate-Alternatives)|
||1 = Use the algorithm. |
||0 = Do not use the algorithm. |
|ModelingtoGenerateAlternativeSlack | value used to define the maximum deviation from the least-cost solution as a part of Modeling to Generate Alternative Algorithm. Can take any real value between 0 and 1. |
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

## 4. Network related

|**Parameter** | **Description**|
| :------------ | :-----------|
|NetworkExpansion | Flag for activating or deactivating inter-regional transmission expansion.|
||1 = active|
||0 = modeling single zone or for multi-zone problems in which inter regional transmission expansion is not allowed.|
|Trans\_Loss\_Segments | Number of segments to use in piece-wise linear approximation of losses.|
||1: linear|
||>=2: piece-wise quadratic|

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

The next step in configuring a GenX model is to specify the solver settings parameters using a `[solver_name]_settings.yml` file inside the `settings` folder. The solver settings parameters are solver specific and are described in the following section.
