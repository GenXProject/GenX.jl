# GenX Outputs

The table below summarizes the units of each output variable reported as part of the various CSV files produced after each model run. The reported units are also provided. If a result file includes time-dependent values, the value will not include the hour weight in it. An annual sum ("AnnualSum") column/row will be provided whenever it is possible (e.g., `emissions.csv`).

## 1 Default output files

### 1.1 capacity.csv

Reports optimal values of investment variables (except StartCap, which is an input)

###### Table 15: Structure of the capacity.csv file
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

### 1.2 costs.csv

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

### 1.3 emissions.csv

Reports CO2 emissions by zone at each hour; an annual sum row will be provided. If any emission cap is present, emission prices each zone faced by each cap will be copied on top of this table with the following strucutre.

###### Table 17: Structure of emission prices in the emissions.csv file
---
|**Output** |**Description** |**Units** |
| :------------ | :-----------|:-----------|
|CO_2\_price |Marginal CO2 abatement cost associated with constraint on maximum annual CO2 emissions; will be same across zones if CO2 emissions constraint is applied for the entire region and not zone-wise |\$/ tonne CO2. |

### 1.4 nse.csv

Reports non-served energy for every model zone, time step and cost-segment.

### 1.5 power.csv

Reports power discharged by each resource (generation, storage, demand response) in each model time step.

### 1.6 reliability.csv

Reports dual variable of maximum non-served energy constraint (shadow price of reliability constraint) for each model zone and time step.

### 1.7 prices.csv

Reports marginal electricity price for each model zone and time step. Marginal electricity price is equal to the dual variable of the load balance constraint. If GenX is configured as a mixed integer linear program, then this output is only generated if `WriteShadowPrices` flag is activated. If configured as a linear program (i.e. linearized unit commitment or economic dispatch) then output automatically available.

### 1.8 status.csv

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

### 1.9 NetRevenue.csv

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

## 2 Settings-specific outputs

This section includes the output files that GenX will print if corresponding function is specified in the Settings.

### 2.1 CapacityValue.csv

This file includes the time-dependent capacity value calculated for each generator. GenX will print this file only if the capacity reserve margin constraints are modeled through the setting file. Each row of the file (excluding the header) corresponds to a generator specified in the inputs. Each column starting from the t1 to the second last one stores the result of capacity obligation provided in each hour divided by the total capacity. Thus the number is unitless. If the capacity margin reserve is not binding for one hour, GenX will return zero. The last column specified the name of the corresponding capacity reserve constraint. Note that, if the user calculates the hour-weight-averaged capacity value for each generator using data of the binding hours, the result is what RTO/ISO call capacity credit.

<!-- #### 2.2 ExportRevenue.csv

This file includes the export revenue in $ of each zone. GenX will print this file only when a network is present and Locational Marginal Price (LMP) data is available to the GenX. The Total row includes the time-step-weighted summation of the time-dependent values shown below. For each time-step, the export revenue is calculated as the net outbound powerflow multiplied by the LMP. It is noteworthy that this export revenue is already part of the generation revenue, and the user should not double count.


#### 2.3 Importcost.csv

This file includes the import cost in $ of each zone. GenX will print this file only when a network is present and Locational Marginal Price (LMP) data is available to the GenX. The Total row includes the time-step -weighted summation of the time-dependent values shown below. For each time step, the import cost is calculated as the net inbound powerflow multiplied by the LMP. It is noteworthy that this import cost is already part of the load payment, and the user should not double count. -->

### 2.2 EnergyRevenue.csv

This file includes the energy revenue in $ earned by each generator through injecting into the grid. Only annual sum values are available.

### 2.3 ChargingCost.csv

This file includes the charging cost  in $ of earned by each generator through withdrawing from the grid. Only annual sum values are available.

### 2.4 ReserveMargin.csv

This file includes the shadow prices of the capacity reserve margin constraints. GenX will print this file only when capacity reserve margin is modeled and the shadow price can be obtained form the solver, as described earlier. Each row (except the header) corresponds to a capacity reserve margin constraint, and each column corresponds to an time step. As a reminder, GenX models the capacity reserve margin (aka capacity market) at the time-dependent level, and each constraint either stands for an overall market or a locality constraint.

### 2.5 ReserveMarginRevenue.csv

This file includes the capacity revenue earned by each generator listed in the input file. GenX will print this file only when capacity reserve margin is modeled and the shadow price can be obtained form the solver. Each row corresponds to a generator, and each column starting from the 6th to the second last is the total revenue from each capacity reserve margin constraint. The revenue is calculated as the capacity contribution of each time steps multiplied by the shadow price, and then the sum is taken over all modeled time steps. The last column is the total revenue received from all capacity reserve margin constraints. As a reminder, GenX models the capacity reserve margin (aka capacity market) at the time-dependent level, and each constraint either stands for an overall market or a locality constraint.

### 2.6 ESR\_prices.csv

This file includes the renewable/clean energy credit price of each modeled RPS/CES constraint. GenX will print this file only when RPS/CES is modeled and the shadow price can be obtained form the solver. The unit is $/MWh.

### 2.7 ESR\_Revenue.csv

This file includes the renewable/clean credit revenue earned by each generator listed in the input file. GenX will print this file only when RPS/CES is modeled and the shadow price can be obtained form the solver. Each row corresponds to a generator, and each column starting from the 6th to the second last is the total revenue earned from each RPS constraint. The revenue is calculated as the total annual generation (if elgible for the corresponding constraint) multiplied by the RPS/CES price. The last column is the total revenue received from all constraint. The unit is $.

### 2.8 SubsidyRevenue.csv

This file includes subsidy revenue earned if a generator specified Min\_Cap is provided in the input file. GenX will print this file only the shadow price can be obtained form the solver. Do not confuse this with the Minimum Capacity Carveout constraint, which is for a subset of generators, and a separate revenue term will be calculated in other files. The unit is $.
