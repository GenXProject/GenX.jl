# GenX Database Documentation

## 1 Model setup parameters

Model settings parameters are specified in a `GenX_Settings.yml` file which should be located in the current working directory (or to specify an alternative location, edit the `settings_path` variable in your `Run.jl` file). Settings include those related to model structure, solution strategy and outputs, policy constraints, and others. Model structure related settings parameter affects the formulation of the model constraint and objective functions. Computational performance related parameters affect the accuracy of the solution. Policy related parameters specify the policy type and policy goal. Network related parameters specify settings related to transmission network expansion and losses. Note that all settings parameters are case sensitive.

###### Table 1a: Summary of the Model settings parameters
---
|**Settings Parameter** | **Description**|
| :------------ | :-----------|
|**Model structure related**||
|OperationWrapping | Select temporal resolution for operations constraints.|
||0 = Models intra-annual operations as a single contiguous period. Inter-temporal constraint are defined based on linking first time step with the last time step of the year.|
||1 = Models intra-annual operations using multiple representative periods. Inter-temporal constraints are defined based on linking first time step with the last time step of each representative period.|
|LongDurationStorage | Select whether inter-period energy exchange allowed for storage technologies.|
||0= inter-period energy exchange not allowed.|
||1 = inter-period energy exchange allowed.|
|TimeDomainReduction | 1 = Use time domain reduced inputs available in the folder with the name defined by settings parameter TimeDomainReduction Folder. If such a folder does not exist or it is empty, time domain reduction will reduce the input data and save the results in the folder with this name. These reduced inputs are based on full input data provided by user in `Load_data.csv`, `Generators_variability.csv`, and `Fuels_data.csv`.|
||0 = Use full input data as provided.|
|TimeDomainReductionFolder | Name of the folder where time domain reduced input data is accessed and stored.|
|UCommit | Select technical resolution of of modeling thermal generators.|
||0 = no unit commitment.|
||1 = unit commitment with integer clustering.|
||2 = unit commitment with linearized clustering.|
|NetworkExpansion | Flag for activating or deactivating inter-regional transmission expansion.|
||1 = active|
||0 = modeling single zone or for multi-zone problems, inter regional transmission expansion is not allowed.|
|Trans\_Loss\_Segments | Number of segments to use in piece-wise linear approximation of losses.|
||1 = linear|
||>=2 = piece-wise quadratic|
|Reserves | Flag for modeling operating reserves .|
||0 = no operating reserves |
||1 regulation (primary) and spinning (secondary) reserves |
|StorageLosses | Flag to account for storage related losses.|
||0 = VRE and CO2 constraint DO NOT account for energy lost. |
||1 = constraint DO account for energy lost. |
|**Policy related**|
|EnergyShareRequirement | Flag for specifying regional renewable portfolio standard (RPS) and clean energy standard policy (CES) related constraints.|
|| Default = 0 (No RPS or CES constraints).|
|| 1 = activate energy share requirement related constraints. |
|CO2Cap | Flag for specifying the type of CO2 emission limit constraint.|
|| 0 = no CO2 emission limit|
|| 1 = mass-based emission limit constraint|
|| 2 = load + rate-based emission limit constraint|
|| 3 = generation + rate-based emission limit constraint|
|CapacityReserveMargin | Flag for Capacity Reserve Margin constraints. |
|| Default = 0 (No Capacity Reserve Margin constraints)|
|| 1 = activate Capacity Reserve Margin related constraints |
|MinCapReq | Minimum technology carve out requirement constraints.|
|| 1 = if one or more minimum technology capacity constraints are specified|
|| 0 = otherwise|
|**Solution strategy and outputs**||
|Solver | Solver name is case sensitive (CPLEX, Gurobi, clp). |
|ParameterScale | Flag to turn on parameter scaling wherein load, capacity and power variables defined in GW rather than MW. This flag aides in improving the computational performance of the model. |
||1 = Scaling is activated. |
||0 = Scaling is not activated. |
|ModelingToGenerateAlternatives | Modeling to Generate Alternative Algorithm. |
||1 = Use the algorithm. |
||0 = Do not use the algorithm. |
|ModelingtoGenerateAlternativeSlack | value used to define the maximum deviation from the least-cost solution as a part of Modeling to Generate Alternative Algorithm. Can take any real value between 0 and 1. |
|WriteShadowPrices | Get dual of various model related constraints, including to estimate electricity prices, stored value of energy and the marginal CO2 prices.|
|**Miscellaneous**|
|PrintModel | Flag for printnig the model equations as .lp file.|
||1= including the model equation as an output|
||0 for the model equation not being included as an output|
|MacOrWindows | Set to either Mac (also works for Linux) or Windows to ensure use of proper file directory separator \ or /.|

Additionally, Solver related settings parameters are specified in the appropriate solver settings .yml file (e.g. `gurobi_settings.yml` or `cplex_settings.yml`), which should be located in the current working directory (or to specify an alternative location, edit the `solver_settings_path` variable in your Run.jl file). Note that GenX supplies default settings for most solver settings in the various solver-specific functions found in the /src/configure_solver/ directory. To overwrite default settings, you can specify the below Solver specific settings. Note that appropriate solver settings are specific to each solver.

###### Table 1b: Summary of the Solver settings parameters
---
|**Settings Parameter** | **Description**|
| :------------ | :-----------|
|**Solver settings**||
|Method | Algorithm used to solve continuous models or the root node of a MIP model. Generally, barrier method provides the fastest run times for real-world problem set.|
|| CPLEX: CPX\_PARAM\_LPMETHOD - Default = 0; See [link](https://www.ibm.com/docs/en/icos/20.1.0?topic=parameters-algorithm-continuous-linear-problems) for more specifications.|
|| Gurobi: Method - Default = -1; See [link](https://www.gurobi.com/documentation/8.1/refman/method.html) for more specifications.|
|| clp: SolveType - Default = 5; See [link](https://www.coin-or.org/Doxygen/Clp/classClpSolve.html) for more specifications.|
|BarConvTol | Convergence tolerance for barrier algorithm.|
|| CPLEX: CPX\_PARAM\_BAREPCOMP - Default = 1e-8; See [link](https://www.ibm.com/docs/en/icos/12.8.0.0?topic=parameters-convergence-tolerance-lp-qp-problems) for more specifications.|
|| Gurobi: BarConvTol - Default = 1e-8; See [link](https://www.gurobi.com/documentation/8.1/refman/barconvtol.html)link for more specifications.|
|Feasib\_Tol | All constraints must be satisfied as per this tolerance. Note that this tolerance is absolute.|
|| CPLEX: CPX\_PARAM\_EPRHS - Default = 1e-6; See [link](https://www.ibm.com/docs/en/icos/20.1.0?topic=parameters-feasibility-tolerance) for more specifications.|
|| Gurobi: FeasibilityTol - Default = 1e-6; See [link](https://www.gurobi.com/documentation/9.1/refman/feasibilitytol.html) for more specifications.|
|| clp: PrimalTolerance - Default = 1e-7; See [link](https://www.coin-or.org/Clp/userguide/clpuserguide.html) for more specifications.|
|| clp: DualTolerance - Default = 1e-7; See [link](https://www.coin-or.org/Clp/userguide/clpuserguide.html) for more specifications.|
|Optimal\_Tol | Reduced costs must all be smaller than Optimal\_Tol in the improving direction in order for a model to be declared optimal.|
|| CPLEX: CPX\_PARAM\_EPOPT - Default = 1e-6; See [link](https://www.ibm.com/docs/en/icos/12.8.0.0?topic=parameters-optimality-tolerance) for more specifications.|
|| Gurobi: OptimalityTol - Default = 1e-6; See [link](https://www.gurobi.com/documentation/8.1/refman/optimalitytol.html) for more specifications.|
|Pre\_Solve | Controls the presolve level.|
|| Gurobi: Presolve - Default = -1; See [link](https://www.gurobi.com/documentation/8.1/refman/presolve.html) for more specifications.|
|| clp: PresolveType - Default = 5; See [link](https://www.coin-or.org/Doxygen/Clp/classClpSolve.html) for more specifications.|
|Crossover | Determines the crossover strategy used to transform the interior solution produced by barrier algorithm into a basic solution.|
|| CPLEX: CPX\_PARAM\_SOLUTIONTYPE - Default = 2; See [link](https://www.ibm.com/docs/en/icos/12.8.0.0?topic=parameters-optimality-tolerance) for more specifications.|
|| Gurobi: Crossover - Default = 0; See [link](https://www.gurobi.com/documentation/9.1/refman/crossover.html#:~:text=Use%20value%200%20to%20disable,interior%20solution%20computed%20by%20barrier.) for more specifications.|
|NumericFocus | Controls the degree to which the code attempts to detect and manage numerical issues.|
|| CPLEX: CPX\_PARAM\_NUMERICALEMPHASIS - Default = 0; See [link](https://www.ibm.com/docs/en/icos/12.8.0.0?topic=parameters-numerical-precision-emphasis) for more specifications.|
|| Gurobi: NumericFocus - Default = 0; See [link](https://www.gurobi.com/documentation/9.1/refman/numericfocus.html) for more specifications.|
|TimeLimit | Time limit to terminate the solution algorithm, model could also terminate if it reaches MIPGap before this time.|
|| CPLEX: CPX\_PARAM\_TILIM- Default = 1e+75; See [link](https://www.ibm.com/docs/en/icos/12.8.0.0?topic=parameters-optimizer-time-limit-in-seconds) for more specifications.|
|| Gurobi: TimeLimit - Default = infinity; See [link](https://www.gurobi.com/documentation/9.1/refman/timelimit.html) for more specifications.|
|| clp: MaximumSeconds - Default = -1; See [link](https://www.coin-or.org/Doxygen/Clp/classClpModel.html) for more specifications.|
|MIPGap | Optimality gap in case of mixed-integer program.|
|| CPLEX: CPX\_PARAM\_EPGAP- Default = 1e-4; See [link](https://www.ibm.com/docs/en/icos/20.1.0?topic=parameters-relative-mip-gap-tolerance) for more specifications.|
|| Gurobi: MIPGap - Default = 1e-4; See [link](https://www.gurobi.com/documentation/9.1/refman/mipgap2.html) for more specifications.|
|DualObjectiveLimit | When using dual simplex (where the objective is monotonically changing), terminate when the objective exceeds this limit.|
|| clp: DualObjectiveLimit - Default = 1e308; See [link](https://www.coin-or.org/Doxygen/Clp/classClpModel.html) for more specifications.|
|MaximumIterations | Terminate after performing this number of simplex iterations.|
|| clp: MaximumIterations - Default = 2147483647; See [link](https://www.coin-or.org/Doxygen/Clp/classClpModel.html) for more specifications.|
|LogLevel | Set to 1, 2, 3, or 4 for increasing output. Set to 0 to disable output.|
|| clp: logLevel - Default = 1; See [link](https://www.coin-or.org/Doxygen/Clp/classClpModel.html) for more specifications.|
|| cbc: logLevel - Default = 1; See [link](https://www.coin-or.org/Doxygen/Cbc/classCbcModel.html#a244a08213674ce52ddcf33ab4ff53380a185d42e67d2c4cb7b79914c0ed322b5f) for more specifications.|
|InfeasibleReturn | Set to 1 to return as soon as the problem is found to be infeasible (by default, an infeasibility proof is computed as well).|
|| clp: InfeasibleReturn - Default = 0; See [link](https://www.coin-or.org/Doxygen/Clp/classClpModel.html) for more specifications.|
|Scaling | Sets or unsets scaling; 0 -off, 1 equilibrium, 2 geometric, 3 auto, 4 dynamic(later).|
|| clp: Scaling - Default = 3; See [link](https://www.coin-or.org/Doxygen/Clp/classClpModel.html) for more specifications.|
|Perturbation | Perturbs problem; Switch on perturbation (50), automatic (100), don't try perturbing (102).|
|| clp: Perturbation - Default = 3; See [link](https://www.coin-or.org/Doxygen/Clp/classClpModel.html) for more specifications.|
|maxSolutions | Terminate after this many feasible solutions have been found.|
|| cbc: maxSolutions - Default = -1; See [link](https://www.coin-or.org/Doxygen/Cbc/classCbcModel.html#a244a08213674ce52ddcf33ab4ff53380a185d42e67d2c4cb7b79914c0ed322b5f) for more specifications.|
|maxNodes | Terminate after this many branch-and-bound nodes have been evaluated|
|| cbc: maxNodes - Default = -1; See [link](https://www.coin-or.org/Doxygen/Cbc/classCbcModel.html#a244a08213674ce52ddcf33ab4ff53380a185d42e67d2c4cb7b79914c0ed322b5f) for more specifications.|
| allowableGap | Terminate after optimality gap is less than this value (on an absolute scale)|
|| cbc: allowableGap - Default = -1; See [link](https://www.coin-or.org/Doxygen/Cbc/classCbcModel.html#a244a08213674ce52ddcf33ab4ff53380a185d42e67d2c4cb7b79914c0ed322b5f) for more specifications.|
|ratioGap | Terminate after optimality gap is smaller than this relative fraction.|
|| cbc: ratioGap - Default = Inf; See [link](https://www.coin-or.org/Doxygen/Cbc/classCbcModel.html#a244a08213674ce52ddcf33ab4ff53380a185d42e67d2c4cb7b79914c0ed322b5f) for more specifications.|
|threads | Set the number of threads to use for parallel branch & bound.|
|| cbc: threads - Default = 1; See [link](https://www.coin-or.org/Doxygen/Cbc/classCbcModel.html#a244a08213674ce52ddcf33ab4ff53380a185d42e67d2c4cb7b79914c0ed322b5f) for more specifications.|


## 2 Inputs

All input files are in CSV format. Running the GenX model requires a minimum of five input files. Additionally, the user may need to specify five more input files based on model configuration and type of scenarios of interest. Names of the input files and their functionality is given below. Note that names of the input files are case sensitive.


###### Table 2: Summary of the input files
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|**Mandatory Files**||
|Fuels\_data.csv |Specify fuel type, CO2 emissions intensity, and time-series of fuel prices. |
|Network.csv |Specify network topology, transmission fixed costs, capacity and loss parameters.|
|Load\_data.csv |Specify time-series of load profiles for each model zone, weights for each time step, load shedding costs, and optional time domain reduction parameters.|
|Generators\_variability.csv |Specify time-series of capacity factor/availability for each resource.|
|Generators\_data.csv |Specify cost and performance data for generation, storage and demand flexibility resources.|
|**Settings-specific Files**||
|Reserves.csv |Specify operational reserve requirements as a function of load and renewables generation and penalty for not meeting these requirements.|
|Energy\_share\_requirement.csv |Specify regional renewable portfolio standard and clean energy standard style policies requiring minimum energy generation from qualifying resources.|
|CO2\_cap.csv |Specify regional CO2 emission limits.|
|Capacity\_reserve\_margin.csv |Specify regional capacity reserve margin requirements.|
|Minimum\_capacity\_requirement.csv |Specify regional minimum technology capacity deployment requirements.|



### 2.1 Mandatory input data


#### 2.1.1 Fuels\_data.csv

• **First row:** names of all fuels used in the model instance which should match the labels used in `Fuel` column in the `Generators_data.csv` file. For renewable resources or other resources that do not consume a fuel, the name of the fuel is `none`.

• **Second row:** The second row specifies the CO2 emissions intensity of each fuel in tons/MMBtu (million British thermal units). Note that by convention, tons correspond to metric tonnes and not short tons (although as long as the user is internally consistent in their application of units, either can be used).

• **Remaining rows:** Rest of the rows in this input file specify the time-series for prices for each fuel in $/MMBtu. A constant price can be specified by entering the same value for all hours.

* ** First column:** The first column in this file denotes, Time\_index, represents the index of time steps in a model instance.


#### 2.1.2 Network.csv

This input file contains input parameters related to: 1) definition of model zones (regions between which transmission flows are explicitly modeled) and 2) definition of transmission network topology, existing capacity, losses and reinforcement costs. The following table describe each of the mandatory parameter inputs need to be specified to run an instance of the model, along with comments for the model configurations when they are needed.

###### Table 3: Structure of the Network.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|**Mandatory Columns**||
|Network\_zones | Specified as z* where * is a number of the zone.|
|**Settings-specific Columns**|
|**Multiple zone model**||
|Network\_Lines | Numerical index for each network line/|
| z* (Network map) | Next n columns, one per zone, with column header in format of z* where * is the number of the zone. L rows, one for each network line (or interregional path), with a 1 in the column corresponding to the 'origin' zone and a -1 in the column corresponding to the 'destination' zone for each line. No more than one column may be marked as origin and one as destination for each line, or the model will not function correctly. Note that positive flows indicate flow from origin to destination zone; negative flows indicate flow from destination to origin zone.|
|Line\_Max\_Flow\_MW | Existing capacity of the inter-regional transmission line.|
|**NetworkExpansion = 1**||
|Line\_Max\_Reinforcement\_MW |Maximum allowable capacity addition to the existing transmission line.|
|Line\_Reinforcement\_Cost\_per\_MWyr | Cost of adding new capacity to the inter-regional transmission line.|
|**Trans\_Loss\_Segments = 1**||
|Line\_Loss\_Percentage | fractional transmission loss for each transmission line||
|**Trans\_Loss\_Segments > 1**||
|Ohms | Line resistance in Ohms (used to calculate I^2R losses)|
|kV | Line voltage in kV (used to calculate I^2R losses)|
|**CapacityReserveMargin > 0**||
|CapRes\_* | Eligibility of the transmission line for adding firm capacity to the capacity reserve margin constraint. * represents the number of the capacity reserve margin constraint.|
||1 = the transmission line is eligible for adding firm capacity to the region|
||0 = the transmission line is not eligible for adding firm capacity to the region|
|DerateCapRes\_* | (0,1) value represents the derating of the firm transmission capacity for the capacity reserve margin constraint.|
|CapResExcl\_* | (-1,1,0) = -1 if the designated direction of the transmission line is inbound to locational deliverability area (LDA) modeled by the capacity reserve margin constraint. = 1 if the designated direction of the transmission line is outbound from the LDA modeled by the capacity reserve margin constraint. Zero otherwise.|



#### 2.1.3 Load\_data.csv

This file includes parameters to characterize model temporal resolution to approximate annual grid operations, electricity demand for each time step for each zone, and cost of load shedding. Note that GenX is designed to model hourly time steps. With some care and effort, finer (e.g. 15 minute) or courser (e.g. 2 hour) time steps can be modeled so long as all time-related parameters are scaled appropriately (e.g. time period weights, heat rates, ramp rates and minimum up and down times for generators, variable costs, etc).

###### Table 4: Structure of the Load\_data.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|**Mandatory Columns**|
|Voll |Value of lost load in $/MWh.|
|Demand\_Segment |Number of demand curtailment/lost load segments with different cost and capacity of curtailable demand for each segment. User-specified demand segments. Integer values starting with 1 in the first row. Additional segements added in subsequent rows.|
|Cost\_of\_Demand\_Curtailment\_per\_MW |Cost of non-served energy/demand curtailment (for each segment), reported as a fraction of value of lost load. If *Demand\_Segment = 1*, then this parameter is a scalar and equal to one. In general this parameter is a vector of length equal to the length of Demand\_Segment.|
|Max\_Demand\_Curtailment| Maximum time-dependent demand curtailable in each segment, reported as % of the demand in each zone and each period. *If Demand\_Segment = 1*, then this parameter is a scalar and equal to one. In general this parameter is a vector of length given by length of Demand\_segment.|
|Time\_Index |Index defining time step in the model.|
|Load\_MW\_z* |Load profile of a zone z* in MW; if multiple zones, this parameter will be a matrix with columns equal to number of zones (each column named appropriate zone number appended to parameter) and rows equal to number of time periods of grid operations being modeled.|
|**Settings-specific Columns**|
|**OperationWrapping = 1**|
|Rep\_Periods |Number of representative periods (e.g. weeks, days) that are modeled to approximate annual grid operations.|
|Timesteps\_per\_Rep\_Period |Number of timesteps per representative period (e.g. 168 if period is set as a week using hour-long time steps).|
|Sub\_Weights |Number of annual time steps (e.g. hours) represented by a given representative period. Length of this column is equal to the number of representative periods. Sum of the elements of this column should be equal to the total number of time steps in a model time horizon, defined in parameterWeightTotal (e.g. 8760 hours if modeling 365 days or 8736 if modeling 52 weeks).|



#### 2.1.4 Generator\_variability.csv

This file contains the time-series of capacity factors / availability of each resource included in the `Generators_data.csv` file for each time step (e.g. hour) modeled.

• first column: The first column contains the time index of each row (starting in the second row) from 1 to N.

• Second column onwards: Resources are listed from the second column onward with headers matching each resource name in the `Generators_data.csv` file in any order. The availability for each resource at each time step is defined as a fraction of installed capacity and should be between 0 and 1. Note that for this reason, resource names specified in `Generators_data.csv` must be unique. Note that for Hydro reservoir resources (i.e. `HYDRO = 1` in the `Generators_data.csv`), values in this file correspond to inflows (in MWhs) to the hydro reservoir as a fraction of installed power capacity, rather than hourly capacity factor.

#### 2.1.5 Generators\_data.csv

This file contains cost and performance parameters for various generators and other resources (storage, flexible demand, etc) included in the model formulation.

###### Table 5: Mandatory columns in the Generators\_data.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Resource | This column contains **unique** names of resources available to the model. Resources can include generators, storage, and flexible or time shiftable demand/loads.|
|Zone | Integer representing zone number where the resource is located. |
|**Technology type flags**|
|New\_Build | {-1, 0, 1}, Flag for resource (storage, generation) eligibility for capacity expansion.|
||New\_Build = 1: eligible for capacity expansion and retirement. |
||New\_Build = 0: not eligible for capacity expansion, eligible for retirement.|
||New\_Build = -1: not eligible for capacity expansion or retirement.|
|THERM | {0, 1, 2}, Flag to indicate membership in set of thermal resources (e.g. nuclear, combined heat and power, natural gas combined cycle, coal power plant)|
||THERM = 0: Not part of set (default) |
||THERM = 1: If the power plant relies on thermal energy input and subject unit commitment constraints/decisions if `UCommit >= 1` (e.g. cycling decisions/costs/constraints). |
||THERM = 2: If the power plant relies on thermal energy input and is subject to simplified economic dispatch constraints (ramping limits and minimum output level but no cycling decisions/costs/constraints). |
|Cap\_size | Size (MW) of a single generating unit. This is used only for resources with integer unit commitment (`THERM = 1`) - not relevant for other resources.|
|VRE | {0, 1}, Flag to indicate membership in set of dispatchable (or curtailable) variable renewable energy resources (onshore wind, offshore wind, utility-scale solar PV, and distributed solar PV subject to dispatch signals).|
||VRE = 0: Not part of set (default) |
||VRE = 1: Dispatchable variable renewable energy (VRE) resources. |
|Num\_VRE\_bins | Number of resource availability profiles considered for each VRE resource per zone. This parameter is used to decide the number of capacity investment decision variables related to a single variable renewable energy technology in each zone.|
||Num\_VRE\_bins = 1: using a single resource availability profile per technology per zone. 1 capacity investment decision variable and 1 generator RID tracking technology power output (and in each zone).|
||Num\_VRE\_bins > 1: using multiple resource availability profiles per technology per zone. Num\_VRE\_bins capacity investment decision variables and 1 generator RID used to define technology power output at each time step (and in each zone). Example: Suppose we are modeling 3 bins of wind profiles for each zone. Then include 3 rows with wind resource names as Wind\_1, Wind\_2, and Wind\_3 and a corresponding increasing sequence of RIDs. Set Num\_VRE\_bins for the generator with smallest RID, Wind\_1, to be 3 and set Num\_VRE\_bins for the other rows corresponding to Wind\_2 and Wind\_3, to be zero. By setting Num\_VRE\_bins for Wind\_2 and Wind\_3, the model eliminates the power outputs variables for these generators. The power output from the technology across all bins is reported in the power output variable for the first generator. This allows for multiple bins without significantly increasing number of model variables (adding each bin only adds one new capacity variable and no operational variables). See documentation for `curtailable_variable_renewable()` for more. |
|MUST\_RUN | {0, 1}, Flag to indicate membership in set of must-run plants (could be used to model behind-the-meter PV not subject to dispatch signals/curtailment, run-of-river hydro that cannot spill water, must-run or self-committed thermal generators, etc). |
||MUST\_RUN = 0: Not part of set (default) |
||MUST\_RUN = 1: Must-run (non-dispatchable) resources.|
|STOR | {0, 1, 2}, Flag to indicate membership in set of storage resources and designate which type of storage resource formulation to employ.|
||STOR = 0: Not part of set (default) |
||STOR = 1: Discharging power capacity and energy capacity are the investment decision variables; symmetric charge/discharge power capacity with charging capacity equal to discharging capacity (e.g. lithium-ion battery storage).|
||STOR = 2: Discharging, charging power capacity and energy capacity are investment variables; asymmetric charge and discharge capacities using distinct processes (e.g. hydrogen electrolysis, storage, and conversion to power using fuel cell or combustion turbine).|
|FLEX | {0, 1}, Flag to indicate membership in set of flexible demand-side resources (e.g. scheduleable or time shiftable loads such as automated EV charging, smart thermostat systems, irrigating pumping loads etc).|
||FLEX = 0: Not part of set (default) |
||FLEX = 1: Flexible demand resource.|
|HYDRO | {0, 1}, Flag to indicate membership in set of reservoir hydro resources.|
||HYDRO = 0: Not part of set (default) |
||HYDRO = 1: Hydropower with reservoir modeling, including inflows, spillage, ramp rate limits and minimum operating level and efficiency loss associated with discharging. Reservoir capacity can be represented as a ratio or energy to power. This type of plant cannot charge from grid.|
|**Existing technology capacity**|
|Existing\_Cap\_MW |The existing capacity of a power plant in MW.|
|Existing\_Cap\_MWh |The existing capacity of storage in MWh where `STOR = 1` or `STOR = 2`.|
|Existing\_Charge\_Cap\_MW |The existing charging capacity for resources where `STOR = 2`.|
|**Capacity/Energy requirements**|
|Max\_Cap\_MW |-1 (default) – no limit on maximum discharge capacity of the resource. If non-negative, represents maximum allowed discharge capacity (in MW) of the resource.|
|Max\_Cap\_MWh |-1 (default) – no limit on maximum energy capacity of the resource. If non-negative, represents maximum allowed energy capacity (in MWh) of the resource with `STOR = 1` or `STOR = 2`.|
|Max\_Charge\_Cap\_MW |-1 (default) – no limit on maximum charge capacity of the resource. If non-negative, represents maximum allowed charge capacity (in MW) of the resource with `STOR = 2`.|
|Min\_Cap\_MW |-1 (default) – no limit on minimum discharge capacity of the resource. If non-negative, represents minimum allowed discharge capacity (in MW) of the resource.|
|Min\_Cap\_MWh| -1 (default) – no limit on minimum energy capacity of the resource. If non-negative, represents minimum allowed energy capacity (in MWh) of the resource with `STOR = 1` or `STOR = 2`.|
|Min\_Charge\_Cap\_MW |-1 (default) – no limit on minimum charge capacity of the resource. If non-negative, represents minimum allowed charge capacity (in MW) of the resource with `STOR = 2`.|
|**Cost parameters**|
|Inv\_Cost\_per\_MWyr | Annualized capacity investment cost of a technology ($/MW/year). |
|Inv\_Cost\_per\_MWhyr | Annualized investment cost of the energy capacity for a storage technology ($/MW/year), applicable to either `STOR = 1` or `STOR = 2`. |
|Inv\_Cost\_Charge\_per\_MWyr | Annualized capacity investment cost for the charging portion of a storage technology with `STOR = 2` ($/MW/year). |
|Fixed\_OM\_Cost\_per\_MWy | Fixed operations and maintenance cost of a technology ($/MW/year). |
|Fixed\_OM\_Cost\_per\_MWhyr | Fixed operations and maintenance cost of the energy component of a storage technology ($/MWh/year). |
|Fixed\_OM\_Cost\_charge\_per\_MWyr | Fixed operations and maintenance cost of the charging component of a storage technology of type `STOR = 2`. |
|Var\_OM\_Cost\_per\_MWh | Variable operations and maintenance cost of a technology ($/MWh). |
|Var\_OM\_Cost\_per\_MWhIn | Variable operations and maintenance cost of the charging aspect of a storage technology with `STOR = 2`, or variable operations and maintenance costs associated with flexible demand deferral with `FLEX = 1`. Otherwise 0 ($/MWh). |
|**Technical performance parameters**|
|Heat\_Rate\_MMBTU\_per\_MWh  |Heat rate of a generator or MMBtu of fuel consumed per MWh of electricity generated for export (net of on-site house loads). The heat rate is the inverse of the efficiency: a lower heat rate is better. Should be consistent with fuel prices in terms of reporting on higher heating value (HHV) or lower heating value (LHV) basis. |
|Fuel  |Fuel needed for a generator. The names should match with the ones in the `Fuels_data.csv`. |
|Self\_Disch  |[0,1], The power loss of storage technologies per hour (fraction loss per hour)- only applies to storage techs.|
|Min\_Power |[0,1], The minimum generation level for a unit as a fraction of total capacity. This value cannot be higher than the smallest time-dependent CF value for a resource in `Generators_variability.csv`. Applies to thermal plants, and reservoir hydro resource (`HYDRO = 1`).|
|Ramp\_Up\_Percentage |[0,1], Maximum increase in power output from between two periods (typically hours), reported as a fraction of nameplate capacity. Applies to thermal plants, and reservoir hydro resource (`HYDRO = 1`).|
|Ramp\_Dn\_Percentage |[0,1], Maximum decrease in power output from between two periods (typically hours), reported as a fraction of nameplate capacity. Applies to thermal plants, and reservoir hydro resource (`HYDRO = 1`).|
|Eff\_Up  |[0,1], Efficiency of charging storage – applies to storage technologies (all STOR types). |
|Eff\_Down  |[0,1], Efficiency of discharging storage – applies to storage technologies (all STOR types). |
|Hydro\_Energy\_to\_Power\_Ratio  |The rated number of hours of reservoir hydro storage at peak discharge power output. Applies to `HYDRO = 1` (hours). |
|Min\_Duration  |Specifies the minimum ratio of installed energy to discharged power capacity that can be installed. Applies to STOR types 1 and 2 (hours). |
|Max\_Duration  |Specifies the maximum ratio of installed energy to discharged power capacity that can be installed. Applies to STOR types 1 and 2 (hours). |
|Max\_Flexible\_Demand\_Delay  |Maximum number of hours that demand can be deferred or delayed. Applies to resources with FLEX type 1 (hours). |
|Max\_Flexible\_Demand\_Advance  |Maximum number of hours that demand can be scheduled in advance of the original schedule. Applies to resources with FLEX type 1 (hours). |
|Flexible\_Demand\_Energy\_Eff  |[0,1], Energy efficiency associated with time shifting demand. Represents energy losses due to time shifting (or 'snap back' effect of higher consumption due to delay in use) that may apply to some forms of flexible demand. Applies to resources with FLEX type 1 (hours). For example, one may need to pre-cool a building more than normal to advance demand. |
|**Required for writing outputs**|
|region | Name fo the model region|
|cluster | Number of the cluster when representing multiple clusters of a given technology in a given region.  |


###### Table 6: Settings-specific columns in the Generators\_data.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|**UCommit >= 1** | The following settings apply only to thermal plants with unit commitment constraints (`THERM = 1`).|
|Up\_Time| Minimum amount of time a resource has to stay in the committed state.|
|Down\_Time |Minimum amount of time a resource has to remain in the shutdown state.|
|Start\_Cost\_per\_MW |Cost per MW of nameplate capacity to start a generator ($/MW per start). Multiplied by the number of generation units (each with a pre-specified nameplate capacity) that is turned on.|
|Start\_Fuel\_MMBTU\_per\_MW |Startup fuel use per MW of nameplate capacity of each generator (MMBtu/MW per start).|
|**Reserves = 1** | The following settings apply to thermal, dispatchable VRE, hydro and storage resources|
|Reg\_Cost |Cost of providing regulation reserves ($/MW per time step/hour).|
|Rsv\_Cost |Cost of providing upwards spinning or contingency reserves ($/MW per time step/hour).|
|Reg\_Max |[0,1], Fraction of nameplate capacity that can committed to provided regulation reserves. .|
|Rsv\_Max |[0,1], Fraction of nameplate capacity that can committed to provided upwards spinning or contingency reserves.|
|**EnergyShareRequirement > 0**||
|ESR\_*| Flag to indicate which resources are considered for the Energy Share Requirement constraint.|
||1- included|
||0- excluded|
|**CapacityReserveMargin > 0**||
|CapRes\_* |[0,1], Fraction of the resource capacity eligible for contributing to the capacity reserve margin constraint (e.g. derate factor).|
|**ModelingToGenerateAlternatives = 1**||
|MGA |Eligibility of the technology for Modeling To Generate Alternative (MGA) run. |
||1 = Technology is available for the MGA run.|
||0 = Technology is unavailable for the MGA run (e.g. storage technologies).|
|Resource\_Type |For the MGA run, we categorize all the resources in a few resource types. We then find maximally different generation portfolio based on these resource types. For example, existing solar and new solar resources could be represented by a resource type names `Solar`. Categorization of resources into resource types is user dependent.|
|**MinCapReq = 1**|
|MinCapTag\_*| Eligibility of resources to participate in Minimum Technology Carveout constraint. \* corresponds to the ith row of the file `Minimum_capacity_requirement.csv`.|



### 2.2 Optional inputs files

#### 2.2.1 Online Time-domain reduction

Modeling grid operations for each hour of the year can be computationally expensive for models with many zones and resources. Time-domain reduction is often employed in capacity expansion models as a way to balance model spatial and temporal resolution as well as representation of dispatch, while ensuring reasonable computational times. GenX allows the option of performing time-domain reduction on the user supplied time-series input data to produce a representative time series at the desired level of temporal resolution. The below table summarizes the list of parameters to be specified by the user to perform the time domain reduction implemented in GenX. These parameters are passed to GenX via the YAML file `time_domain_reduction_settings.yml`.

###### Table 7: Structure of the Load\_data.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|**TimeDomainReduction = 1**||
|Timesteps\_per\_period | The number of timesteps (e.g., hours) in each representative period (i.e. 168 for weeks, 24 for days, 72 for three-day periods, etc).|
|UseExtremePeriods | 1 = Include outliers (by performance or load/resource extreme) as their own representative extreme periods. This setting automatically includes periods based on criteria outlined in the dictionary `ExtremePeriods`. Extreme periods can be selected based on following criteria applied to load profiles or solar and wind capacity factors profiles, at either the zonal or system level. A) absolute (timestep with min/max value) statistic (minimum, maximum) and B) integral (period with min/max summed value) statistic (minimum, maximum). For example, the user could want the hour with the most load across the whole system to be included among the extreme periods. They would select Load, System, Absolute, and Max.|
||0 = Do not include extreme periods.|
|ExtremePeriods | If UseExtremePeriods = 1, use this dictionary to select which types of extreme periods to use. Select by profile type (Load, PV, or Wind), geography (Zone or System), grouping by timestep or by period (Absolute or Integral), and statistic (Maximum or Minimum).|
|ClusterMethod |Either `kmeans` or `kmedoids`, the method used to cluster periods and determine each time step's representative period.|
|ScalingMethod |Either ‘N' or ‘S', the decision to normalize ([0,1]) or standardize (mean 0, variance 1) the input data prior to clustering.|
|MinPeriods |The minimum number of representative periods used to represent the input data. If using UseExtremePeriods, this must be greater or equal to the number of selected extreme periods. If `IterativelyAddPeriods` is off, this will be the total number of representative periods.|
|MaxPeriods| The maximum number of representative periods - both clustered and extreme - that may be used to represent the input data.|
|IterativelyAddPeriods |1 = Add representative periods until the error threshold between input data and represented data is met or the maximum number of representative periods is reached.|
||0 = Use only the minimum number of representative periods. This minimum value includes the selected extreme periods if `UseExtremePeriods` is on.|
|Threshold |Iterative period addition will end if the period farthest from its representative period (as measured using Euclidean distance) is within this percentage of the total possible error (for normalization) or 95% of the total possible error (± 2 σ for standardization). E.g., for a threshold of 0.01, each period must be within 1% of the spread of possible error before the clustering iterations will terminate (or until the maximum is reached).|
|IterateMethod | Either ‘cluster' (Default) or ‘extreme', whether to increment the number of clusters to the kmeans/kmedoids method or to set aside the worst-fitting periods as a new extreme periods.|
|nReps |Default 200, the number of kmeans/kmedoids repetitions at the same setting.|
|LoadWeight| Default 1, a multiplier on load columns to optionally prioritize better fits for load profiles over resource capacity factor or fuel price profiles.|
|WeightTotal |Default 8760, the sum to which the relative weights of representative periods will be scaled.|
|ClusterFuelPrices| Either 1 or 0, whether or not to use the fuel price time series in `Fuels_data.csv` in the clustering process. If 'no', this function will still write `Fuels_data.csv` in the TimeDomainReductionFolder with reshaped fuel prices based on the number and size of the representative periods but will not use the fuel price time series for selection of representative periods.|



#### 2.2.2 Reserves.csv

This file includes parameter inputs needed to model time-dependent procurement of regulation and spinning reserves. This file is needed if `Reserves` flag is activated in the YAML file `GenX_settings.yml`.

###### Table 8: Structure of the Reserves.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Reg\_Req\_Percent\_Load |[0,1], Regulation requirement as a percent of time-dependent load; here load is the total across all model zones.|
|Reg\_Req\_Percent\_VRE |[0,1], Regulation requirement as a percent of time-dependent wind and solar generation (summed across all model zones).|
|Rsv\_Req\_Percent\_Load [0,1], |Spinning up or contingency reserve requirement as a percent of time-dependent load (which is summed across all zones).|
|Rsv\_Req\_Percent\_VRE |[0,1], Spinning up or contingency reserve requirement as a percent of time-dependent wind and solar generation (which is summed across all zones).|
|Unmet\_Rsv\_Penalty\_Dollar\_per\_MW |Penalty for not meeting time-dependent spinning reserve requirement ($/MW per time step).|
|Dynamic\_Contingency |Flags to include capacity (generation or transmission) contingency to be added to the spinning reserve requirement.|
|Dynamic\_Contingency |= 1: contingency set to be equal to largest installed thermal unit (only applied when `UCommit = 1`).|
||= 2: contingency set to be equal to largest committed thermal unit each time period (only applied when `UCommit = 1`).|
|Static\_Contingency\_MW |A fixed static contingency in MW added to reserve requirement. Applied when `UCommit = 1` and `DynamicContingency = 0`, or when `UCommit = 2`. Contingency term not included in operating reserve requirement when this value is set to 0 and DynamicContingency is not active.|



#### 2.2.3 Energy\_share\_requirement.csv

This file contains inputs specifying minimum energy share requirement policies, such as Renewable Portfolio Standard (RPS) or Clean Energy Standard (CES) policies. This file is needed if parameter EnergyShareRequirement has a non-zero value in the YAML file `GenX_settings.yml`.

Note: this file should use the same region name as specified in the `Generators_data.csv` file.

###### Table 9: Structure of the Energy\_share\_requirement.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Region\_description |Region name|
|Network\_zones |zone number represented as z*|
|ESR\_* |[0,1], Energy share requirements as a share of zonal demand (calculated on an annual basis). * represents the number of the ESR constraint, given by the number of ESR\_* columns in the `Energy_share_requirement.csv` file.|



#### 2.2.4 CO2\_cap.csv

This file contains inputs specifying CO2 emission limits policies (e.g. emissions cap and permit trading programs). This file is needed if `CO2Cap` flag is activated in the YAML file `GenX_settings.yml`. `CO2Cap` flag set to 1 represents mass-based (tCO2 ) emission target. `CO2Cap` flag set to 2 is specified when emission target is given in terms of rate (tCO2/MWh) and is based on total demand met. `CO2Cap` flag set to 3 is specified when emission target is given in terms of rate (tCO2 /MWh) and is based on total generation.

###### Table 10: Structure of the CO2\_cap.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Region\_description |Region name|
|Network\_zones| zone number represented as z*|
|CO\_2\_Cap\_Zone* |If a zone is eligible for the emission limit constraint, then this column is set to 1, else 0.|
|CO\_2\_Max\_tons\_MWh* |Emission limit in terms of rate|
|CO\_2\_Max\_Mtons* |Emission limit in absolute values, in Million of tons |
| | where in the above inputs, * represents the number of the emission limit constraints. For example, if the model has 2 emission limit constraints applied separately for 2 zones, the above CSV file will have 2 columns for specifying emission limit in terms on rate: CO\_2\_Max\_tons\_MWh\_1 and CO\_2\_Max\_tons\_MWh\_2.|



#### 2.2.5 Capacity\_reserve\_margin.csv

This file contains the regional capacity reserve margin requirements. This file is needed if parameter CapacityReserveMargin has a non-zero value in the YAML file `GenX_settings.yml`.

Note: this file should use the same region name as specified in the `Generators_data.csv` file

###### Table 11: Structure of the Capacity\_reserve\_margin.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Region\_description |Region name|
|Network\_zones |zone number represented as z*|
|CapRes\_* |[0,1], Capacity reserve margin requirements of a zone, reported as a fraction of demand|



#### 2.2.6 Minimum\_capacity\_requirement.csv

This file contains the minimum capacity carve-out requirement to be imposed (e.g. a storage capacity mandate or offshore wind capacity mandate). This file is needed if parameter `MinCapReq` flag has a non-zero value in the YAML file `GenX_settings.yml`.

###### Table 12: Structure of the Minimum\_capacity\_requirement.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|MinCapReqConstraint |Index of the minimum capacity carve-out requirement.|
|Constraint\_Description |Names of minimum capacity carve-out constraints; not to be read by model, but used as a helpful notation to the model user. |
|Min\_MW | minimum capacity requirement [MW]|


Some of the columns specified in the input files in Section 2.2 and 2.1 are not used in the GenX model formulation. These columns are necessary for interpreting the model outputs and used in the output module of the GenX.


#### 2.2.7 Rand\_mga\_objective\_coefficients.csv
This file is required while using modeling to generate alternatives (MGA) algorithm. The number of columns in this csv file is equal to one plus the number of model zones. Number of rows for each iteration is equal to the number of distinct elements in the `Resource_Type` column in the `Generators_data.csv` file. Elements of this file are used as random objective function coefficients fo the MGA algorithm.

###### Table 12: Structure of the Minimum\_capacity\_requirement.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|V* |* represents the region number. This column has random integers between -100 and 100.|
|Iter | MGA iteration number.|



## 3 Outputs

The table below summarizes the units of each output variable reported as part of the various CSV files produced after each model run. The reported units are also provided. If a result file includes time-dependent values, the value will not include the hour weight in it. An annual sum ("AnnualSum") column/row will be provided whenever it is possible (e.g., `emissions.csv`).

### 3.1 Default output files


#### 3.1.1 capacity.csv

Reports optimal values of investment variables (except StartCap, which is an input)

###### Table 14: Structure of the capacity.csv file
---
|**Output** |**Description** |**Units** |
| :------------ | :-----------|:-----------|
| StartCap |Initial power capacity of each resource type in each zone; this is an input |MW |
| RetCap |Retired power capacity of each resource type in each zone |MW |
| NewCap |Installed capacity of each resource type in each zone |MW|
| EndCap| Total power capacity of each resource type in each zone |MW |
| StartEnergyCap |Initial energy capacity of each resource type in each zone; this is an input and applies only to storage tech.| MWh |
| RetEnergyCap |Retired energy capacity of each resource type in each zone; applies only to storage tech. |MWh |
| NewEnergyCap| Installed energy capacity of each resource type in each zone; applies only to storage tech. |MWh |
| EndEnergyCap |Total installed energy capacity of each resource type in each zone; applies only to storage tech. |MWh |
| StartChargeCap| Initial charging power capacity of `STOR = 2` resource type in each zone; this is an input |MW |
| RetChargeCap |Retired charging power capacity of `STOR = 2` resource type in each zone |MW |
| NewChargeCap |Installed charging capacity of each resource type in each zone |MW |
| EndChargeCap |Total charging power capacity of each resource type in each zone |MW|



#### 3.1.2 costs.csv

Reports optimal objective function value and contribution of each term by zone.

###### Table 15: Structure of the costs.csv file
---
|**Output** |**Description** |**Units** |
| :------------ | :-----------|:-----------|
| cTotal |Total objective function value |$ |
| cFix |Total annualized investment and fixed operating & maintainenance (FOM) costs associated with all resources |$ |
| cVar |Total annual variable cost associated with all resources; includes fuel costs for thermal plants |$|
| cNSE |Total annual cost of non-served energy |$|
| cStart |Total annual cost of start-up of thermal power plants| $|
| cUnmetRsv |Total annual cost of not meeting time-dependent operating reserve (spinning) requirements |$ |
| cNetworkExp |Total cost of network expansion |$|
| cEmissionsRevenue |Total and zonal emissions revenue |$ |
| cEmissionsCost |Total an zonal emissions cost |$ |



#### 3.1.3 emissions.csv

Reports CO2 emissions by zone at each hour; an annual sum row will be provided. If any emission cap is present, emission prices each zone faced by each cap will be copied on top of this table with the following strucutre.

###### Table 16: Structure of emission prices in the emissions.csv file
---
|**Output** |**Description** |**Units** |
| :------------ | :-----------|:-----------|
|CO_2\_price |Marginal CO2 abatement cost associated with constraint on maximum annual CO2 emissions; will be same across zones if CO2 emissions constraint is applied for the entire region and not zone-wise |\$/ tonne CO2. |



#### 3.1.4 nse.csv

Reports non-served energy for every model zone, time step and cost-segment.


#### 3.1.5 power.csv

Reports power discharged by each resource (generation, storage, demand response) in each model time step.


#### 3.1.6 reliability.csv

Reports dual variable of maximum non-served energy constraint (shadow price of reliability constraint) for each model zone and time step.


#### 3.1.7 prices.csv

Reports marginal electricity price for each model zone and time step. Marginal electricity price is equal to the dual variable of the load balance constraint. If GenX is configured as a mixed integer linear program, then this output is only generated if `WriteShadowPrices` flag is activated. If configured as a linear program (i.e. linearized unit commitment or economic dispatch) then output automatically available.


#### 3.1.8 status.csv

Reports computational performance of the model and objective function related information.

###### Table 17: Structure of the status.csv file
---
|**Output** |**Description** |**Units** |
| :------------ | :-----------|:-----------|
|Status | termination criteria (optimal, timelimit etc.).||
|solve | Solve time including time for pre-solve |seconds |
|Objval | Optimal objective function value |$|
|Objbound | Best objective lower bound | $ |
|FinalMIPGap |Optimality gap at termination in case of a mixed-integer linear program (MIP gap); when using Gurobi, the lower bound and MIP gap is reported excluding constant terms (E.g. fixed cost of existing generators that cannot be retired) in the objective function and hence may not be directly usable. |Fraction|



#### 3.1.9 NetRevenue.csv

This file summarizes the cost, revenue and profit for each generation technology for each region.

###### Table 18: Stucture of the NetRevenue.csv file
---
|**Output** |**Description** |**Units** |
| :------------ | :-----------|:-----------|
| Fixed\_OM\_cost\_MW | Fixed Operation and Maintenance cost of the MW capacity. |$|
| Fixed\_OM\_cost\_MWh| Fixed Operation and Maintenance cost of the MWh capacity. Only applicable to energy storage.| $ |
| Var\_OM\_cost\_out| Variable Operation and Maintenance cost of the power generation or discharge. |$ |
| Var\_OM\_cost\_in |Variable Operation and Maintenance cost of the power charge/pumping. Only applicable to energy storage. |$ |
| Fuel\_cost| Fuel cost of the power generation. Only applicable to generation that burns fuel. |$ |
| Charge\_cost |Cost of charging power (due to the payment for electricity) Only applicable to energy storage. |$|
| EmissionsCost| Cost of buying emission credit. |$ |
| StartCost |Cost of generator start-up. |$ |
| Inv\_cost\_MW |Cost of building MW capacity. |$ |
| Inv\_cost\_MWh| Cost of building MWh capacity. |$ |
| EnergyRevenue |Revenue of generating power.| $ |
| SubsidyRevenue| Revenue of Min\_Cap subsidy. |$ |
| ReserveMarginRevenue| Revenue earned from capacity reserve margin constraints. |$|
| ESRRevenue| Revenue selling renewable/clean energy credits. |$ |
| Revenue| Total Revenue.| $ |
| Cost| Total Cost. |$ |
| Profit |Revenue minus Cost. |$ |



### 3.2 Settings-specific outputs

This section includes the output files that GenX will print if corresponding function is specified in the Settings.


#### 3.2.1 CapacityValue.csv

This file includes the time-dependent capacity value calculated for each generator. GenX will print this file only if the capacity reserve margin constraints are modeled through the setting file. Each row of the file (excluding the header) corresponds to a generator specified in the inputs. Each column starting from the t1 to the second last one stores the result of capacity obligation provided in each hour divided by the total capacity. Thus the number is unitless. If the capacity margin reserve is not binding for one hour, GenX will return zero. The last column specified the name of the corresponding capacity reserve constraint. Note that, if the user calculates the hour-weight-averaged capacity value for each generator using data of the binding hours, the result is what RTO/ISO call capacity credit.

<!---
#### 3.2.2 ExportRevenue.csv

This file includes the export revenue in $ of each zone. GenX will print this file only when a network is present and Locational Marginal Price (LMP) data is available to the GenX. The Total row includes the time-step-weighted summation of the time-dependent values shown below. For each time-step, the export revenue is calculated as the net outbound powerflow multiplied by the LMP. It is noteworthy that this export revenue is already part of the generation revenue, and the user should not double count.


#### 3.2.3 Importcost.csv

This file includes the import cost in $ of each zone. GenX will print this file only when a network is present and Locational Marginal Price (LMP) data is available to the GenX. The Total row includes the time-step -weighted summation of the time-dependent values shown below. For each time step, the import cost is calculated as the net inbound powerflow multiplied by the LMP. It is noteworthy that this import cost is already part of the load payment, and the user should not double count.
--->


#### 3.2.2 EnergyRevenue.csv

This file includes the energy revenue in $ earned by each generator through injecting into the grid. Only annual sum values are available.


#### 3.2.3 ChargingCost.csv

This file includes the charging cost  in $ of earned by each generator through withdrawing from the grid. Only annual sum values are available.


#### 3.2.4 ReserveMargin.csv

This file includes the shadow prices of the capacity reserve margin constraints. GenX will print this file only when capacity reserve margin is modeled and the shadow price can be obtained form the solver, as described earlier. Each row (except the header) corresponds to a capacity reserve margin constraint, and each column corresponds to an time step. As a reminder, GenX models the capacity reserve margin (aka capacity market) at the time-dependent level, and each constraint either stands for an overall market or a locality constraint.


#### 3.2.5 ReserveMarginRevenue.csv

This file includes the capacity revenue earned by each generator listed in the input file. GenX will print this file only when capacity reserve margin is modeled and the shadow price can be obtained form the solver. Each row corresponds to a generator, and each column starting from the 6th to the second last is the total revenue from each capacity reserve margin constraint. The revenue is calculated as the capacity contribution of each time steps multiplied by the shadow price, and then the sum is taken over all modeled time steps. The last column is the total revenue received from all capacity reserve margin constraints. As a reminder, GenX models the capacity reserve margin (aka capacity market) at the time-dependent level, and each constraint either stands for an overall market or a locality constraint.


#### 3.2.6 ESR\_prices.csv

This file includes the renewable/clean energy credit price of each modeled RPS/CES constraint. GenX will print this file only when RPS/CES is modeled and the shadow price can be obtained form the solver. The unit is $/MWh.


#### 3.2.7 ESR\_Revenue.csv

This file includes the renewable/clean credit revenue earned by each generator listed in the input file. GenX will print this file only when RPS/CES is modeled and the shadow price can be obtained form the solver. Each row corresponds to a generator, and each column starting from the 6th to the second last is the total revenue earned from each RPS constraint. The revenue is calculated as the total annual generation (if elgible for the corresponding constraint) multiplied by the RPS/CES price. The last column is the total revenue received from all constraint. The unit is $.


#### 3.2.8 SubsidyRevenue.csv

This file includes subsidy revenue earned if a generator specified Min\_Cap is provided in the input file. GenX will print this file only the shadow price can be obtained form the solver. Do not confuse this with the Minimum Capacity Carveout constraint, which is for a subset of generators, and a separate revenue term will be calculated in other files. The unit is $.
