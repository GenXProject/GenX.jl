# GenX Inputs

All input files are in CSV format. Running the GenX model requires a minimum of four **mandatory input files** and one folder, which consists of CSV files for generating resources:

1. Fuels\_data.csv: specify fuel type, CO2 emissions intensity, and time-series of fuel prices.
2. Network.csv: specify network topology, transmission fixed costs, capacity and loss parameters.
3. Demand\_data.csv: specify time-series of demand profiles for each model zone, weights for each time step, demand shedding costs, and optional time domain reduction parameters.
4. Generators\_variability.csv: specify time-series of capacity factor/availability for each resource.
5. Resources folder: specify cost and performance data for generation, storage and demand flexibility resources.
 
Additionally, the user may need to specify eight more **settings-specific** input files based on model configuration and type of scenarios of interest:
1. Operational\_reserves.csv: specify operational reserve requirements as a function of demand and renewables generation and penalty for not meeting these requirements.
2. Energy\_share\_requirement.csv: specify regional renewable portfolio standard and clean energy standard style policies requiring minimum energy generation from qualifying resources.
3. CO2\_cap.csv: specify regional CO2 emission limits.
4. Capacity\_reserve\_margin.csv: specify regional capacity reserve margin requirements.
5. Minimum\_capacity\_requirement.csv: specify regional minimum technology capacity deployment requirements.
6. Vre\_and\_stor\_data.csv: specify cost and performance data for co-located VRE and storage resources.
7. Vre\_and\_stor\_solar\_variability.csv: specify time-series of capacity factor/availability for each solar PV resource that exists for every co-located VRE and storage resource (in DC terms).
8. Vre\_and\_stor\_wind\_variability.csv: specify time-series of capacity factor/availability for each wind resource that exists for every co-located VRE and storage resource (in AC terms).


!!! note "Note"
    Names of the input files are case sensitive.


## 1 Mandatory input data


### 1.1 Fuels\_data.csv

• **First row:** names of all fuels used in the model instance which should match the labels used in `Fuel` column in one of the resource `.csv` file in the `resources` folder. For renewable resources or other resources that do not consume a fuel, the name of the fuel is `None`.

• **Second row:** The second row specifies the CO2 emissions intensity of each fuel in tons/MMBtu (million British thermal units). Note that by convention, tons correspond to metric tonnes and not short tons (although as long as the user is internally consistent in their application of units, either can be used).

• **Remaining rows:** Rest of the rows in this input file specify the time-series for prices for each fuel in $/MMBtu. A constant price can be specified by entering the same value for all hours.

* ** First column:** The first column in this file denotes, Time\_index, represents the index of time steps in a model instance.


### 1.2 Network.csv

This input file contains input parameters related to: 1) definition of model zones (regions between which transmission flows are explicitly modeled) and 2) definition of transmission network topology, existing capacity, losses and reinforcement costs. The following table describe each of the mandatory parameter inputs need to be specified to run an instance of the model, along with comments for the model configurations when they are needed.

###### Table 3: Structure of the Network.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|**Settings-specific Columns**|
|**Multiple zone model**||
|Network\_Lines | Numerical index for each network line. The length of this column is counted but the actual values are not used.|
| z* (Network map) **OR** Start_Zone, End_Zone | See below |
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

The list interface consists of a column for the lines start zone and one for the line's end zone.
Here is a snippet of the Network.csv file for a map with three zones and two lines:
```
Network_Lines, Start_Zone, End_Zone,
            1,          1,        2,
            2,          1,        3,
```

The matrix interface requires N columns labeled `z1, z2, z3 ... zN`,
and L rows, one for each network line (or interregional path), with a `1` in the column corresponding to the 'start' zone 
and a `-1` in the column corresponding to the 'end' zone for each line.
Here is the same network map implemented as a matrix:
```
Network_Lines, z1, z2, z3,
            1,  1, -1,  0,
            2,  1,  0, -1,
```

Note that in either case, positive flows indicate flow from start to end zone;
negative flows indicate flow from end to start zone.


### 1.3 Demand\_data.csv (Load\_data.csv)

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

### 1.4 Resources input files

The `resources` folder contains the input files for each resource type. At the current version of GenX, the following resources are included in the model: 
1) thermal generators, specified in the `Thermal.csv` file,
2) variable renewable energy resources (VRE), specified in the `VRE.csv` file,
3) reservoir hydro resources, specified in the `Hydro.csv` file,
4) storage resources, specified in the `Storage.csv` file,
5) flexible demand resources, specified in the `Flex_demand.csv` file,
6) must-run resources, specified in the `Must_run.csv` file,
7) electrolyzers, specified in the `Electrolyzer.csv` file, and
8) co-located VRE and storage resources, specified in the `Vre_stor.csv` file.

Each file contains cost and performance parameters for various generators and other resources included in the model formulation. The following table describes the mandatory columns in each of these files. Note that the column names are case insensitive.

##### Table 5a: Mandatory columns in all resource .csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Resource | This column contains **unique** names of resources available to the model. Resources can include generators, storage, and flexible or time shiftable demand.|
|Zone | Integer representing zone number where the resource is located. |
|**Technology type flags**|
|New\_Build | {0, 1}, Flag for resource (storage, generation) eligibility for capacity expansion.|
||New\_Build = 1: eligible for capacity expansion. |
||New\_Build = 0: not eligible for capacity expansion.|
|Can\_Retire | {0, 1}, Flag for resource (storage, generation) eligibility for retirement.|
||Can\_Retire = 1: eligible for retirement. |
||Can\_Retire = 0: not eligible for retirement.|
|**Existing technology capacity**|
|Existing\_Cap\_MW |The existing capacity of a power plant in MW. Note that for co-located VRE-STOR resources, this capacity represents the existing AC grid connection capacity in MW. |
|**Capacity/Energy requirements**|
|Max\_Cap\_MW |-1 (default) – no limit on maximum discharge capacity of the resource. If non-negative, represents maximum allowed discharge capacity (in MW) of the resource. Note that for co-located VRE-STOR resources, this capacity represents the maximum AC grid connection capacity in MW. |
|Min\_Cap\_MW |-1 (default) – no limit on minimum discharge capacity of the resource. If non-negative, represents minimum allowed discharge capacity (in MW) of the resource. Note that for co-located VRE-STOR resources, this capacity represents the minimum AC grid connection capacity in MW. |
|**Cost parameters**|
|Inv\_Cost\_per\_MWyr | Annualized capacity investment cost of a technology ($/MW/year). Note that for co-located VRE-STOR resources, this annualized capacity investment cost pertains to the grid connection.|
|Fixed\_OM\_Cost\_per\_MWyr | Fixed operations and maintenance cost of a technology ($/MW/year). Note that for co-located VRE-STOR resources, this fixed operations and maintenance cost pertains to the grid connection.|
|Var\_OM\_Cost\_per\_MWh | Variable operations and maintenance cost of a technology ($/MWh). Note that for co-located VRE-STOR resources, these costs apply to the AC generation sent to the grid from the entire site. |
|**Technical performance parameters**|
|Heat\_Rate\_MMBTU\_per\_MWh  |Heat rate of a generator or MMBtu of fuel consumed per MWh of electricity generated for export (net of on-site consumption). The heat rate is the inverse of the efficiency: a lower heat rate is better. Should be consistent with fuel prices in terms of reporting on higher heating value (HHV) or lower heating value (LHV) basis. |
|Fuel  |Fuel needed for a generator. The names should match with the ones in the `Fuels_data.csv`. |
|**Required for writing outputs**|
|region | Name of the model region|
|cluster | Number of the cluster when representing multiple clusters of a given technology in a given region.  |
|**Required if electrolyzer is included in the model**|
|Qualified_Hydrogen_Supply| {0,1}, Indicates that generator or storage resources is eligible to supply electrolyzers in the same zone (used for hourly clean supply constraint)|
|**Required for retrofitting**|
|Can\_Retrofit | {0, 1}, Flag for resource (storage, generation) eligibility for retrofit.|
||Can\_Retrofit = 1: eligible for retrofit. |
||Can\_Retrofit = 0: not eligible for retrofit.|
|Retrofit | {0, 1}, Flag for resource retrofit technologies (i.e., retrofit options, e.g. CCS retrofit for coal plants).|
||Retrofit = 1: is a retrofit technology. |
||Retrofit = 0: is not a retrofit technology.|
|Retrofit\_Id | Unique identifier to group retrofittable source technologies with retrofit options inside the same zone.|
|Retrofit\_Efficiency | [0,1], Efficiency of the retrofit technology.|

##### Table 5b: Settings-specific columns in all resource .csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|**ModelingToGenerateAlternatives = 1**||
|MGA |Eligibility of the technology for Modeling To Generate Alternative (MGA) run. |
||1 = Technology is available for the MGA run.|
||0 = Technology is unavailable for the MGA run (e.g. storage technologies).|
|Resource\_Type |For the MGA run, we categorize all the resources in a few resource types. We then find maximally different generation portfolio based on these resource types. For example, existing solar and new solar resources could be represented by a resource type names `Solar`. Categorization of resources into resource types is user dependent. |
|**Maintenance data**|
|MAINT|[0,1], toggles scheduled maintenance formulation.|
|Maintenance\_Duration| (Positive integer, less than total length of simulation.) Duration of the maintenance period, in number of timesteps. Only used if `MAINT=1`.|
|Maintenance\_Cycle\_Length\_Years| Length of scheduled maintenance cycle, in years. `1` is maintenance every year, `3` is every three years, etc. (Positive integer. Only used if `MAINT=1`.)|
|Maintenance\_Begin\_Cadence| Cadence of timesteps in which scheduled maintenance can begin. `1` means that a maintenance period can start in any timestep, `24` means it can start only in timesteps 1, 25, 49, etc. A larger number can decrease the simulation computational cost as it limits the optimizer's choices. (Positive integer, less than total length of simulation. Only used if `MAINT=1`.)|
|**CO2-related parameters required if any resources have nonzero CO2_Capture_Fraction**|
|CO2\_Capture\_Fraction  |[0,1], The CO2 capture fraction of CCS-equipped power plants during steady state operation. This value should be 0 for generators without CCS. |
|CO2\_Capture\_Fraction\_Startup  |[0,1], The CO2 capture fraction of CCS-equipped power plants during the startup events. This value should be 0 for generators without CCS |
|Biomass | {0, 1}, Flag to indicate if generator uses biomass as feedstock (optional input column).|
||Biomass = 0: Not part of set (default). |
||Biomass = 1: Uses biomass as fuel.|
|CCS\_Disposal\_Cost\_per\_Metric_Ton | Cost associated with CCS disposal ($/tCO2), including pipeline, injection and storage costs of CCS-equipped generators.|

##### Table 6a: Additional columns in the Thermal.csv file
|**Column Name** | **Description**|
| :------------ | :-----------|
|Model | {1, 2}, Flag to indicate membership in set of thermal resources (e.g. nuclear, combined heat and power, natural gas combined cycle, coal power plant)|
||Model = 1: If the power plant relies on thermal energy input and subject unit commitment constraints/decisions if `UCommit >= 1` (e.g. cycling decisions/costs/constraints). |
||Model = 2: If the power plant relies on thermal energy input and is subject to simplified economic dispatch constraints (ramping limits and minimum output level but no cycling decisions/costs/constraints). |
|Min\_Power |[0,1], The minimum generation level for a unit as a fraction of total capacity. This value cannot be higher than the smallest time-dependent CF value for a resource in `Generators_variability.csv`.|
|Ramp\_Up\_Percentage |[0,1], Maximum increase in power output from between two periods (typically hours), reported as a fraction of nameplate capacity.|
|Ramp\_Dn\_Percentage |[0,1], Maximum decrease in power output from between two periods (typically hours), reported as a fraction of nameplate capacity.|
|**PiecewiseFuelUsage-related parameters**|
|PWFU\_Fuel\_Usage\_Zero\_Load\_MMBTU\_per\_h|The fuel usage (MMBTU/h) for the first PWFU segemnt (y-intercept) at zero load.|
|PWFU\_Heat\_Rate\_MMBTU\_per\_MWh\_*i| The slope of fuel usage function of the segment i.|
|PWFU\_Load\_Point\_MW\_*i| The end of segment i (MW).|
|**Multi-fuel parameters**|
|MULTI_FUELS | {0, 1}, Flag to indicate membership in set of thermal resources that can burn multiple fuels at the same time (e.g., natural gas combined cycle cofiring with hydrogen, coal power plant cofiring with natural gas.|
||MULTI_FUELS = 0: Not part of set (default) |
||MULTI_FUELS = 1: Resources that can use fuel blending. |
|Num\_Fuels  |Number of fuels that a multi-fuel generator (MULTI_FUELS = 1) can use at the same time. The length of ['Fuel1', 'Fuel2', ...] should be equal to 'Num\_Fuels'. Each fuel will requires its corresponding heat rate, min cofire level, and max cofire level. |
|Fuel1  |Frist fuel needed for a mulit-fuel generator (MULTI_FUELS = 1). The names should match with the ones in the `Fuels_data.csv`. |
|Fuel2  |Second fuel needed for a mulit-fuel generator (MULTI_FUELS = 1). The names should match with the ones in the `Fuels_data.csv`. |
|Heat1\_Rate\_MMBTU\_per\_MWh  |Heat rate of a multi-fuel generator (MULTI_FUELS = 1) for Fuel1. |
|Heat2\_Rate\_MMBTU\_per\_MWh  |Heat rate of a multi-fuel generator (MULTI_FUELS = 1) for Fuel2. |
|Fuel1\_Min\_Cofire\_Level  |The minimum blendng level of 'Fuel1' in total heat inputs of a mulit-fuel generator (MULTI_FUELS = 1) during the normal generation process. |
|Fuel1\_Min\_Cofire_Level\_Start  |The minimum blendng level of 'Fuel1' in total heat inputs of a mulit-fuel generator (MULTI_FUELS = 1) during the start-up process. |
|Fuel1\_Max\_Cofire\_Level  |The maximum blendng level of 'Fuel1' in total heat inputs of a mulit-fuel generator (MULTI_FUELS = 1) during the normal generation process. |
|Fuel1\_Max\_Cofire_Level\_Start  |The maximum blendng level of 'Fuel1' in total heat inputs of a mulit-fuel generator (MULTI_FUELS = 1) during the start-up process. |
|Fuel2\_Min\_Cofire\_Level  |The minimum blendng level of 'Fuel2' in total heat inputs of a mulit-fuel generator (MULTI_FUELS = 1) during the normal generation process. |
|Fuel2\_Min\_Cofire_Level\_Start  |The minimum blendng level of 'Fuel2' in total heat inputs of a mulit-fuel generator (MULTI_FUELS = 1) during the start-up process. |
|Fuel2\_Max\_Cofire\_Level  |The maximum blendng level of 'Fuel2' in total heat inputs of a mulit-fuel generator (MULTI_FUELS = 1) during the normal generation process. |
|Fuel2\_Max\_Cofire_Level\_Start  |The maximum blendng level of 'Fuel2' in total heat inputs of a mulit-fuel generator (MULTI_FUELS = 1) during the start-up process. |

##### Table 6b: Settings-specific columns in the Thermal.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|**UCommit >= 1** | The following settings apply only to thermal plants with unit commitment constraints|
|Up\_Time| Minimum amount of time a resource has to stay in the committed state.|
|Down\_Time |Minimum amount of time a resource has to remain in the shutdown state.|
|Start\_Cost\_per\_MW |Cost per MW of nameplate capacity to start a generator ($/MW per start). Multiplied by the number of generation units (each with a pre-specified nameplate capacity) that is turned on.|
|Start\_Fuel\_MMBTU\_per\_MW |Startup fuel use per MW of nameplate capacity of each generator (MMBtu/MW per start).|
|**OperationalReserves = 1** | |
|Reg\_Cost |Cost of providing regulation reserves ($/MW per time step/hour).|
|Rsv\_Cost |Cost of providing upwards spinning or contingency reserves ($/MW per time step/hour).|
|Reg\_Max |[0,1], Fraction of nameplate capacity that can committed to provided regulation reserves. .|
|Rsv\_Max |[0,1], Fraction of nameplate capacity that can committed to provided upwards spinning or contingency reserves.|

##### Table 7a: Additional columns in the Vre.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Num\_VRE\_bins | Number of resource availability profiles considered for each VRE resource per zone. This parameter is used to decide the number of capacity investment decision variables related to a single variable renewable energy technology in each zone.|
||Num\_VRE\_bins = 1: using a single resource availability profile per technology per zone. 1 capacity investment decision variable and 1 generator RID tracking technology power output (and in each zone).|
||Num\_VRE\_bins > 1: using multiple resource availability profiles per technology per zone. Num\_VRE\_bins capacity investment decision variables and 1 generator RID used to define technology power output at each time step (and in each zone). Example: Suppose we are modeling 3 bins of wind profiles for each zone. Then include 3 rows with wind resource names as Wind\_1, Wind\_2, and Wind\_3 and a corresponding increasing sequence of RIDs. Set Num\_VRE\_bins for the generator with smallest RID, Wind\_1, to be 3 and set Num\_VRE\_bins for the other rows corresponding to Wind\_2 and Wind\_3, to be zero. By setting Num\_VRE\_bins for Wind\_2 and Wind\_3, the model eliminates the power outputs variables for these generators. The power output from the technology across all bins is reported in the power output variable for the first generator. This allows for multiple bins without significantly increasing number of model variables (adding each bin only adds one new capacity variable and no operational variables). See documentation for `curtailable_variable_renewable()` for more. |

##### Table 6b: Settings-specific columns in the Vre.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|**OperationalReserves = 1** | |
|Reg\_Cost |Cost of providing regulation reserves ($/MW per time step/hour).|
|Rsv\_Cost |Cost of providing upwards spinning or contingency reserves ($/MW per time step/hour).|
|Reg\_Max |[0,1], Fraction of nameplate capacity that can committed to provided regulation reserves. .|
|Rsv\_Max |[0,1], Fraction of nameplate capacity that can committed to provided upwards spinning or contingency reserves.|

##### Table 7a: Additional columns in the Hydro.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Min\_Power |[0,1], The minimum generation level for a unit as a fraction of total capacity. This value cannot be higher than the smallest time-dependent CF value for a resource in `Generators_variability.csv`.|
|Ramp\_Up\_Percentage |[0,1], Maximum increase in power output from between two periods (typically hours), reported as a fraction of nameplate capacity.|
|Ramp\_Dn\_Percentage |[0,1], Maximum decrease in power output from between two periods (typically hours), reported as a fraction of nameplate capacity.|
|Hydro\_Energy\_to\_Power\_Ratio  |The rated number of hours of reservoir hydro storage at peak discharge power output. (hours). |
|LDS | {0, 1}, Flag to indicate the resources eligible for long duration storage constraints with inter period linkage.|
||LDS = 0: Not part of set (default) |
||LDS = 1: Long duration storage resources|

##### Table 7b: Settings-specific columns in the Hydro.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|**OperationalReserves = 1** | |
|Reg\_Cost |Cost of providing regulation reserves ($/MW per time step/hour).|
|Rsv\_Cost |Cost of providing upwards spinning or contingency reserves ($/MW per time step/hour).|
|Reg\_Max |[0,1], Fraction of nameplate capacity that can committed to provided regulation reserves. .|
|Rsv\_Max |[0,1], Fraction of nameplate capacity that can committed to provided upwards spinning or contingency reserves.|

##### Table 8a: Additional columns in the Storage.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Model | {0, 1, 2}, Flag to indicate membership in set of storage resources and designate which type of storage resource formulation to employ.|
||Model = 0: Not part of set (default) |
||Model = 1: Discharging power capacity and energy capacity are the investment decision variables; symmetric charge/discharge power capacity with charging capacity equal to discharging capacity (e.g. lithium-ion battery storage).|
||Model = 2: Discharging, charging power capacity and energy capacity are investment variables; asymmetric charge and discharge capacities using distinct processes (e.g. hydrogen electrolysis, storage, and conversion to power using fuel cell or combustion turbine).|
|LDS | {0, 1}, Flag to indicate the resources eligible for long duration storage constraints with inter period linkage.|
||LDS = 0: Not part of set (default) |
||LDS = 1: Long duration storage resources|
|Self\_Disch  |[0,1], The power loss of storage technologies per hour (fraction loss per hour)- only applies to storage techs.|
|Eff\_Up  |[0,1], Efficiency of charging storage.|
|Eff\_Down  |[0,1], Efficiency of discharging storage. |
|Min\_Duration  |Specifies the minimum ratio of installed energy to discharged power capacity that can be installed (hours). |
|Max\_Duration  |Specifies the maximum ratio of installed energy to discharged power capacity that can be installed (hours). |
|**Existing technology capacity**|
|Existing\_Cap\_MWh |The existing capacity of storage in MWh where `Model = 1` or `Model = 2`.|
|Existing\_Charge\_Cap\_MW |The existing charging capacity for resources where `Model = 2`.|
|**Capacity/Energy requirements**|
|Max\_Cap\_MWh |-1 (default) – no limit on maximum energy capacity of the resource. If non-negative, represents maximum allowed energy capacity (in MWh) of the resource with `Model = 1` or `Model = 2`.|
|Max\_Charge\_Cap\_MW |-1 (default) – no limit on maximum charge capacity of the resource. If non-negative, represents maximum allowed charge capacity (in MW) of the resource with `Model = 2`.|
|Min\_Cap\_MWh| -1 (default) – no limit on minimum energy capacity of the resource. If non-negative, represents minimum allowed energy capacity (in MWh) of the resource with `Model = 1` or `Model = 2`.|
|Min\_Charge\_Cap\_MW |-1 (default) – no limit on minimum charge capacity of the resource. If non-negative, represents minimum allowed charge capacity (in MW) of the resource with `Model = 2`.|
|**Cost parameters**|
|Inv\_Cost\_per\_MWhyr | Annualized investment cost of the energy capacity for a storage technology ($/MW/year), applicable to either `Model = 1` or `Model = 2`. |
|Inv\_Cost\_Charge\_per\_MWyr | Annualized capacity investment cost for the charging portion of a storage technology with `Model = 2` ($/MW/year). |
|Fixed\_OM\_Cost\_per\_MWhyr | Fixed operations and maintenance cost of the energy component of a storage technology ($/MWh/year).|
|Fixed\_OM\_Cost\_Charge\_per\_MWyr | Fixed operations and maintenance cost of the charging component of a storage technology of type `Model = 2`. |
|Var\_OM\_Cost\_per\_MWhIn | Variable operations and maintenance cost of the charging aspect of a storage technology with `Model = 2`. Otherwise 0 ($/MWh).|

##### Table 8b: Settings-specific columns in the Storage.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|**OperationalReserves = 1** | |
|Reg\_Cost |Cost of providing regulation reserves ($/MW per time step/hour).|
|Rsv\_Cost |Cost of providing upwards spinning or contingency reserves ($/MW per time step/hour).|
|Reg\_Max |[0,1], Fraction of nameplate capacity that can committed to provided regulation reserves. .|
|Rsv\_Max |[0,1], Fraction of nameplate capacity that can committed to provided upwards spinning or contingency reserves.|

##### Table 9: Additional columns in the Flex_demand.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Max\_Flexible\_Demand\_Delay  |Maximum number of hours that demand can be deferred or delayed (hours). |
|Max\_Flexible\_Demand\_Advance  |Maximum number of hours that demand can be scheduled in advance of the original schedule (hours). |
|Flexible\_Demand\_Energy\_Eff  |[0,1], Energy efficiency associated with time shifting demand. Represents energy losses due to time shifting (or 'snap back' effect of higher consumption due to delay in use) that may apply to some forms of flexible demand (hours). For example, one may need to pre-cool a building more than normal to advance demand. |
|**Cost parameters**|
|Var\_OM\_Cost\_per\_MWhIn | Variable operations and maintenance costs associated with flexible demand deferral. Otherwise 0 ($/MWh). |

##### Table 10: Additional columns in the Electrolyzer.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Hydrogen_MWh_Per_Tonne| Electrolyzer efficiency in megawatt-hours (MWh) of electricity per metric tonne of hydrogen produced (MWh/t)|
|Electrolyzer_Min_kt| Minimum annual quantity of hydrogen that must be produced by electrolyzer in kilotonnes (kt)|
|Hydrogen_Price_Per_Tonne| Price (or value) of hydrogen per metric tonne ($/t)|
|Min\_Power |[0,1], The minimum generation level for a unit as a fraction of total capacity. This value cannot be higher than the smallest time-dependent CF value for a resource in `Generators_variability.csv`.|
|Ramp\_Up\_Percentage |[0,1], Maximum increase in power output from between two periods (typically hours), reported as a fraction of nameplate capacity.|
|Ramp\_Dn\_Percentage |[0,1], Maximum decrease in power output from between two periods (typically hours), reported as a fraction of nameplate capacity.|
!!! note
    Check `Qualified_Hydrogen_Supply` column in table 5a if electrolyzers are included in the model. This column is used to indicate which resources are eligible to supply electrolyzers in the same zone (used for hourly clean supply constraint).

Each co-located VRE and storage resource can be easily configured to contain either a co-located VRE-storage resource, standalone VRE resource (either wind, solar PV, or both), or standalone storage resource.
##### Table 11a: Additional columns in the Vre_stor.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
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
|Existing\_Cap\_MW |The existing AC grid connection capacity in MW. |
|Existing\_Cap\_MWh |The existing capacity of storage in MWh. |
|Existing\_Cap\_Inverter\_MW |The existing capacity of co-located VRE-STOR resource's inverter in MW (AC). |
|Existing\_Cap\_Solar\_MW |The existing capacity of co-located VRE-STOR resource's solar PV in MW (DC). |
|Existing\_Cap\_Wind\_MW |The existing capacity of co-located VRE-STOR resource's wind in MW (AC). |
|Existing\_Cap\_Discharge\_DC\_MW |The existing discharge capacity of co-located VRE-STOR resource's storage component in MW (DC). Note that this only applies to resources where `STOR_DC_DISCHARGE = 2`. |
|Existing\_Cap\_Charge\_DC\_MW |The existing charge capacity of co-located VRE-STOR resource's storage component in MW (DC). Note that this only applies to resources where `STOR_DC_CHARGE = 2`. |
|Existing\_Cap\_Discharge\_AC\_MW |The existing discharge capacity of co-located VRE-STOR resource's storage component in MW (AC). Note that this only applies to resources where `STOR_AC_DISCHARGE = 2`. |
|Existing\_Cap\_Charge\_AC\_MW |The existing charge capacity of co-located VRE-STOR resource's storage component in MW (AC). Note that this only applies to resources where `STOR_DC_CHARGE = 2`. |
|**Capacity/Energy requirements**|
|Max\_Cap\_MW |-1 (default) – no limit on maximum discharge capacity of the resource. If non-negative, represents maximum allowed AC grid connection capacity in MW of the resource. |
|Max\_Cap\_MWh |-1 (default) – no limit on maximum energy capacity of the resource. If non-negative, represents maximum allowed energy capacity of storage in MWh. |
|Min\_Cap\_MW |-1 (default) – no limit on minimum discharge capacity of the resource. If non-negative, represents minimum allowed AC grid connection capacity in MW. |
|Min\_Cap\_MWh| -1 (default) – no limit on minimum energy capacity of the resource. If non-negative, represents minimum allowed energy capacity of storage in MWh. |
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
|Inv\_Cost\_per\_MWyr | Annualized capacity investment cost of the grid connection ($/MW/year).|
|Inv\_Cost\_per\_MWhyr | Annualized investment cost of the energy capacity for the co-located storage resource ($/MW/year)|
|Fixed\_OM\_Cost\_per\_MWyr | Fixed operations and maintenance cost of the grid connection ($/MW/year).|
|Fixed\_OM\_Cost\_per\_MWhyr | Fixed operations and maintenance cost of the energy component of the co-located storage resource. ($/MWh/year). |
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
|Self\_Disch  |[0,1], The power loss of storage component of each resource per hour (fraction loss per hour). |
|EtaInverter |[0,1], Inverter efficiency representing losses from converting DC to AC power and vice versa for each technology |
|Inverter_Ratio_Solar  |-1 (default) - no required ratio between solar PV capacity built to inverter capacity built. If non-negative, represents the ratio of solar PV capacity built to inverter capacity built.|
|Inverter_Ratio_Wind  |-1 (default) - no required ratio between wind capacity built to grid connection capacity built. If non-negative, represents the ratio of wind capacity built to grid connection capacity built.|
|Power\_to\_Energy\_AC  |The power to energy conversion for the storage component for AC discharging/charging of symmetric storage resources.|
|Power\_to\_Energy\_DC  |The power to energy conversion for the storage component for DC discharging/charging of symmetric storage resources.|
|Eff\_Up\_DC  |[0,1], Efficiency of DC charging storage – applies to storage technologies (all STOR types). |
|Eff\_Down\_DC  |[0,1], Efficiency of DC discharging storage – applies to storage technologies (all STOR types). |
|Eff\_Up\_AC  |[0,1], Efficiency of AC charging storage – applies to storage technologies (all STOR types). |
|Eff\_Down\_AC  |[0,1], Efficiency of AC discharging storage – applies to storage technologies (all STOR types). |

##### Table 11b: Settings-specific columns in the Vre_stor.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|**OperationalReserves = 1** | |
|Reg\_Cost |Cost of providing regulation reserves ($/MW per time step/hour).|
|Rsv\_Cost |Cost of providing upwards spinning or contingency reserves ($/MW per time step/hour).|
|Reg\_Max |[0,1], Fraction of nameplate capacity that can committed to provided regulation reserves. .|
|Rsv\_Max |[0,1], Fraction of nameplate capacity that can committed to provided upwards spinning or contingency reserves.|

##### Policy-related columns for all resources
In addition to the files described above, the `resources` folder contains the following files that are used to specify policy-related parameters for specific resources: 

1) `Resource_energy_share_requirement.csv`
2) `Resource_minimum_capacity_requirement.csv`
3) `Resource_maximum_capacity_requirement.csv`
4) `Resource_capacity_reserve_margin.csv`

!!! note
    These files are optional and can be omitted if no policy-related parameters are specified in the settings file. Also, not all the resources need to be included in these files, only those for which the policy applies.

The following table describes the columns in each of these four files.

!!! warning
    The first column of each file must contain the resource name corresponding to a resource in one of the resource data files described above. Note that the order of resources in the policy files is not important.

This policy is applied when if `EnergyShareRequirement > 0` in the settings file. \* corresponds to the ith row of the file `Energy_share_requirement.csv`. 

##### Table 12: Energy share requirement policy parameters
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Resource| Resource name corresponding to a resource in one of the resource data files described above.|
|ESR\_*| Flag to indicate which resources are considered for the Energy Share Requirement constraint.|
||1- included|
||0- excluded|
|**co-located VRE-STOR resources only**|
|ESRVreStor\_*| Flag to indicate which resources are considered for the Energy Share Requirement constraint.|
||1- included|
||0- excluded|

This policy is applied when if `MinCapReq = 1` in the settings file. \* corresponds to the ith row of the file `Minimum_capacity_requirement.csv`. 

##### Table 13: Minimum capacity requirement policy parameters
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Resource| Resource name corresponding to a resource in one of the resource data files described above.|
|Min_Cap\_*| Flag to indicate which resources are considered for the Minimum Capacity Requirement constraint.|
|**co-located VRE-STOR resources only**|
|Min_Cap_Solar\_*| Eligibility of resources with a solar PV component (multiplied by the inverter efficiency for AC terms) to participate in Minimum Technology Carveout constraint.|
|Min_Cap_Wind\_*| Eligibility of resources with a wind component to participate in Minimum Technology Carveout constraint (AC terms).|
|Min_Cap_Stor\_*| Eligibility of resources with a storage component to participate in Minimum Technology Carveout constraint (discharge capacity in AC terms).|

This policy is applied when if `MaxCapReq = 1` in the settings file. \* corresponds to the ith row of the file `Maximum_capacity_requirement.csv`.

##### Table 14: Maximum capacity requirement policy parameters
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Resource| Resource name corresponding to a resource in one of the resource data files described above.|
|Max_Cap\_*| Flag to indicate which resources are considered for the Maximum Capacity Requirement constraint.|
|**co-located VRE-STOR resources only**|
|Max_Cap_Solar\_*| Eligibility of resources with a solar PV component (multiplied by the inverter efficiency for AC terms) to participate in Maximum Technology Carveout constraint.
|Max_Cap_Wind\_*| Eligibility of resources with a wind component to participate in Maximum Technology Carveout constraint (AC terms).
|Max_Cap_Stor\_*| Eligibility of resources with a storage component to participate in Maximum Technology Carveout constraint (discharge capacity in AC terms).|

This policy is applied when if `CapacityReserveMargin > 0` in the settings file. \* corresponds to the ith row of the file `Capacity_reserve_margin.csv`.

##### Table 15: Capacity reserve margin policy parameters
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Resource| Resource name corresponding to a resource in one of the resource data files described above.|
|Eligible_Cap_Res\_*| Fraction of the resource capacity eligible for contributing to the capacity reserve margin constraint (e.g. derate factor).|

##### Additional module-related columns for all resources
In addition to the files described above, the `resources` folder can contain additional files that are used to specify attributes for specific resources and modules. Currently, the following files are supported:

1) `Resource_multistage_data.csv`: mandatory if `MultiStage = 1` in the settings file
<!-- 2) `Resource_piecewisefuel_usage.csv` -->

!!! warning
    The first column of each additional module file must contain the resource name corresponding to a resource in one of the resource data files described above. Note that the order of resources in these files is not important.

##### Table 16: Multistage parameters
!!! warning
    This file is mandatory if `MultiStage = 1` in the settings file.
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Resource| Resource name corresponding to a resource in one of the resource data files described above.|
|Capital\_Recovery\_Period  |Capital recovery period (in years) used for determining overnight capital costs from annualized investment costs. Note that for co-located VRE-STOR resources, this value pertains to the grid connection. |
|Lifetime  |Lifetime (in years) used for determining endogenous retirements of newly built capacity.  Note that the same lifetime is used for each component of a co-located VRE-STOR resource. |
|Min\_Retired\_Cap\_MW  |Minimum required discharge capacity retirements in the current model period. This field can be used to enforce lifetime retirements of existing capacity. Note that for co-located VRE-STOR resources, this value pertains to the grid connection. |
|Min\_Retired\_Energy\_Cap\_MW  |Minimum required energy capacity retirements in the current model period. This field can be used to enforce lifetime retirements of existing energy capacity. Note that for co-located VRE-STOR resources, this value pertains to the storage component.|
|Min\_Retired\_Charge\_Cap\_MW  |Minimum required energy capacity retirements in the current model period. This field can be used to enforce lifetime retirements of existing charge capacity. |
|Contribute\_Min\_Retirement | {0, 1}, Flag to indicate whether the (retrofitting) resource can contribute to the minimum retirement requirement.|
|**co-located VRE-STOR resources only**|
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

#### 1.5 Generator\_variability.csv

This file contains the time-series of capacity factors / availability of each resource included in the resource `.csv` file in the `resources` folder for each time step (e.g. hour) modeled.

• First column: The first column contains the time index of each row (starting in the second row) from 1 to N.

• Second column onwards: Resources are listed from the second column onward with headers matching each resource name in the resource `.csv` file in the `resources` folder in any order. The availability for each resource at each time step is defined as a fraction of installed capacity and should be between 0 and 1. Note that for this reason, resource names specified in the resource `.csv` file must be unique. Note that for Hydro reservoir resources (i.e. `Hydro.csv`), values in this file correspond to inflows (in MWhs) to the hydro reservoir as a fraction of installed power capacity, rather than hourly capacity factor. Note that for co-located VRE and storage resources, solar PV and wind resource profiles should not be located in this file but rather in separate variability files (these variabilities can be in the `Generators_variability.csv` if time domain reduction functionalities will be utilized because the time domain reduction functionalities will separate the files after the clustering is completed).

|Self\_Disch  |[0,1], The power loss of storage technologies per hour (fraction loss per hour)- only applies to storage techs. Note that for co-located VRE-STOR resources, this value applies to the storage component of each resource.|
|Min\_Power |[0,1], The minimum generation level for a unit as a fraction of total capacity. This value cannot be higher than the smallest time-dependent CF value for a resource in `Generators_variability.csv`. Applies to thermal plants, and reservoir hydro resource (`HYDRO = 1`).|
|Ramp\_Up\_Percentage |[0,1], Maximum increase in power output from between two periods (typically hours), reported as a fraction of nameplate capacity. Applies to thermal plants, and reservoir hydro resource (`HYDRO = 1`).|
|Ramp\_Dn\_Percentage |[0,1], Maximum decrease in power output from between two periods (typically hours), reported as a fraction of nameplate capacity. Applies to thermal plants, and reservoir hydro resource (`HYDRO = 1`).|
|Eff\_Up  |[0,1], Efficiency of charging storage – applies to storage technologies (all STOR types except co-located storage resources).|
|Eff\_Down  |[0,1], Efficiency of discharging storage – applies to storage technologies (all STOR types except co-located storage resources). |

|Min\_Duration  |Specifies the minimum ratio of installed energy to discharged power capacity that can be installed. Applies to STOR types 1 and 2 (hours). Note that for co-located VRE-STOR resources, this value does not apply. |
|Max\_Duration  |Specifies the maximum ratio of installed energy to discharged power capacity that can be installed. Applies to STOR types 1 and 2 (hours). Note that for co-located VRE-STOR resources, this value does not apply. |
|Max\_Flexible\_Demand\_Delay  |Maximum number of hours that demand can be deferred or delayed. Applies to resources with FLEX type 1 (hours). |
|Max\_Flexible\_Demand\_Advance  |Maximum number of hours that demand can be scheduled in advance of the original schedule. Applies to resources with FLEX type 1 (hours). |
|Flexible\_Demand\_Energy\_Eff  |[0,1], Energy efficiency associated with time shifting demand. Represents energy losses due to time shifting (or 'snap back' effect of higher consumption due to delay in use) that may apply to some forms of flexible demand. Applies to resources with FLEX type 1 (hours). For example, one may need to pre-cool a building more than normal to advance demand. |

#### 1.6 Vre\_and\_stor\_solar\_variability.csv

This file contains the time-series of capacity factors / availability of the solar PV component (DC capacity factors) of each co-located resource included in the `Vre_and_stor_data.csv` file for each time step (e.g. hour) modeled.

• first column: The first column contains the time index of each row (starting in the second row) from 1 to N.

• Second column onwards: Resources are listed from the second column onward with headers matching each resource name in the `Vre_stor.csv` files in any order. The availability for each resource at each time step is defined as a fraction of installed capacity and should be between 0 and 1. Note that for this reason, resource names specified in all the resource `.csv` files must be unique. 

#### 1.7 Vre\_and\_stor\_wind\_variability.csv

This file contains the time-series of capacity factors / availability of the wind component (AC capacity factors) of each co-located resource included in the `Vre_and_stor_data.csv` file for each time step (e.g. hour) modeled.

• First column: The first column contains the time index of each row (starting in the second row) from 1 to N.

• Second column onwards: Resources are listed from the second column onward with headers matching each resource name in the `Vre_stor.csv` files in any order. The availability for each resource at each time step is defined as a fraction of installed capacity and should be between 0 and 1. Note that for this reason, resource names specified in all the resource `.csv` files must be unique. 

## 2. Optional inputs files

### 2.1 Operational_reserves.csv

This file includes parameter inputs needed to model time-dependent procurement of regulation and spinning reserves. This file is needed if `OperationalReserves` flag is activated in the YAML file `genx_settings.yml`.

###### Table 7: Structure of the Operational_reserves.csv file
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



### 2.2 Energy\_share\_requirement.csv

This file contains inputs specifying minimum energy share requirement policies, such as Renewable Portfolio Standard (RPS) or Clean Energy Standard (CES) policies. This file is needed if parameter EnergyShareRequirement has a non-zero value in the YAML file `genx_settings.yml`.

Note: this file should use the same region name as specified in the the resource `.csv` file (inside the `Resource`).

###### Table 8: Structure of the Energy\_share\_requirement.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Region\_description |Region name|
|Network\_zones |zone number represented as z*|
|ESR\_* |[0,1], Energy share requirements as a share of zonal demand (calculated on an annual basis). * represents the number of the ESR constraint, given by the number of ESR\_* columns in the `Energy_share_requirement.csv` file.|



### 2.3 CO2\_cap.csv

This file contains inputs specifying CO2 emission limits policies (e.g. emissions cap and permit trading programs). This file is needed if `CO2Cap` flag is activated in the YAML file `genx_settings.yml`. `CO2Cap` flag set to 1 represents mass-based (tCO2 ) emission target. `CO2Cap` flag set to 2 is specified when emission target is given in terms of rate (tCO2/MWh) and is based on total demand met. `CO2Cap` flag set to 3 is specified when emission target is given in terms of rate (tCO2 /MWh) and is based on total generation.

###### Table 9: Structure of the CO2\_cap.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Region\_description |Region name|
|Network\_zones| zone number represented as z*|
|CO\_2\_Cap\_Zone_* |If a zone is eligible for the emission limit constraint, then this column is set to 1, else 0.|
|CO\_2\_Max\_tons\_MWh_* |Emission limit in terms of rate|
|CO\_2\_Max\_Mtons_* |Emission limit in absolute values, in Million of tons |
| | where in the above inputs, * represents the number of the emission limit constraints. For example, if the model has 2 emission limit constraints applied separately for 2 zones, the above CSV file will have 2 columns for specifying emission limit in terms on rate: CO\_2\_Max\_tons\_MWh\_1 and CO\_2\_Max\_tons\_MWh\_2.|

### 2.4 Capacity\_reserve\_margin.csv

This file contains the regional capacity reserve margin requirements. This file is needed if parameter CapacityReserveMargin has a non-zero value in the YAML file `genx_settings.yml`.

Note: this file should use the same region name as specified in the resource `.csv` file (inside the `Resource`).

###### Table 10: Structure of the Capacity\_reserve\_margin.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Region\_description |Region name|
|Network\_zones |zone number represented as z*|
|CapRes\_* |[0,1], Capacity reserve margin requirements of a zone, reported as a fraction of demand|



### 2.5 Minimum\_capacity\_requirement.csv

This file contains the minimum capacity carve-out requirement to be imposed (e.g. a storage capacity mandate or offshore wind capacity mandate). This file is needed if the `MinCapReq` flag has a non-zero value in the YAML file `genx_settings.yml`.

###### Table 11: Structure of the Minimum\_capacity\_requirement.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|MinCapReqConstraint |Index of the minimum capacity carve-out requirement.|
|Constraint\_Description |Names of minimum capacity carve-out constraints; not to be read by model, but used as a helpful notation to the model user. |
|Min\_MW | minimum capacity requirement [MW]|


Some of the columns specified in the input files in Section 2.2 and 2.1 are not used in the GenX model formulation. These columns are necessary for interpreting the model outputs and used in the output module of the GenX.

### 2.6 Maximum\_capacity\_requirement.csv

This contains the maximum capacity limits to be imposed (e.g. limits on total deployment of solar, wind, or batteries in the system as a whole or in certain collections of zones).
It is required if the `MaxCapReq` flag has a non-zero value in `genx_settings.yml`.

###### Table 12: Structure of the Maximum\_capacity\_requirement.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|MaxCapReqConstraint |Index of the maximum capacity limit.|
|Constraint\_Description |Names of maximum capacity limit; not to be read by model, but used as a helpful notation to the model user. |
|Max\_MW | maximum capacity limit [MW]|


Some of the columns specified in the input files in Section 2.2 and 2.1 are not used in the GenX model formulation. These columns are necessary for interpreting the model outputs and used in the output module of the GenX.

### 2.7 Method\_of\_morris\_range.csv

This file contains the settings parameters required to run the Method of Morris algorithm in GenX. This file is needed if the `MethodofMorris` flag is ON in the YAML file `genx_settings.yml`.

###### Table 13: Structure of the Method\_of\_morris\_range.csv file
---
|**Column Name** | **Description**|
| :------------ | :-----------|
|Resource | This column contains **unique** names of resources available to the model. Resources can include generators, storage, and flexible or time shiftable demand/loads.|
|Zone | Integer representing zone number where the resource is located. |
|Lower\_bound | Percentage lower deviation from the nominal value|
|Upper\_bound| Percentage upper deviation from the nominal value|
|Parameter| Column from the resource `.csv` file (inside the `Resource`) containing uncertain parameters|
|Group| Group the uncertain parameters that will be changed all at once while performing the sensitivity analysis. For example, if the fuel price of natural gas is uncertain, all generators consuming natural gas should be in the same group. Group name is user defined|
|p_steps| Number of steps between upper and lower bound|
|total\_num\_trajectory| Total number of trakectories through the design matrix|
|num\_trajectory| Selected number of trajectories throigh the design matrix|
|len\_design\_mat| Length of the design matrix|
|policy| Name of the policy|

!!! note "Notes"
    1. Upper and lower bounds are specified in terms of percentage deviation from the nominal value.
    2. Percentage variation for uncertain parameters in a given group is identical. For example, if solar cluster 1 and solar cluster 2 both belong to the ‘solar’ group, their Lower_bound and Upper_bound must be identical
    3. P\_steps should at least be = 1\%, i.e., Upper\_bound – Lower\_bound $<$ p\_steps
    4. P\_steps for parameters in one group must be identical
    5. Total\_num\_trajectory should be around 3 to 4 times the total number of uncertain parameters
    6. num\_trajectory should be approximately equal to the total number of uncertain parameters
    7. len\_design_mat should be 1.5 to 2 times the total number of uncertain parameters
    8. Higher number of num\_trajectory and len_design_mat would lead to higher accuracy
    9. Upper and lower bounds should be specified for all the resources included in the resource `.csv` file (inside the `Resource`). If a parameter related to a particular resource is not uncertain, specify upper bound = lower bound = 0.

