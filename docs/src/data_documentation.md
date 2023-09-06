# GenX Database Documentation

## 1 Model setup parameters

Model settings parameters are specified in a `genx_settings.yml` file which should be located in the current working directory (or to specify an alternative location, edit the `settings_path` variable in your `Run.jl` file).
Settings include those related to model structure, solution strategy and outputs, policy constraints, and others. Model structure related settings parameters affect the formulation of the model constraints and objective function.
Computational performance related parameters affect the accuracy of the solution.
Policy related parameters specify the policy type and policy goal. Network related parameters specify settings related to transmission network expansion and losses.
Note that all settings parameters are case sensitive.

###### Table 1a: Summary of the Model settings parameters
---
|**Settings Parameter** | **Description**|
| :------------ | :-----------|
|**Model structure related**||
|TimeDomainReduction | 1 = Use time domain reduced inputs available in the folder with the name defined by settings parameter `TimeDomainReductionFolder`. If such a folder does not exist or it is empty, time domain reduction will reduce the input data and save the results there.|
||0 = Use the data in the main case folder; do not perform clustering.|
|TimeDomainReductionFolder | Name of the folder where time domain reduced input data is stored.|
|UCommit | Select technical resolution of of modeling thermal generators.|
||0 = no unit commitment.|
||1 = unit commitment with integer clustering.|
||2 = unit commitment with linearized clustering.|
|NetworkExpansion | Flag for activating or deactivating inter-regional transmission expansion.|
||1 = active|
||0 = modeling single zone or for multi-zone problems in which inter regional transmission expansion is not allowed.|
|Trans\_Loss\_Segments | Number of segments to use in piece-wise linear approximation of losses.|
||1: linear|
||>=2: piece-wise quadratic|
|Reserves | Flag for modeling operating reserves .|
||0 = No operating reserves considered. |
||1 = Consider regulation (primary) and spinning (secondary) reserves. |
|StorageLosses | Flag to account for storage related losses.|
||0 = VRE and CO2 constraints DO NOT account for energy lost. |
||1 = constraints account for energy lost. |
|**Policy related**|
|EnergyShareRequirement | Flag for specifying regional renewable portfolio standard (RPS) and clean energy standard policy (CES) related constraints.|
|| Default = 0 (No RPS or CES constraints).|
|| 1 = activate energy share requirement related constraints. |
|CO2Cap | Flag for specifying the type of CO2 emission limit constraint.|
|| 0 = no CO2 emission limit|
|| 1 = mass-based emission limit constraint|
|| 2 = demand + rate-based emission limit constraint|
|| 3 = generation + rate-based emission limit constraint|
|CapacityReserveMargin | Flag for Capacity Reserve Margin constraints. |
|| Default = 0 (No Capacity Reserve Margin constraints)|
|| 1 = activate Capacity Reserve Margin related constraints |
|MinCapReq | Minimum technology carve out requirement constraints.|
|| 1 = if one or more minimum technology capacity constraints are specified|
|| 0 = otherwise|
|MaxCapReq | Maximum system-wide technology capacity limit constraints.|
|| 1 = if one or more maximum technology capacity constraints are specified|
|| 0 = otherwise|
|**Solution strategy and outputs**||
|Solver | Specifies the solver name (This is not case sensitive i.e. CPLEX/cplex, Gurobi/gurobi, Clp/clp indicate the same solvers, respectively). |
|ParameterScale | Flag to turn on parameter scaling wherein demand, capacity and power variables defined in GW rather than MW. This flag aides in improving the computational performance of the model. |
||1 = Scaling is activated. |
||0 = Scaling is not activated. |
|ModelingToGenerateAlternatives | Modeling to Generate Alternative Algorithm. For details, see [here](https://genxproject.github.io/GenX/dev/additional_features/#Modeling-to-Generate-Alternatives)|
||1 = Use the algorithm. |
||0 = Do not use the algorithm. |
|ModelingtoGenerateAlternativeSlack | value used to define the maximum deviation from the least-cost solution as a part of Modeling to Generate Alternative Algorithm. Can take any real value between 0 and 1. |
|WriteShadowPrices | Get the optimal values of dual variables of various model related constraints, including to estimate electricity prices, stored value of energy and the marginal CO2 prices.|
|MultiStage | Model multiple planning stages |
||1 = Model multiple planning stages as specified in `multi_stage_settings.yml` |
||0 = Model single planning stage |
|MethodofMorris | Method of Morris algorithm |
||1 = Use the algorithm. |
||0 = Do not use the algorithm. |
|**Miscellaneous**||
|PrintModel | Flag for printing the model equations as .lp file.|
||1 = including the model equation as an output|
||0 = the model equation won't be included as an output|

Additionally, Solver related settings parameters are specified in the appropriate .yml file (e.g. `gurobi_settings.yml` or `cplex_settings.yml`),
which should be located in the current working directory.
Note that GenX supplies default settings for most solver settings in the various solver-specific functions found in the `src/configure_solver/` directory.
To overwrite default settings, you can specify the below Solver specific settings.
Settings are specific to each solver.

###### Table 1b: Summary of the Solver settings parameters
---
|**Settings Parameter** | **Description**|
| :------------ | :-----------|
|**Solver settings**||
|Method | Algorithm used to solve continuous models or the root node of a MIP model. Generally, barrier method provides the fastest run times for real-world problem set.|
|| CPLEX: CPX\_PARAM\_LPMETHOD - Default = 0; See [link](https://www.ibm.com/docs/en/icos/20.1.0?topic=parameters-algorithm-continuous-linear-problems) for more specifications.|
|| Gurobi: Method - Default = -1; See [link](https://www.gurobi.com/documentation/8.1/refman/method.html) for more specifications.|
|| clp: SolveType - Default = 5; See [link](https://www.coin-or.org/Doxygen/Clp/classClpSolve.html) for more specifications.|
|| HiGHS: Method - Default = "choose"; See [link](https://ergo-code.github.io/HiGHS/dev/options/definitions/)
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

All input files are in CSV format. Running the GenX model requires a minimum of five input files. Additionally, the user may need to specify five more input files based on model configuration and type of scenarios of interest. Description and column details of all potential input files are included in the `Input_data_explained` folder in the `Example_Systems` folder. Names of the input files and their functionality is also given below. Note that names of the input files are case sensitive.


###### Table 2: Summary of the input files
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|**Mandatory Files**||
|Fuels\_data.csv |Specify fuel type, CO2 emissions intensity, and time-series of fuel prices. |
|Network.csv |Specify network topology, transmission fixed costs, capacity and loss parameters.|
|Demand\_data.csv |Specify time-series of demand profiles for each model zone, weights for each time step, demand shedding costs, and optional time domain reduction parameters.|
|Generators\_variability.csv |Specify time-series of capacity factor/availability for each resource.|
|Generators\_data.csv |Specify cost and performance data for generation, storage and demand flexibility resources.|
|**Settings-specific Files**||
|Reserves.csv |Specify operational reserve requirements as a function of demand and renewables generation and penalty for not meeting these requirements.|
|Energy\_share\_requirement.csv |Specify regional renewable portfolio standard and clean energy standard style policies requiring minimum energy generation from qualifying resources.|
|CO2\_cap.csv |Specify regional CO2 emission limits.|
|Capacity\_reserve\_margin.csv |Specify regional capacity reserve margin requirements.|
|Minimum\_capacity\_requirement.csv |Specify regional minimum technology capacity deployment requirements.|
|Vre\_and\_stor\_data.csv |Specify cost and performance data for co-located VRE and storage resources.|
|Vre\_and\_stor\_solar\_variability.csv |Specify time-series of capacity factor/availability for each solar PV resource that exists for every co-located VRE and storage resource (in DC terms).|
|Vre\_and\_stor\_wind\_variability.csv |Specify time-series of capacity factor/availability for each wind resource that exists for every co-located VRE and storage resource (in AC terms).|

### 2.1 Mandatory input data


#### 2.1.1 Fuels\_data.csv

• **First row:** names of all fuels used in the model instance which should match the labels used in `Fuel` column in the `Generators_data.csv` file. For renewable resources or other resources that do not consume a fuel, the name of the fuel is `None`.

• **Second row:** The second row specifies the CO2 emissions intensity of each fuel in tons/MMBtu (million British thermal units). Note that by convention, tons correspond to metric tonnes and not short tons (although as long as the user is internally consistent in their application of units, either can be used).

• **Remaining rows:** Rest of the rows in this input file specify the time-series for prices for each fuel in $/MMBtu. A constant price can be specified by entering the same value for all hours.

* ** First column:** The first column in this file denotes, Time\_index, represents the index of time steps in a model instance.


#### 2.1.2 Network.csv

This input file contains input parameters related to: 1) definition of model zones (regions between which transmission flows are explicitly modeled) and 2) definition of transmission network topology, existing capacity, losses and reinforcement costs. The following table describe each of the mandatory parameter inputs need to be specified to run an instance of the model, along with comments for the model configurations when they are needed.

###### Table 3: Structure of the Network.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|**Settings-specific Columns**|
|**Multiple zone model**||
|Network\_Lines | Numerical index for each network line. The length of this column is counted but the actual values are not used.|
| z* (Network map) **OR** Origin_Zone, Destination_Zone | See below |
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
|**MultiStage == 1**|
|Capital\_Recovery\_Period  |Capital recovery period (in years) used for determining overnight capital costs from annualized investment costs for network transmission line expansion.  |
|Line\_Max\_Flow\_Possible\_MW  |Maximum possible line flow in the current model period. Overrides Line\_Max\_Reinforcement\_MW, which is not used when performing multi-stage modeling.  |

There are two interfaces implemented for specifying the network topology itself: a matrix interface and a list interface.
Only one choice is permitted in a given file.

The list interface consists of a column for the lines origin zone and one for the line's destination zone.
Here is a snippet of the Network.csv file for a map with three zones and two lines:
```
Network_Lines, Origin_Zone, Destination_Zone,
            1,           1,                2,
            2,           1,                3,
```

The matrix interface requires N columns labeled `z1, z2, z3 ... zN`,
and L rows, one for each network line (or interregional path), with a `1` in the column corresponding to the 'origin' zone 
and a `-1` in the column corresponding to the 'destination' zone for each line.
Here is the same network map implemented as a matrix:
```
Network_Lines, z1, z2, z3,
            1,  1, -1,  0,
            2,  1,  0, -1,
```

Note that in either case, positive flows indicate flow from origin to destination zone;
negative flows indicate flow from destination to origin zone.


#### 2.1.3 Demand\_data.csv (Load\_data.csv)

This file includes parameters to characterize model temporal resolution to approximate annual grid operations, electricity demand for each time step for each zone, and cost of load shedding. Note that GenX is designed to model hourly time steps. With some care and effort, finer (e.g. 15 minute) or courser (e.g. 2 hour) time steps can be modeled so long as all time-related parameters are scaled appropriately (e.g. time period weights, heat rates, ramp rates and minimum up and down times for generators, variable costs, etc).

###### Table 4: Structure of the Demand\_data.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|**Mandatory Columns**|
|Voll |Value of lost load (also referred to as non-served energy) in $/MWh.|
|Demand\_Segment |Number of demand curtailment/unserved demand segments with different cost and capacity of curtailable demand for each segment. User-specified demand segments. Integer values starting with 1 in the first row. Additional segements added in subsequent rows.|
|Cost\_of\_Demand\_Curtailment\_per\_MW |Cost of non-served energy/demand curtailment (for each segment), reported as a fraction of value of the lost load (non-served demand). If *Demand\_Segment = 1*, then this parameter is a scalar and equal to one. In general this parameter is a vector of length equal to the length of Demand\_Segment.|
|Max\_Demand\_Curtailment| Maximum time-dependent demand curtailable in each segment, reported as % of the demand in each zone and each period. *If Demand\_Segment = 1*, then this parameter is a scalar and equal to one. In general this parameter is a vector of length given by length of Demand\_segment.|
|Time\_Index |Index defining time step in the model.|
|Demand\_MW\_z* |Demand profile of a zone z* in MW; if multiple zones, this parameter will be a matrix with columns equal to number of zones (each column named appropriate zone number appended to parameter) and rows equal to number of time periods of grid operations being modeled.|
|Rep\_Periods |Number of representative periods (e.g. weeks, days) that are modeled to approximate annual grid operations. This is always a single entry. For a full-year model, this is `1`.|
|Timesteps\_per\_Rep\_Period |Number of timesteps per representative period (e.g. 168 if period is set as a week using hour-long time steps). This is always a single entry: all representative periods have the same length. For a full-year model, this entry is equal to the number of time steps.|
|Sub\_Weights |Number of annual time steps (e.g. hours) represented by each timestep in a representative period. The length of this column is equal to the number of representative periods. The sum of the elements should be equal to the total number of time steps in a model time horizon (e.g. 8760 hours if modeling 365 days or 8736 if modeling 52 weeks).|



#### 2.1.4 Generator\_variability.csv

This file contains the time-series of capacity factors / availability of each resource included in the `Generators_data.csv` file for each time step (e.g. hour) modeled.

• First column: The first column contains the time index of each row (starting in the second row) from 1 to N.

• Second column onwards: Resources are listed from the second column onward with headers matching each resource name in the `Generators_data.csv` file in any order. The availability for each resource at each time step is defined as a fraction of installed capacity and should be between 0 and 1. Note that for this reason, resource names specified in `Generators_data.csv` must be unique. Note that for Hydro reservoir resources (i.e. `HYDRO = 1` in the `Generators_data.csv`), values in this file correspond to inflows (in MWhs) to the hydro reservoir as a fraction of installed power capacity, rather than hourly capacity factor. Note that for co-located VRE and storage resources, solar PV and wind resource profiles should not be located in this file but rather in separate variability files (these variabilities can be in the `Generators_variability.csv` if time domain reduction functionalities will be utilized because the time domain reduction functionalities will separate the files after the clustering is completed).

#### 2.1.5 Generators\_data.csv

This file contains cost and performance parameters for various generators and other resources (storage, flexible demand, etc) included in the model formulation.

###### Table 5: Mandatory columns in the Generators\_data.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Resource | This column contains **unique** names of resources available to the model. Resources can include generators, storage, and flexible or time shiftable demand.|
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
|FLEX | {0, 1}, Flag to indicate membership in set of flexible demand-side resources (e.g. scheduleable or time shiftable demand such as automated EV charging, smart thermostat systems, irrigation pumping demand etc).|
||FLEX = 0: Not part of set (default) |
||FLEX = 1: Flexible demand resource.|
|HYDRO | {0, 1}, Flag to indicate membership in set of reservoir hydro resources.|
||HYDRO = 0: Not part of set (default) |
||HYDRO = 1: Hydropower with reservoir modeling, including inflows, spillage, ramp rate limits and minimum operating level and efficiency loss associated with discharging. Reservoir capacity can be represented as a ratio or energy to power. This type of plant cannot charge from grid.|
|ELECTROLYZER | {0, 1}, Flag to indicate membership in set of electrolysis resources (optional input column).|
||ELECTROLYZER = 0: Not part of set (default) |
||ELECTROLYZER = 1: Electrolyzer resources.|
|LDS | {0, 1}, Flag to indicate the resources eligible for long duration storage constraints with inter period linkage (e.g., reservoir hydro, hydrogen storage). Note that for co-located VRE-STOR resources, this flag must be 0 (LDS_VRE_STOR flag exists in VRE-STOR dataframe). |
||LDS = 0: Not part of set (default) |
||LDS = 1: Long duration storage resources|
|VRE_STOR | {0, 1}, Flag to indicate membership in set of co-located variable renewable energy resources (onshore wind and utility-scale solar PV) and storage resources (either short- or long-duration energy storage with symmetric or asymmetric charging or discharging capabilities).|
||VRE_STOR = 0: Not part of set (default) |
||VRE_STOR = 1: Co-located VRE and storage (VRE-STOR) resources. |
|**Existing technology capacity**|
|Existing\_Cap\_MW |The existing capacity of a power plant in MW. Note that for co-located VRE-STOR resources, this capacity represents the existing AC grid connection capacity in MW. |
|Existing\_Cap\_MWh |The existing capacity of storage in MWh where `STOR = 1` or `STOR = 2`. Note that for co-located VRE-STOR resources, this capacity represents the existing capacity of storage in MWh. |
|Existing\_Charge\_Cap\_MW |The existing charging capacity for resources where `STOR = 2`.|
|**Capacity/Energy requirements**|
|Max\_Cap\_MW |-1 (default) – no limit on maximum discharge capacity of the resource. If non-negative, represents maximum allowed discharge capacity (in MW) of the resource. Note that for co-located VRE-STOR resources, this capacity represents the maximum AC grid connection capacity in MW. |
|Max\_Cap\_MWh |-1 (default) – no limit on maximum energy capacity of the resource. If non-negative, represents maximum allowed energy capacity (in MWh) of the resource with `STOR = 1` or `STOR = 2`. Note that for co-located VRE-STOR resources, this capacity represents the maximum capacity of storage in MWh. |
|Max\_Charge\_Cap\_MW |-1 (default) – no limit on maximum charge capacity of the resource. If non-negative, represents maximum allowed charge capacity (in MW) of the resource with `STOR = 2`.|
|Min\_Cap\_MW |-1 (default) – no limit on minimum discharge capacity of the resource. If non-negative, represents minimum allowed discharge capacity (in MW) of the resource. Note that for co-located VRE-STOR resources, this capacity represents the minimum AC grid connection capacity in MW. |
|Min\_Cap\_MWh| -1 (default) – no limit on minimum energy capacity of the resource. If non-negative, represents minimum allowed energy capacity (in MWh) of the resource with `STOR = 1` or `STOR = 2`. Note that for co-located VRE-STOR resources, this capacity represents the minimum capacity of storage in MWh. |
|Min\_Charge\_Cap\_MW |-1 (default) – no limit on minimum charge capacity of the resource. If non-negative, represents minimum allowed charge capacity (in MW) of the resource with `STOR = 2`.|
|**Cost parameters**|
|Inv\_Cost\_per\_MWyr | Annualized capacity investment cost of a technology ($/MW/year). Note that for co-located VRE-STOR resources, this annualized capacity investment cost pertains to the grid connection.|
|Inv\_Cost\_per\_MWhyr | Annualized investment cost of the energy capacity for a storage technology ($/MW/year), applicable to either `STOR = 1` or `STOR = 2`. Note that for co-located VRE-STOR resources, this annualized investment cost of the energy capacity pertains to the co-located storage resource.|
|Inv\_Cost\_Charge\_per\_MWyr | Annualized capacity investment cost for the charging portion of a storage technology with `STOR = 2` ($/MW/year). |
|Fixed\_OM\_Cost\_per\_MWyr | Fixed operations and maintenance cost of a technology ($/MW/year). Note that for co-located VRE-STOR resources, this fixed operations and maintenance cost pertains to the grid connection.|
|Fixed\_OM\_Cost\_per\_MWhyr | Fixed operations and maintenance cost of the energy component of a storage technology ($/MWh/year). Note that for co-located VRE-STOR resources, this fixed operations and maintenance cost of the energy component pertains to the co-located storage resource. |
|Fixed\_OM\_Cost\_Charge\_per\_MWyr | Fixed operations and maintenance cost of the charging component of a storage technology of type `STOR = 2`. |
|Var\_OM\_Cost\_per\_MWh | Variable operations and maintenance cost of a technology ($/MWh). Note that for co-located VRE-STOR resources, these costs apply to the AC generation sent to the grid from the entire site. |
|Var\_OM\_Cost\_per\_MWhIn | Variable operations and maintenance cost of the charging aspect of a storage technology with `STOR = 2`, or variable operations and maintenance costs associated with flexible demand deferral with `FLEX = 1`. Otherwise 0 ($/MWh). Note that for co-located VRE-STOR resources, these costs must be 0 (specific variable operations and maintenance costs exist in VRE-STOR dataframe). |
|**Technical performance parameters**|
|Heat\_Rate\_MMBTU\_per\_MWh  |Heat rate of a generator or MMBtu of fuel consumed per MWh of electricity generated for export (net of on-site consumption). The heat rate is the inverse of the efficiency: a lower heat rate is better. Should be consistent with fuel prices in terms of reporting on higher heating value (HHV) or lower heating value (LHV) basis. |
|Fuel  |Fuel needed for a generator. The names should match with the ones in the `Fuels_data.csv`. |
|Self\_Disch  |[0,1], The power loss of storage technologies per hour (fraction loss per hour)- only applies to storage techs. Note that for co-located VRE-STOR resources, this value applies to the storage component of each resource.|
|Min\_Power |[0,1], The minimum generation level for a unit as a fraction of total capacity. This value cannot be higher than the smallest time-dependent CF value for a resource in `Generators_variability.csv`. Applies to thermal plants, and reservoir hydro resource (`HYDRO = 1`).|
|Ramp\_Up\_Percentage |[0,1], Maximum increase in power output from between two periods (typically hours), reported as a fraction of nameplate capacity. Applies to thermal plants, and reservoir hydro resource (`HYDRO = 1`).|
|Ramp\_Dn\_Percentage |[0,1], Maximum decrease in power output from between two periods (typically hours), reported as a fraction of nameplate capacity. Applies to thermal plants, and reservoir hydro resource (`HYDRO = 1`).|
|Eff\_Up  |[0,1], Efficiency of charging storage – applies to storage technologies (all STOR types except co-located storage resources).|
|Eff\_Down  |[0,1], Efficiency of discharging storage – applies to storage technologies (all STOR types except co-located storage resources). |
|Hydro\_Energy\_to\_Power\_Ratio  |The rated number of hours of reservoir hydro storage at peak discharge power output. Applies to `HYDRO = 1` (hours). |
|Min\_Duration  |Specifies the minimum ratio of installed energy to discharged power capacity that can be installed. Applies to STOR types 1 and 2 (hours). Note that for co-located VRE-STOR resources, this value does not apply. |
|Max\_Duration  |Specifies the maximum ratio of installed energy to discharged power capacity that can be installed. Applies to STOR types 1 and 2 (hours). Note that for co-located VRE-STOR resources, this value does not apply. |
|Max\_Flexible\_Demand\_Delay  |Maximum number of hours that demand can be deferred or delayed. Applies to resources with FLEX type 1 (hours). |
|Max\_Flexible\_Demand\_Advance  |Maximum number of hours that demand can be scheduled in advance of the original schedule. Applies to resources with FLEX type 1 (hours). |
|Flexible\_Demand\_Energy\_Eff  |[0,1], Energy efficiency associated with time shifting demand. Represents energy losses due to time shifting (or 'snap back' effect of higher consumption due to delay in use) that may apply to some forms of flexible demand. Applies to resources with FLEX type 1 (hours). For example, one may need to pre-cool a building more than normal to advance demand. |
|**Required for writing outputs**|
|region | Name of the model region|
|cluster | Number of the cluster when representing multiple clusters of a given technology in a given region.  |
|**MultiStage == 1**|
|Capital\_Recovery\_Period  |Capital recovery period (in years) used for determining overnight capital costs from annualized investment costs. Note that for co-located VRE-STOR resources, this value pertains to the grid connection (other capital recovery periods for different components of the resource can be found in the VRE-STOR dataframe). |
|Lifetime  |Lifetime (in years) used for determining endogenous retirements of newly built capacity.  Note that the same lifetime is used for each component of a co-located VRE-STOR resource. |
|Min\_Retired\_Cap\_MW  |Minimum required discharge capacity retirements in the current model period. This field can be used to enforce lifetime retirements of existing capacity. Note that for co-located VRE-STOR resources, this value pertains to the grid connection (other minimum required discharge capacity retirements for different components of the resource can be found in the VRE-STOR dataframe). |
|Min\_Retired\_Energy\_Cap\_MW  |Minimum required energy capacity retirements in the current model period. This field can be used to enforce lifetime retirements of existing energy capacity. Note that for co-located VRE-STOR resources, this value pertains to the storage component (other minimum required capacity retirements for different components of the resource can be found in the VRE-STOR dataframe).|
|Min\_Retired\_Charge\_Cap\_MW  |Minimum required energy capacity retirements in the current model period. This field can be used to enforce lifetime retirements of existing charge capacity. |
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
|ESR\_*| Flag to indicate which resources are considered for the Energy Share Requirement constraint. Note that this flag must be 0 for co-located VRE-STOR resources (policy inputs are read from the specific VRE-STOR dataframe).|
||1- included|
||0- excluded|
|**CapacityReserveMargin > 0**||
|CapRes\_* |[0,1], Fraction of the resource capacity eligible for contributing to the capacity reserve margin constraint (e.g. derate factor). Note that this fraction must be 0 for co-located VRE-STOR resources (policy inputs are read from the specific VRE-STOR dataframe).|
|**ModelingToGenerateAlternatives = 1**||
|MGA |Eligibility of the technology for Modeling To Generate Alternative (MGA) run. |
||1 = Technology is available for the MGA run.|
||0 = Technology is unavailable for the MGA run (e.g. storage technologies).|
|Resource\_Type |For the MGA run, we categorize all the resources in a few resource types. We then find maximally different generation portfolio based on these resource types. For example, existing solar and new solar resources could be represented by a resource type names `Solar`. Categorization of resources into resource types is user dependent. Note that this fraction must be 0 for co-located VRE-STOR resources (policy inputs are read from the specific VRE-STOR dataframe).|
|**MinCapReq = 1**|
|MinCapTag\_*| Eligibility of resources to participate in Minimum Technology Carveout constraint. \* corresponds to the ith row of the file `Minimum_capacity_requirement.csv`. Note that this eligibility must be 0 for co-located VRE-STOR resources (policy inputs are read from the specific VRE-STOR dataframe).|
|**MaxCapReq = 1**|
|MaxCapTag\_*| Eligibility of resources to participate in Maximum Technology Carveout constraint. \* corresponds to the ith row of the file `Maximum_capacity_requirement.csv`. Note that this eligibility must be 0 for co-located VRE-STOR resources (policy inputs are read from the specific VRE-STOR dataframe).|
|**PiecewiseFuelUsage-related parameters required if any resources have nonzero PWFU_Slope and PWFU_Intercept**|
|PWFU\_Slope\_*i| The slope (MMBTU/MWh) of segment i for the piecewise-linear fuel usage approximation|
|PWFU\_Intercept\_*i| The intercept (MMBTU) of segment i for the piecewise-linear fuel usage approximation. The slope and intercept parameters must be consistent with the Cap_Size of the plant.|
|**Electrolyzer related parameters required if the set ELECTROLYZER is not empty**|
|Hydrogen_MWh_Per_Tonne| Electrolyzer efficiency in megawatt-hours (MWh) of electricity per metric tonne of hydrogen produced (MWh/t)|
|Electrolyzer_Min_kt| Minimum annual quantity of hydrogen that must be produced by electrolyzer in kilotonnes (kt)|
|Hydrogen_Price_Per_Tonne| Price (or value) of hydrogen per metric tonne ($/t)|
|Qualified_Hydrogen_Supply| {0,1}, Indicates that generator or storage resources is eligible to supply electrolyzers in the same zone (used for hourly clean supply constraint)|
|**CO2-related parameters required if any resources have nonzero CO2_Capture_Fraction**|
|CO2\_Capture\_Fraction  |[0,1], The CO2 capture fraction of CCS-equipped power plants during steady state operation. This value should be 0 for generators without CCS. |
|CO2\_Capture\_Fraction\_Startup  |[0,1], The CO2 capture fraction of CCS-equipped power plants during the startup events. This value should be 0 for generators without CCS |
|Biomass | {0, 1}, Flag to indicate if generator uses biomass as feedstock (optional input column).|
||Biomass = 0: Not part of set (default). |
||Biomass = 1: Uses biomass as fuel.|
|CCS\_Disposal\_Cost\_per\_Metric_Ton | Cost associated with CCS disposal ($/tCO2), including pipeline, injection and storage costs of CCS-equipped generators.|



### 2.2 Optional inputs files

#### 2.2.1 Online Time-domain reduction

Modeling grid operations for each hour of the year can be computationally expensive for models with many zones and resources. Time-domain reduction is often employed in capacity expansion models as a way to balance model spatial and temporal resolution as well as representation of dispatch, while ensuring reasonable computational times. GenX allows the option of performing time-domain reduction on the user supplied time-series input data to produce a representative time series at the desired level of temporal resolution. The below table summarizes the list of parameters to be specified by the user to perform the time domain reduction implemented in GenX. These parameters are passed to GenX via the YAML file `time_domain_reduction_settings.yml`.

###### Table 7: Structure of the time_domain_reduction.yml file
---
|**Key** | **Description**|
| :------------ | :-----------|
|Timesteps\_per\_period | The number of timesteps (e.g., hours) in each representative period (i.e. 168 for weeks, 24 for days, 72 for three-day periods, etc).|
|UseExtremePeriods | 1 = Include outliers (by performance or demand/resource extreme) as their own representative extreme periods. This setting automatically includes periods based on criteria outlined in the dictionary `ExtremePeriods`. Extreme periods can be selected based on following criteria applied to demand profiles or solar and wind capacity factors profiles, at either the zonal or system level. A) absolute (timestep with min/max value) statistic (minimum, maximum) and B) integral (period with min/max summed value) statistic (minimum, maximum). For example, the user could want the hour with the most demand across the whole system to be included among the extreme periods. They would select Demand, System, Absolute, and Max.|
||0 = Do not include extreme periods.|
|ExtremePeriods | If UseExtremePeriods = 1, use this dictionary to select which types of extreme periods to use. Select by profile type (Demand, PV, or Wind), geography (Zone or System), grouping by timestep or by period (Absolute or Integral), and statistic (Maximum or Minimum).|
|ClusterMethod |Either `kmeans` or `kmedoids`, the method used to cluster periods and determine each time step's representative period.|
|ScalingMethod |Either ‘N' or ‘S', the decision to normalize ([0,1]) or standardize (mean 0, variance 1) the input data prior to clustering.|
|MinPeriods |The minimum number of representative periods used to represent the input data. If using UseExtremePeriods, this must be greater or equal to the number of selected extreme periods. If `IterativelyAddPeriods` is off, this will be the total number of representative periods.|
|MaxPeriods| The maximum number of representative periods - both clustered and extreme - that may be used to represent the input data.|
|IterativelyAddPeriods |1 = Add representative periods until the error threshold between input data and represented data is met or the maximum number of representative periods is reached.|
||0 = Use only the minimum number of representative periods. This minimum value includes the selected extreme periods if `UseExtremePeriods` is on.|
|Threshold |Iterative period addition will end if the period farthest from its representative period (as measured using Euclidean distance) is within this percentage of the total possible error (for normalization) or 95% of the total possible error (± 2 σ for standardization). E.g., for a threshold of 0.01, each period must be within 1% of the spread of possible error before the clustering iterations will terminate (or until the maximum is reached).|
|IterateMethod | Either ‘cluster' (Default) or ‘extreme', whether to increment the number of clusters to the kmeans/kmedoids method or to set aside the worst-fitting periods as a new extreme periods.|
|nReps |Default 200, the number of kmeans/kmedoids repetitions at the same setting.|
|DemandWeight| Default 1, a multiplier on demand columns to optionally prioritize better fits for demand profiles over resource capacity factor or fuel price profiles.|
|WeightTotal |Default 8760, the sum to which the relative weights of representative periods will be scaled.|
|ClusterFuelPrices| Either 1 or 0, whether or not to use the fuel price time series in `Fuels_data.csv` in the clustering process. If 'no', this function will still write `Fuels_data.csv` in the TimeDomainReductionFolder with reshaped fuel prices based on the number and size of the representative periods but will not use the fuel price time series for selection of representative periods.|



#### 2.2.2 Reserves.csv

This file includes parameter inputs needed to model time-dependent procurement of regulation and spinning reserves. This file is needed if `Reserves` flag is activated in the YAML file `genx_settings.yml`.

###### Table 8: Structure of the Reserves.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Reg\_Req\_Percent\_Demand |[0,1], Regulation requirement as a percent of time-dependent demand; here demand is the total across all model zones.|
|Reg\_Req\_Percent\_VRE |[0,1], Regulation requirement as a percent of time-dependent wind and solar generation (summed across all model zones).|
|Rsv\_Req\_Percent\_Demand [0,1], |Spinning up or contingency reserve requirement as a percent of time-dependent demand (which is summed across all zones).|
|Rsv\_Req\_Percent\_VRE |[0,1], Spinning up or contingency reserve requirement as a percent of time-dependent wind and solar generation (which is summed across all zones).|
|Unmet\_Rsv\_Penalty\_Dollar\_per\_MW |Penalty for not meeting time-dependent spinning reserve requirement ($/MW per time step).|
|Dynamic\_Contingency |Flags to include capacity (generation or transmission) contingency to be added to the spinning reserve requirement.|
|Dynamic\_Contingency |= 1: contingency set to be equal to largest installed thermal unit (only applied when `UCommit = 1`).|
||= 2: contingency set to be equal to largest committed thermal unit each time period (only applied when `UCommit = 1`).|
|Static\_Contingency\_MW |A fixed static contingency in MW added to reserve requirement. Applied when `UCommit = 1` and `DynamicContingency = 0`, or when `UCommit = 2`. Contingency term not included in operating reserve requirement when this value is set to 0 and DynamicContingency is not active.|



#### 2.2.3 Energy\_share\_requirement.csv

This file contains inputs specifying minimum energy share requirement policies, such as Renewable Portfolio Standard (RPS) or Clean Energy Standard (CES) policies. This file is needed if parameter EnergyShareRequirement has a non-zero value in the YAML file `genx_settings.yml`.

Note: this file should use the same region name as specified in the `Generators_data.csv` file.

###### Table 9: Structure of the Energy\_share\_requirement.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Region\_description |Region name|
|Network\_zones |zone number represented as z*|
|ESR\_* |[0,1], Energy share requirements as a share of zonal demand (calculated on an annual basis). * represents the number of the ESR constraint, given by the number of ESR\_* columns in the `Energy_share_requirement.csv` file.|



#### 2.2.4 CO2\_cap.csv

This file contains inputs specifying CO2 emission limits policies (e.g. emissions cap and permit trading programs). This file is needed if `CO2Cap` flag is activated in the YAML file `genx_settings.yml`. `CO2Cap` flag set to 1 represents mass-based (tCO2 ) emission target. `CO2Cap` flag set to 2 is specified when emission target is given in terms of rate (tCO2/MWh) and is based on total demand met. `CO2Cap` flag set to 3 is specified when emission target is given in terms of rate (tCO2 /MWh) and is based on total generation.

###### Table 10: Structure of the CO2\_cap.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Region\_description |Region name|
|Network\_zones| zone number represented as z*|
|CO\_2\_Cap\_Zone_* |If a zone is eligible for the emission limit constraint, then this column is set to 1, else 0.|
|CO\_2\_Max\_tons\_MWh_* |Emission limit in terms of rate|
|CO\_2\_Max\_Mtons_* |Emission limit in absolute values, in Million of tons |
| | where in the above inputs, * represents the number of the emission limit constraints. For example, if the model has 2 emission limit constraints applied separately for 2 zones, the above CSV file will have 2 columns for specifying emission limit in terms on rate: CO\_2\_Max\_tons\_MWh\_1 and CO\_2\_Max\_tons\_MWh\_2.|



#### 2.2.5 Capacity\_reserve\_margin.csv

This file contains the regional capacity reserve margin requirements. This file is needed if parameter CapacityReserveMargin has a non-zero value in the YAML file `genx_settings.yml`.

Note: this file should use the same region name as specified in the `Generators_data.csv` file

###### Table 11: Structure of the Capacity\_reserve\_margin.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Region\_description |Region name|
|Network\_zones |zone number represented as z*|
|CapRes\_* |[0,1], Capacity reserve margin requirements of a zone, reported as a fraction of demand|



#### 2.2.6 Minimum\_capacity\_requirement.csv

This file contains the minimum capacity carve-out requirement to be imposed (e.g. a storage capacity mandate or offshore wind capacity mandate). This file is needed if the `MinCapReq` flag has a non-zero value in the YAML file `genx_settings.yml`.

###### Table 12: Structure of the Minimum\_capacity\_requirement.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|MinCapReqConstraint |Index of the minimum capacity carve-out requirement.|
|Constraint\_Description |Names of minimum capacity carve-out constraints; not to be read by model, but used as a helpful notation to the model user. |
|Min\_MW | minimum capacity requirement [MW]|


Some of the columns specified in the input files in Section 2.2 and 2.1 are not used in the GenX model formulation. These columns are necessary for interpreting the model outputs and used in the output module of the GenX.

#### 2.2.7 Maximum\_capacity\_requirement.csv

This contains the maximum capacity limits to be imposed (e.g. limits on total deployment of solar, wind, or batteries in the system as a whole or in certain collections of zones).
It is required if the `MaxCapReq` flag has a non-zero value in `genx_settings.yml`.

###### Table 13: Structure of the Maximum\_capacity\_requirement.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|MaxCapReqConstraint |Index of the maximum capacity limit.|
|Constraint\_Description |Names of maximum capacity limit; not to be read by model, but used as a helpful notation to the model user. |
|Max\_MW | maximum capacity limit [MW]|


Some of the columns specified in the input files in Section 2.2 and 2.1 are not used in the GenX model formulation. These columns are necessary for interpreting the model outputs and used in the output module of the GenX.

#### 2.2.8 Method\_of\_morris\_range.csv

This file contains the settings parameters required to run the Method of Morris algorithm in GenX. This file is needed if the `MethodofMorris` flag is ON in the YAML file `genx_settings.yml`.

###### Table 14: Structure of the Method\_of\_morris\_range.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Resource | This column contains **unique** names of resources available to the model. Resources can include generators, storage, and flexible or time shiftable demand.|
|Zone | Integer representing zone number where the resource is located. |
|Lower\_bound | Percentage lower deviation from the nominal value|
|Upper\_bound| Percentage upper deviation from the nominal value|
|Parameter| Column from the `Generators_data.csv` file containing uncertain parameters|
|Group| Group the uncertain parameters that will be changed all at once while performing the sensitivity analysis. For example, if the fuel price of natural gas is uncertain, all generators consuming natural gas should be in the same group. Group name is user defined|
|p_steps| Number of steps between upper and lower bound|
|total\_num\_trajectory| Total number of trakectories through the design matrix|
|num\_trajectory| Selected number of trajectories throigh the design matrix|
|len\_design\_mat| Length of the design matrix|
|policy| Name of the policy|

Notes:
1. Upper and lower bounds are specified in terms of percentage deviation from the nominal value.
2. Percentage variation for uncertain parameters in a given group is identical. For example, if solar cluster 1 and solar cluster 2 both belong to the ‘solar’ group, their Lower_bound and Upper_bound must be identical
3. P\_steps should at least be = 1\%, i.e., Upper\_bound – Lower\_bound $<$ p\_steps
4. P\_steps for parameters in one group must be identical
5. Total\_num\_trajectory should be around 3 to 4 times the total number of uncertain parameters
6. num\_trajectory should be approximately equal to the total number of uncertain parameters
7. len\_design_mat should be 1.5 to 2 times the total number of uncertain parameters
8. Higher number of num\_trajectory and len_design_mat would lead to higher accuracy
9. Upper and lower bounds should be specified for all the resources included in the `Generators_data.csv` file. If a parameter related to a particular resource is not uncertain, specify upper bound = lower bound = 0.

#### 2.2.9 Vre\_and\_stor\_data.csv

This file contains additional cost and performance parameters for specifically co-located VRE and storage resources included in the model formulation.
Each co-located VRE and storage generator must be explicitly listed in the `Generators_data.csv` and have the matching unique **Resource** name and **R\_ID** in both the `Generators_data.csv` and the `Vre_and_stor_data.csv`.
This file supplements the `Generators_data.csv` by specifically adding VRE-STOR data and flags that are unique to how this module functions.
Some cost and performance parameters for each co-located resource will be read in from the `Generators_data.csv` (as indicated above in the explanation of inputs from `Generators_data.csv` and from Table 15) and the rest of the specific inputs will be noted here for each resource.
Each co-located VRE and storage resource can be easily configured to contain either a co-located VRE-storage resource, standalone VRE resource (either wind, solar PV, or both), or standalone storage resource.

###### Table 15: Additional & modified columns for co-located VRE-STOR resources in the Generators\_data.csv file (already noted above but explicitly defined here)
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|**Added Columns**|
|VRE_STOR | {0, 1}, Flag to indicate membership in set of co-located variable renewable energy resources (onshore wind and utility-scale solar PV) and storage resources (either short- or long-duration energy storage with symmetric or asymmetric charging or discharging capabilities).|
||VRE_STOR = 0: Not part of set (default) |
||VRE_STOR = 1: Co-located VRE and storage (VRE-STOR) resources. |
|**Modified Columns**|
|Existing\_Cap\_MW |The existing capacity of a power plant in MW. Note that for co-located VRE-STOR resources, this capacity represents the existing AC grid connection capacity in MW. |
|Existing\_Cap\_MWh |The existing capacity of storage in MWh where `VRE_STOR = 1`. Note that for co-located VRE-STOR resources, this capacity represents the existing capacity of storage in MWh. |
|Max\_Cap\_MW |-1 (default) – no limit on maximum discharge capacity of the resource. If non-negative, represents maximum allowed discharge capacity (in MW) of the resource. Note that for co-located VRE-STOR resources, this capacity represents the maximum AC grid connection capacity in MW. |
|Max\_Cap\_MWh |-1 (default) – no limit on maximum energy capacity of the resource. If non-negative, represents maximum allowed energy capacity (in MWh) of the resource with or `VRE_STOR = 1`. Note that for co-located VRE-STOR resources, this capacity represents the maximum capacity of storage in MWh. |
|Min\_Cap\_MW |-1 (default) – no limit on minimum discharge capacity of the resource. If non-negative, represents minimum allowed discharge capacity (in MW) of the resource. Note that for co-located VRE-STOR resources, this capacity represents the minimum AC grid connection capacity in MW. |
|Min\_Cap\_MWh| -1 (default) – no limit on minimum energy capacity of the resource. If non-negative, represents minimum allowed energy capacity (in MWh) of the resource with `STOR = 1` or `STOR = 2` or `VRE_STOR = 1`. Note that for co-located VRE-STOR resources, this capacity represents the minimum capacity of storage in MWh. |
|Inv\_Cost\_per\_MWyr | Annualized capacity investment cost of a technology ($/MW/year). Note that for co-located VRE-STOR resources, this annualized capacity investment cost pertains to the grid connection.|
|Inv\_Cost\_per\_MWhyr | Annualized investment cost of the energy capacity for a storage technology ($/MW/year), applicable to either `STOR = 1` or `STOR = 2`. Note that for co-located VRE-STOR resources, this annualized investment cost of the energy capacity pertains to the co-located storage resource.|
|Fixed\_OM\_Cost\_per\_MWyr | Fixed operations and maintenance cost of a technology ($/MW/year). Note that for co-located VRE-STOR resources, this fixed operations and maintenance cost pertains to the grid connection.|
|Fixed\_OM\_Cost\_per\_MWhyr | Fixed operations and maintenance cost of the energy component of a storage technology ($/MWh/year). Note that for co-located VRE-STOR resources, this fixed operations and maintenance cost of the energy component pertains to the co-located storage resource. |
|Self\_Disch  |[0,1], The power loss of storage technologies per hour (fraction loss per hour)- only applies to storage techs. Note that for co-located VRE-STOR resources, this value applies to the storage component of each resource.|
|Reg\_Cost | **(If Reserves = 1)** Cost of providing regulation reserves ($/MW per time step/hour).|
|Rsv\_Cost | **(If Reserves = 1)** Cost of providing upwards spinning or contingency reserves ($/MW per time step/hour).|
|Reg\_Max | **(If Reserves = 1)** [0,1], Fraction of nameplate capacity that can committed to provided regulation reserves. .|
|Rsv\_Max | **(If Reserves = 1)** [0,1], Fraction of nameplate capacity that can committed to provided upwards spinning or contingency reserves.|
|Capital\_Recovery\_Period  | **(If MultiStage == 1)** Capital recovery period (in years) used for determining overnight capital costs from annualized investment costs. Note that for co-located VRE-STOR resources, this value pertains to the grid connection (other capital recovery periods for different components of the resource can be found in the VRE-STOR dataframe). |
|Lifetime  | **(If MultiStage == 1)** Lifetime (in years) used for determining endogenous retirements of newly built capacity.  Note that the same lifetime is used for each component of a co-located VRE-STOR resource. |
|Min\_Retired\_Cap\_MW  | **(If MultiStage == 1)** Minimum required discharge capacity retirements in the current model period. This field can be used to enforce lifetime retirements of existing capacity. Note that for co-located VRE-STOR resources, this value pertains to the grid connection (other minimum required discharge capacity retirements for different components of the resource can be found in the VRE-STOR dataframe). |
|Min\_Retired\_Energy\_Cap\_MW  | **(If MultiStage == 1)** Minimum required energy capacity retirements in the current model period. This field can be used to enforce lifetime retirements of existing energy capacity. Note that for co-located VRE-STOR resources, this value pertains to the storage component (other minimum required capacity retirements for different components of the resource can be found in the VRE-STOR dataframe).|
|MinCapTag\_*| **(If MinCapReq = 1)** Eligibility of resources' grid connection to participate in Minimum Technology Carveout constraint. \* corresponds to the ith row of the file `Minimum_capacity_requirement.csv`. Note that this eligibility must only apply to the interconnection capacity for co-located VRE-STOR resources (policy inputs for solar PV, wind, or battery minimum capacities are read from the specific VRE-STOR dataframe).|
|MaxCapTag\_*| **(If MaxCapReq = 1)** Eligibility of resources' grid connection to participate in Maximum Technology Carveout constraint. \* corresponds to the ith row of the file `Maximum_capacity_requirement.csv`. Note that this eligibility must only apply to the interconnection capacity for co-located VRE-STOR resources (policy inputs for solar PV, wind, or battery maxmum capacities are read from the specific VRE-STOR dataframe).|
|**Columns that Must Be Set to Zero**|
|Var\_OM\_Cost\_per\_MWhIn | Variable operations and maintenance cost of the charging aspect of a storage technology with `STOR = 2`, or variable operations and maintenance costs associated with flexible demand deferral with `FLEX = 1`. Otherwise 0 ($/MWh). Note that for co-located VRE-STOR resources, these costs must be 0 (specific variable operations and maintenance costs exist in VRE-STOR dataframe). |
|ESR\_*| **(If EnergyShareRequirement > 0)** Flag to indicate which resources are considered for the Energy Share Requirement constraint. Note that this flag must be 0 for co-located VRE-STOR resources (policy inputs are read from the specific VRE-STOR dataframe).|
|CapRes\_* | **(If CapacityReserveMargin > 0)** [0,1], Fraction of the resource capacity eligible for contributing to the capacity reserve margin constraint (e.g. derate factor). Note that this fraction must be 0 for co-located VRE-STOR resources (policy inputs are read from the specific VRE-STOR dataframe).|
|LDS | {0, 1}, Flag to indicate the resources eligible for long duration storage constraints with inter period linkage (e.g., reservoir hydro, hydrogen storage). Note that for co-located VRE-STOR resources, this flag must be 0 (LDS_VRE_STOR flag exists in VRE-STOR dataframe). |
||LDS = 0: Not part of set (default) |
||LDS = 1: Long duration storage resources|

###### Table 16: Mandatory columns in the Vre\_and\_stor\_data.csv file

---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Resource | This column contains **unique** names of the co-located VRE and storage resources available to the model and must match the `Generators_data.csv`. |
|Zone | Integer representing zone number where the resource is located. |
|R\_ID | Each resource receives a **unique** number ID, which is explicitly defined in the `Generators_data.csv` or implicitly defined in the GenX model after all of the data has been loaded. The R\_ID of each co-located resource must match the R\_ID either explicitly or implicitly defined in the `Generators_data.csv`.|
|**Technology type flags**|
|SOLAR | {0, 1}, Flag to indicate membership in the set of co-located VRE-storage resources with a solar PV component.|
||SOLAR = 0: Not part of set (default) |
||SOLAR = 1: If the co-located VRE-storage resource can produce solar PV energy. ||
|WIND | {0, 1}, Flag to indicate membership in the set of co-located VRE-storage resources with a wind component.|
||WIND = 0: Not part of set (default) |
||WIND = 1: If the co-located VRE-storage resource can produce wind energy. ||
|STOR_DC_DISCHARGE | {0, 1, 2}, Flag to indicate membership in set of co-located VRE-storage resources that discharge behind the meter and through the inverter (DC).|
||STOR_DC_DISCHARGE = 0: Not part of set (default) |
||STOR_DC_DISCHARGE = 1: If the co-located VRE-storage resource contains symmetric charge/discharge power capacity with charging capacity equal to discharging capacity (e.g. lithium-ion battery storage). Note that if STOR_DC_DISCHARGE = 1, STOR_DC_CHARGE = 1.|
||STOR_DC_DISCHARGE = 2: If the co-located VRE-storage resource has asymmetric discharge capacities using distinct processes (e.g. hydrogen electrolysis, storage, and conversion to power using fuel cell or combustion turbine).|
|STOR_DC_CHARGE | {0, 1, 2}, Flag to indicate membership in set of co-located VRE-storage resources that charge through the inverter (DC).|
||STOR_DC_CHARGE = 0: Not part of set (default) |
||STOR_DC_CHARGE = 1: If the co-located VRE-storage resource contains symmetric charge/discharge power capacity with charging capacity equal to discharging capacity (e.g. lithium-ion battery storage). Note that if STOR_DC_CHARGE = 1, STOR_DC_DISCHARGE = 1.|
||STOR_DC_CHARGE = 2: If the co-located VRE-storage resource has asymmetric charge capacities using distinct processes (e.g. hydrogen electrolysis, storage, and conversion to power using fuel cell or combustion turbine).|
|STOR_AC_DISCHARGE | {0, 1, 2}, Flag to indicate membership in set of co-located VRE-storage resources that discharges AC.|
||STOR_AC_DISCHARGE = 0: Not part of set (default) |
||STOR_AC_DISCHARGE = 1: If the co-located VRE-storage resource contains symmetric charge/discharge power capacity with charging capacity equal to discharging capacity (e.g. lithium-ion battery storage). Note that if STOR_AC_DISCHARGE = 1, STOR_AC_CHARGE = 1.|
||STOR_AC_DISCHARGE = 2: If the co-located VRE-storage resource has asymmetric discharge capacities using distinct processes (e.g. hydrogen electrolysis, storage, and conversion to power using fuel cell or combustion turbine).|
|STOR_AC_CHARGE | {0, 1, 2}, Flag to indicate membership in set of co-located VRE-storage resources that charge AC.|
||STOR_AC_CHARGE = 0: Not part of set (default) |
||STOR_AC_CHARGE = 1: If the co-located VRE-storage resource contains symmetric charge/discharge power capacity with charging capacity equal to discharging capacity (e.g. lithium-ion battery storage). Note that if STOR_AC_CHARGE = 1, STOR_AC_DISCHARGE = 1.|
||STOR_AC_CHARGE = 2: If the co-located VRE-storage resource has asymmetric charge capacities using distinct processes (e.g. hydrogen electrolysis, storage, and conversion to power using fuel cell or combustion turbine).|
|LDS_VRE_STOR | {0, 1}, Flag to indicate the co-located VRE-storage resources eligible for long duration storage constraints with inter period linkage (e.g., reservoir hydro, hydrogen storage). |
||LDS_VRE_STOR = 0: Not part of set (default) |
||LDS_VRE_STOR = 1: Long duration storage resources|
|**Existing technology capacity**|
|Existing\_Cap\_Inverter\_MW |The existing capacity of co-located VRE-STOR resource's inverter in MW (AC). |
|Existing\_Cap\_Solar\_MW |The existing capacity of co-located VRE-STOR resource's solar PV in MW (DC). |
|Existing\_Cap\_Wind\_MW |The existing capacity of co-located VRE-STOR resource's wind in MW (AC). |
|Existing\_Cap\_Discharge\_DC\_MW |The existing discharge capacity of co-located VRE-STOR resource's storage component in MW (DC). Note that this only applies to resources where `STOR_DC_DISCHARGE = 2`. |
|Existing\_Cap\_Charge\_DC\_MW |The existing charge capacity of co-located VRE-STOR resource's storage component in MW (DC). Note that this only applies to resources where `STOR_DC_CHARGE = 2`. |
|Existing\_Cap\_Discharge\_AC\_MW |The existing discharge capacity of co-located VRE-STOR resource's storage component in MW (AC). Note that this only applies to resources where `STOR_AC_DISCHARGE = 2`. |
|Existing\_Cap\_Charge\_AC\_MW |The existing charge capacity of co-located VRE-STOR resource's storage component in MW (AC). Note that this only applies to resources where `STOR_DC_CHARGE = 2`. |
|**Capacity/Energy requirements**|
|Max\_Cap\_Inverter\_MW |-1 (default) – no limit on maximum inverter capacity of the resource. If non-negative, represents maximum allowed inverter capacity (in MW AC) of the resource. |
|Max\_Cap\_Solar\_MW |-1 (default) – no limit on maximum solar PV capacity of the resource. If non-negative, represents maximum allowed solar PV capacity (in MW DC) of the resource. |
|Max\_Cap\_Wind\_MW |-1 (default) – no limit on maximum wind capacity of the resource. If non-negative, represents maximum allowed wind capacity (in MW AC) of the resource. |
|Max\_Cap\_Discharge\_DC\_MW |-1 (default) – no limit on maximum DC discharge capacity of the resource. If non-negative, represents maximum allowed DC discharge capacity (in MW DC) of the resource with `STOR_DC_DISCHARGE = 2`.|
|Max\_Cap\_Charge\_DC\_MW |-1 (default) – no limit on maximum DC charge capacity of the resource. If non-negative, represents maximum allowed DC charge capacity (in MW DC) of the resource with `STOR_DC_CHARGE = 2`.|
|Max\_Cap\_Discharge\_AC\_MW |-1 (default) – no limit on maximum AC discharge capacity of the resource. If non-negative, represents maximum allowed AC discharge capacity (in MW AC) of the resource with `STOR_AC_DISCHARGE = 2`.|
|Max\_Cap\_Charge\_AC\_MW |-1 (default) – no limit on maximum AC charge capacity of the resource. If non-negative, represents maximum allowed AC charge capacity (in MW AC) of the resource with `STOR_AC_CHARGE = 2`.|
|Min\_Cap\_Inverter\_MW |-1 (default) – no limit on minimum inverter capacity of the resource. If non-negative, represents minimum allowed inverter capacity (in MW AC) of the resource. |
|Min\_Cap\_Solar\_MW |-1 (default) – no limit on minimum solar PV capacity of the resource. If non-negative, represents minimum allowed solar PV capacity (in MW DC) of the resource. |
|Min\_Cap\_Wind\_MW |-1 (default) – no limit on minimum wind capacity of the resource. If non-negative, represents minimum allowed wind capacity (in MW AC) of the resource. |
|Min\_Cap\_Discharge\_DC\_MW |-1 (default) – no limit on minimum DC discharge capacity of the resource. If non-negative, represents minimum allowed DC discharge capacity (in MW DC) of the resource with `STOR_DC_DISCHARGE = 2`.|
|Min\_Cap\_Charge\_DC\_MW |-1 (default) – no limit on minimum DC charge capacity of the resource. If non-negative, represents minimum allowed DC charge capacity (in MW DC) of the resource with `STOR_DC_CHARGE = 2`.|
|Min\_Cap\_Discharge\_AC\_MW |-1 (default) – no limit on minimum AC discharge capacity of the resource. If non-negative, represents minimum allowed AC discharge capacity (in MW AC) of the resource with `STOR_AC_DISCHARGE = 2`.|
|Min\_Cap\_Charge\_AC\_MW |-1 (default) – no limit on minimum AC charge capacity of the resource. If non-negative, represents minimum allowed AC charge capacity (in MW AC) of the resource with `STOR_AC_CHARGE = 2`.|
|**Cost parameters**|
|Inv\_Cost\_Inverter\_per\_MWyr | Annualized capacity investment cost of the inverter component ($/MW-AC/year). |
|Inv\_Cost\_Solar\_per\_MWyr | Annualized capacity investment cost of the solar PV component ($/MW-DC/year). |
|Inv\_Cost\_Wind\_per\_MWyr | Annualized capacity investment cost of the wind component ($/MW-AC/year). |
|Inv\_Cost\_Discharge\_DC\_per\_MWyr | Annualized capacity investment cost for the discharging portion of a storage technology with `STOR_DC_DISCHARGE = 2` ($/MW-DC/year). |
|Inv\_Cost\_Charge\_DC\_per\_MWyr | Annualized capacity investment cost for the charging portion of a storage technology with `STOR_DC_CHARGE = 2` ($/MW-DC/year). |
|Inv\_Cost\_Discharge\_AC\_per\_MWyr | Annualized capacity investment cost for the discharging portion of a storage technology with `STOR_AC_DISCHARGE = 2` ($/MW-AC/year). |
|Inv\_Cost\_Charge\_AC\_per\_MWyr | Annualized capacity investment cost for the charging portion of a storage technology with `STOR_AC_CHARGE = 2` ($/MW-AC/year). |
|Fixed\_OM\_Inverter\_Cost\_per\_MWyr | Fixed operations and maintenance cost of the inverter component ($/MW-AC/year).|
|Fixed\_OM\_Solar\_Cost\_per\_MWyr | Fixed operations and maintenance cost of the solar PV component ($/MW-DC/year).|
|Fixed\_OM\_Wind\_Cost\_per\_MWyr | Fixed operations and maintenance cost of the wind component ($/MW-AC/year).|
|Fixed\_OM\_Cost\_Discharge\_DC\_per\_MWyr | Fixed operations and maintenance cost of the discharging component of a storage technology with `STOR_DC_DISCHARGE = 2` ($/MW-DC/year).|
|Fixed\_OM\_Cost\_Charge\_DC\_per\_MWyr | Fixed operations and maintenance cost of the charging component of a storage technology with `STOR_DC_CHARGE = 2` ($/MW-DC/year).|
|Fixed\_OM\_Cost\_Discharge\_AC\_per\_MWyr | Fixed operations and maintenance cost of the discharging component of a storage technology with `STOR_AC_DISCHARGE = 2` ($/MW-AC/year).|
|Fixed\_OM\_Cost\_Charge\_AC\_per\_MWyr | Fixed operations and maintenance cost of the charging component of a storage technology with `STOR_AC_CHARGE = 2` ($/MW-AC/year).|
|Var\_OM\_Cost\_per\_MWh\_Solar | Variable operations and maintenance cost of the solar PV component (multiplied by the inverter efficiency for AC terms) ($/MWh). |
|Var\_OM\_Cost\_per\_MWh\_Wind | Variable operations and maintenance cost of the wind component ($/MWh). |
|Var\_OM\_Cost\_per\_MWh\_Discharge_DC | Variable operations and maintenance cost of the discharging component of a storage technology with `STOR_DC_DISCHARGE = 2` (multiplied by the inverter efficiency for AC terms) ($/MWh). |
|Var\_OM\_Cost\_per\_MWh\_Charge_DC | Variable operations and maintenance cost of the charging component of a storage technology with `STOR_DC_CHARGE = 2` (divided by the inverter efficiency for AC terms) ($/MWh). |
|Var\_OM\_Cost\_per\_MWh\_Discharge_AC | Variable operations and maintenance cost of the discharging component of a storage technology with `STOR_AC_DISCHARGE = 2` ($/MWh). |
|Var\_OM\_Cost\_per\_MWh\_Charge_AC | Variable operations and maintenance cost of the charging component of a storage technology with `STOR_AC_CHARGE = 2` ($/MWh). |
|**Technical performance parameters**|
|EtaInverter |[0,1], Inverter efficiency representing losses from converting DC to AC power and vice versa for each technology |
|Inverter_Ratio_Solar  |-1 (default) - no required ratio between solar PV capacity built to inverter capacity built. If non-negative, represents the ratio of solar PV capacity built to inverter capacity built.|
|Inverter_Ratio_Wind  |-1 (default) - no required ratio between wind capacity built to grid connection capacity built. If non-negative, represents the ratio of wind capacity built to grid connection capacity built.|
|Power\_to\_Energy\_AC  |The power to energy conversion for the storage component for AC discharging/charging of symmetric storage resources.|
|Power\_to\_Energy\_DC  |The power to energy conversion for the storage component for DC discharging/charging of symmetric storage resources.|
|Eff\_Up\_DC  |[0,1], Efficiency of DC charging storage – applies to storage technologies (all STOR types). |
|Eff\_Down\_DC  |[0,1], Efficiency of DC discharging storage – applies to storage technologies (all STOR types). |
|Eff\_Up\_AC  |[0,1], Efficiency of AC charging storage – applies to storage technologies (all STOR types). |
|Eff\_Down\_AC  |[0,1], Efficiency of AC discharging storage – applies to storage technologies (all STOR types). |
|**Required for writing outputs**|
|region | Name of the model region|
|cluster | Number of the cluster when representing multiple clusters of a given technology in a given region.  |
|technology | Non-unique name of resource (e.g. solar PV, wind) to classify each resource for post-processing purposes.  |
|**MultiStage == 1**|
|Capital\_Recovery\_Period_DC  |Capital recovery period (in years) used for determining overnight capital costs from annualized investment costs for the inverter component. |
|Capital\_Recovery\_Period_Solar  |Capital recovery period (in years) used for determining overnight capital costs from annualized investment costs for the solar PV component. |
|Capital\_Recovery\_Period_Wind  |Capital recovery period (in years) used for determining overnight capital costs from annualized investment costs for the wind component. |
|Capital\_Recovery\_Period_Discharge_DC  |Capital recovery period (in years) used for determining overnight capital costs from annualized investment costs for the discharge DC component when `STOR_DC_DISCHARGE = 2  `. |
|Capital\_Recovery\_Period_Charge_DC  |Capital recovery period (in years) used for determining overnight capital costs from annualized investment costs for the charge DC component when `STOR_DC_CHARGE = 2  `. |
|Capital\_Recovery\_Period_Discharge_AC  |Capital recovery period (in years) used for determining overnight capital costs from annualized investment costs for the discharge AC component when `STOR_AC_DISCHARGE = 2  `. |
|Capital\_Recovery\_Period_Charge_AC  |Capital recovery period (in years) used for determining overnight capital costs from annualized investment costs for the charge AC component when `STOR_AC_CHARGE = 2  `. |
|Min\_Retired\_Cap\_Inverter\_MW  |Minimum required inverter capacity retirements in the current model period. This field can be used to enforce lifetime retirements of existing capacity.|
|Min\_Retired\_Cap\_Solar\_MW  |Minimum required solar capacity retirements in the current model period. This field can be used to enforce lifetime retirements of existing capacity.|
|Min\_Retired\_Cap\_Wind\_MW  |Minimum required wind capacity retirements in the current model period. This field can be used to enforce lifetime retirements of existing capacity.|
|Min\_Retired\_Cap\_Discharge_DC\_MW  |Minimum required discharge capacity retirements in the current model period for storage resources with `STOR_DC_DISCHARGE = 2`. This field can be used to enforce lifetime retirements of existing capacity.|
|Min\_Retired\_Cap\_Charge_DC\_MW  |Minimum required charge capacity retirements in the current model period for storage resources with `STOR_DC_CHARGE = 2`. This field can be used to enforce lifetime retirements of existing capacity.|
|Min\_Retired\_Cap\_Discharge_AC\_MW  |Minimum required discharge capacity retirements in the current model period for storage resources with `STOR_AC_DISCHARGE = 2`. This field can be used to enforce lifetime retirements of existing capacity.|
|Min\_Retired\_Cap\_Charge_AC\_MW  |Minimum required charge capacity retirements in the current model period for storage resources with `STOR_AC_CHARGE = 2`. This field can be used to enforce lifetime retirements of existing capacity.|
| WACC\_DC | The line-specific weighted average cost of capital for the inverter component. |
| WACC\_Solar | The line-specific weighted average cost of capital for the solar PV component. |
| WACC\_Wind | The line-specific weighted average cost of capital for the wind component. |
| WACC\_Discharge\_DC | The line-specific weighted average cost of capital for the discharging DC storage component with `STOR_DC_DISCHARGE = 2`. |
| WACC\_Charge\_DC | The line-specific weighted average cost of capital for the charging DC storage component with `STOR_DC_CHARGE = 2`. |
| WACC\_Discharge\_AC | The line-specific weighted average cost of capital for the discharging AC storage component with `STOR_AC_DISCHARGE = 2`. |
| WACC\_Charge\_AC | The line-specific weighted average cost of capital for the charging AC storage component with `STOR_AC_CHARGE = 2`. |

###### Table 17: Settings-specific columns in the Vre\_stor\_data.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|**EnergyShareRequirement > 0**||
|ESRVreStor\_*| Flag to indicate which resources are considered for the Energy Share Requirement constraint. |
||1- included|
||0- excluded|
|**CapacityReserveMargin > 0**||
|CapResVreStor\_* |[0,1], Fraction of the resource capacity eligible for contributing to the capacity reserve margin constraint (e.g. derate factor). |
|**MinCapReq = 1**|
|MinCapTagSolar\_*| Eligibility of resources with a solar PV component (multiplied by the inverter efficiency for AC terms) to participate in Minimum Technology Carveout constraint. \* corresponds to the ith row of the file `Minimum_capacity_requirement.csv`. |
|MinCapTagWind\_*| Eligibility of resources with a wind component to participate in Minimum Technology Carveout constraint (AC terms). \* corresponds to the ith row of the file `Minimum_capacity_requirement.csv`. |
|MinCapTagStor\_*| Eligibility of resources with a storage component to participate in Minimum Technology Carveout constraint (discharge capacity in AC terms). \* corresponds to the ith row of the file `Minimum_capacity_requirement.csv`.|
|**MaxCapReq = 1**|
|MaxCapTagSolar\_*| Eligibility of resources with a solar PV component (multiplied by the inverter efficiency for AC terms) to participate in Maximum Technology Carveout constraint. \* corresponds to the ith row of the file `Maximum_capacity_requirement.csv`. |
|MaxCapTagWind\_*| Eligibility of resources with a wind component to participate in Maximum Technology Carveout constraint (AC terms). \* corresponds to the ith row of the file `Maximum_capacity_requirement.csv`. |
|MaxCapTagStor\_*| Eligibility of resources with a storage component to participate in Maximum Technology Carveout constraint (discharge capacity in AC terms). \* corresponds to the ith row of the file `Maximum_capacity_requirement.csv`.|

#### 2.2.10 Vre\_and\_stor\_solar\_variability.csv

This file contains the time-series of capacity factors / availability of the solar PV component (DC capacity factors) of each co-located resource included in the `Vre_and_stor_data.csv` file for each time step (e.g. hour) modeled.

• first column: The first column contains the time index of each row (starting in the second row) from 1 to N.

• Second column onwards: Resources are listed from the second column onward with headers matching each resource name in the `Generators_data.csv` and `Vre_and_stor_data.csv` files in any order. The availability for each resource at each time step is defined as a fraction of installed capacity and should be between 0 and 1. Note that for this reason, resource names specified in `Generators_data.csv` and `Vre_and_stor_data.csv` must be unique. 

#### 2.2.11 Vre\_and\_stor\_wind\_variability.csv

This file contains the time-series of capacity factors / availability of the wind component (AC capacity factors) of each co-located resource included in the `Vre_and_stor_data.csv` file for each time step (e.g. hour) modeled.

• First column: The first column contains the time index of each row (starting in the second row) from 1 to N.

• Second column onwards: Resources are listed from the second column onward with headers matching each resource name in the `Generators_data.csv` and `Vre_and_stor_data.csv` files in any order. The availability for each resource at each time step is defined as a fraction of installed capacity and should be between 0 and 1. Note that for this reason, resource names specified in `Generators_data.csv` and `Vre_and_stor_data.csv` must be unique. 


## 3 Outputs

The table below summarizes the units of each output variable reported as part of the various CSV files produced after each model run. The reported units are also provided. If a result file includes time-dependent values, the value will not include the hour weight in it. An annual sum ("AnnualSum") column/row will be provided whenever it is possible (e.g., `emissions.csv`).

### 3.1 Default output files


#### 3.1.1 capacity.csv

Reports optimal values of investment variables (except StartCap, which is an input)

###### Table 15: Structure of the capacity.csv file
---
|**Output** |**Description** |**Units** |
| :------------ | :-----------|:-----------|
| StartCap |Initial power capacity of each resource type in each zone; this is an input |MW |
| RetCap |Retired power capacity of each resource type in each zone |MW |
| NewCap |Installed capacity of each resource type in each zone |MW|
| EndCap| Total power capacity of each resource type in each zone |MW |
| CapacityConstraintDual |Shadow price of the capacity limit set by Max_Cap_MW for each resource type in each zone. Values are multiplied by -1 so that the output is >=0. |$/MW |
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

###### Table 16: Structure of the costs.csv file
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

###### Table 17: Structure of emission prices in the emissions.csv file
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

Reports marginal electricity price for each model zone and time step. Marginal electricity price is equal to the dual variable of the power balance constraint. If GenX is configured as a mixed integer linear program, then this output is only generated if `WriteShadowPrices` flag is activated. If configured as a linear program (i.e. linearized unit commitment or economic dispatch) then output automatically available.


#### 3.1.8 status.csv

Reports computational performance of the model and objective function related information.

###### Table 18: Structure of the status.csv file
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

###### Table 19: Stucture of the NetRevenue.csv file
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

#### 3.2.9 vre_stor_capacity.csv

Reports optimal values of investment variables (except StartCap, which is an input) for co-located VRE and storage resources

###### Table 14: Structure of the vre_stor_capacity.csv file
---
|**Output** |**Description** |**Units** |
| :------------ | :-----------|:-----------|
| StartCapSolar |Initial solar PV capacity of each resource type in each zone; this is an input |MW DC|
| RetCapSolar |Retired solar PV capacity of each resource type in each zone |MW DC|
| NewCapSolar |Installed solar PV capacity of each resource type in each zone |MW DC|
| EndCapSolar| Total solar PV capacity of each resource type in each zone |MW DC|
| StartCapWind |Initial wind capacity of each resource type in each zone; this is an input |MW AC|
| RetCapWind |Retired wind capacity of each resource type in each zone |MW AC|
| NewCapWind |Installed wind capacity of each resource type in each zone |MW AC|
| EndCapWind| Total wind capacity of each resource type in each zone |MW AC|
| StartCapDC |Initial inverter capacity of each resource type in each zone; this is an input |MW AC|
| RetCapDC |Retired inverter capacity of each resource type in each zone |MW AC|
| NewCapDC |Installed inverter capacity of each resource type in each zone |MW AC|
| EndCapDC| Total inverter capacity of each resource type in each zone |MW AC|
| StartCapGrid |Initial grid connection capacity of each resource type in each zone; this is an input |MW AC|
| RetCapGrid |Retired grid connection capacity of each resource type in each zone |MW AC|
| NewCapGrid |Installed grid connection capacity of each resource type in each zone |MW AC|
| EndCapGrid| Total gri connection capacity of each resource type in each zone |MW AC|
| StartEnergyCap |Initial energy capacity of each resource type in each zone; this is an input and applies only to storage tech.| MWh |
| RetEnergyCap |Retired energy capacity of each resource type in each zone; applies only to storage tech. |MWh |
| NewEnergyCap| Installed energy capacity of each resource type in each zone; applies only to storage tech. |MWh |
| EndEnergyCap |Total installed energy capacity of each resource type in each zone; applies only to storage tech. |MWh |
| StartChargeACCap| Initial charging AC power capacity of `STOR_AC_CHARGE = 2` resource type in each zone; this is an input |MW AC|
| RetChargeACCap |Retired charging AC power capacity of `STOR_AC_CHARGE = 2` resource type in each zone |MW AC|
| NewChargeACCap |Installed charging AC capacity of each resource type in each zone |MW AC|
| EndChargeAC Cap |Total charging power AC capacity of each resource type in each zone |MW AC|
| StartChargeDCCap| Initial charging DC power capacity of `STOR_DC_CHARGE = 2` resource type in each zone; this is an input |MW DC|
| RetChargeDCCap |Retired charging DC power capacity of `STOR_DC_CHARGE = 2` resource type in each zone |MW DC|
| NewChargeDCCap |Installed charging DC capacity of each resource type in each zone |MW DC|
| EndChargeDC Cap |Total charging power DC capacity of each resource type in each zone |MW DC|
| StartDischargeACCap| Initial discharging AC power capacity of `STOR_AC_DISCHARGE = 2` resource type in each zone; this is an input |MW AC|
| RetDischargeACCap |Retired discharging AC power capacity of `STOR_AC_DISCHARGE = 2` resource type in each zone |MW AC|
| NewDischargeACCap |Installed discharging AC capacity of each resource type in each zone |MW AC|
| EndDischargeAC Cap |Total discharging power AC capacity of each resource type in each zone |MW AC|
| StartDischargeDCCap| Initial discharging DC power capacity of `STOR_DC_DISCHARGE = 2` resource type in each zone; this is an input |MW DC|
| RetDischargeDCCap |Retired discharging DC power capacity of `STOR_DC_DISCHARGE = 2` resource type in each zone |MW DC|
| NewDischargeDCCap |Installed discharging DC capacity of each resource type in each zone |MW DC|
| EndDischargeDC Cap |Total discharging power DC capacity of each resource type in each zone |MW DC|

#### 3.2.10 vre_stor_dc_charge.csv

Reports DC charging by each co-located VRE and storage resource (could include grid or BTM charging) in each model time step.

#### 3.2.11 vre_stor_ac_charge.csv

Reports AC charging by each co-located VRE and storage resource (could include grid or BTM charging) in each model time step.

#### 3.2.12 vre_stor_dc_discharge.csv

Reports storage DC discharging by each co-located VRE and storage resource in each model time step.

#### 3.2.13 vre_stor_ac_discharge.csv

Reports storage AC discharging charging by each co-located VRE and storage resource in each model time step.


#### 3.2.14 vre_stor_solar_power.csv

Reports solar PV generation in AC terms by each co-located VRE and storage resource in each model time step.

#### 3.2.15 vre_stor_wind_power.csv

Reports wind generation in AC terms by each co-located VRE and storage resource in each model time step.
