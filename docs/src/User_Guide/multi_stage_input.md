# Multi-stage setup

This section describes the available features, inputs and model components related to formulating and solving multi-stage investment planning problems. Two different types of multi-stage problems can be setup:
* Perfect foresight: A single multi-stage investment planning problem that simultaneously optimizes capacity and operations across all specified investment stages
* Myopic: Sequential solution of single-stage investment planning for each investment stage, where capacity additions and retirements from the previous stages are used to determine initial (or existing) capacity at the beginning of the current stage. 

The table below summarizes the key differences in the two model setups.

|                                              | Perfect foresight | Myopic                               |
| :------------------------------------------ | :-----------------: | :------------------------------------: |
| No. of optimization problems solved        | 1                 | Equal to number of investment stages |
| Objective function cost basis              | Net present value | Annualized costs                     |
| Price/dual variable information available? | No                | Yes                                  |


### Additional inputs needed for multi-stage modeling

####  Input data files
Instead of one set of input files, there is one directory of input files that needs to be provided for each planning period or stage (e.g., “inputs/inputs\_p1/” for the first period “inputs/inputs\_p2/” for the second period, etc.). Below we list the additional parameters that must be provided in the corresponding stage-specific input files to instantiate a multi-stage planning problem.


|                              |                                                                   **Resource_multistage_data.csv files**                                                                  |
|:------------------------------|:----------------------------------------------------------------------------------------------------------------------------------------------------------|
| Min\_Retired\_Cap\_MW        | Minimum capacity in MW that must retire in this planning stage. Note that for the co-located VRE-STOR module, this value represents the grid connection component.                                                                                           |
| Min\_Retired\_Energy\_Cap\_MW | Minimum energy capacity in MW that must retire in this planning stage. Note that for the co-located VRE-STOR module, this value represents the storage component.                                                                                    |
| Min\_Retired\_Charge\_Cap\_MW | Minimum charge capacity in MW that must retire in this planning stage.                                                                                     |
| Lifetime                     | The operational lifespan in years of this technology after which it must be retired.                                                                       |
| Capital\_Recovery\_Period      | The technology-specific period in years over which initial capital costs must be recovered. Note that for the co-located VRE-STOR module, this value represents the grid connection component.                                                               |
| WACC                         | *Optional, not used in discounting.* Investment annuities are discounted at the general discount rate (the `WACC` field of `multi_stage_settings.yml`); a technology-specific cost of capital should already be reflected in the annualized investment cost. The column is accepted for backwards compatibility but does not affect results.                                                                                                 |
|Contribute\_Min\_Retirement | {0, 1}, Flag to indicate whether the (retrofitting) resource can contribute to the minimum retirement requirement.|

|                              |                                                                   **co-located VRE-STOR resources only**                                                                  |
|:------------------------------|:----------------------------------------------------------------------------------------------------------------------------------------------------------|
|Min\_Retired\_Cap\_Inverter\_MW  |Minimum inverter capacity in MW AC that must retire in this plannig stage. |
|Min\_Retired\_Cap\_Solar\_MW  |Minimum solar PV capacity in MW DC that must retire in this plannig stage. |
|Min\_Retired\_Cap\_Wind\_MW  |Minimum wind capacity in MW AC that must retire in this plannig stage. |
|Min\_Retired\_Cap\_Discharge_DC\_MW  |Minimum storage DC discharge capacity that must retire in this planning stage with `STOR_DC_DISCHARGE = 2`. |
|Min\_Retired\_Cap\_Charge_DC\_MW  |Minimum storage DC charge capacity that must retire in this planning stage with `STOR_DC_CHARGE = 2`. |
|Min\_Retired\_Cap\_Discharge_AC\_MW  |Minimum storage AC discharge capacity that must retire in this planning stage with `STOR_AC_DISCHARGE = 2`. |
|Min\_Retired\_Cap\_Charge_AC\_MW  |Minimum storage AC charge capacity that must retire in this planning stage with `STOR_AC_CHARGE = 2`. |
|Capital\_Recovery\_Period_DC  |The technology-specific period in years over which initial capital costs for the inverter component must be recovered.|
|Capital\_Recovery\_Period_Solar  |The technology-specific period in years over which initial capital costs for the solar PV component must be recovered.|
|Capital\_Recovery\_Period_Wind  |The technology-specific period in years over which initial capital costs for the wind component must be recovered.|
|Capital\_Recovery\_Period_Discharge_DC  |The technology-specific period in years over which initial capital costs for the storage DC discharge component must be recovered when `STOR_DC_DISCHARGE = 2  `. |
|Capital\_Recovery\_Period_Charge_DC  |The technology-specific period in years over which initial capital costs for the storage DC charge component must be recovered when `STOR_DC_CHARGE = 2  `.|
|Capital\_Recovery\_Period_Discharge_AC  |The technology-specific period in years over which initial capital costs for the storage AC discharge component must be recovered when `STOR_AC_DISCHARGE = 2  `.|
|Capital\_Recovery\_Period_Charge_AC  |The technology-specific period in years over which initial capital costs for the storage AC charge component must be recovered when `STOR_DC_CHARGE = 2  `.|
| WACC\_DC, WACC\_Solar, WACC\_Wind, WACC\_Discharge\_DC, WACC\_Charge\_DC, WACC\_Discharge\_AC, WACC\_Charge\_AC | *Optional, not used in discounting.* Component-specific costs of capital, accepted for backwards compatibility. All annuities are discounted at the general discount rate; see the WACC row above. |

|                           |                                                                       **Network.csv**                                                                      |
|:---------------------------|:----------------------------------------------------------------------------------------------------------------------------------------------------------|
| Line\_Max\_Flow\_Possible\_MW | The maximum transmission capacity of the line, as opposed to Line\_Max\_Reinforcement\_MW which now specifies the maximum expansion to the line in one stage. |
| Capital\_Recovery\_Period   | The line-specific period in years over which initial capital costs must be recovered.                                                                |
| WACC                      | *Optional, not used in discounting.* Line investment annuities are discounted at the general discount rate (the `WACC` field of `multi_stage_settings.yml`). The column is accepted for backwards compatibility but does not affect results. |


!!! note "Allowing retrofitted capacity to not contribute to minimum retirement requirements (`myopic=0` only)"
    Special considerations must be taken into account when utilizing the retrofit module alongside multi-stage planning, particularly when using a non zero value for the `Min_Retired_Cap_MW` column in the `Resource_multistage_data.csv` file.
    1. When assigning a non-zero value to the `Min_Retired_Cap_MW` column in the `Resource_multistage_data.csv` file, the user can specify whether the model should consider the retrofitted capacity to contribute to the minimum retirement requirement. This is done by setting the `Contribute_Min_Retirement` column to 1 for the retrofit options in the same retrofit cluster (i.e., same `Retrofit_Id`).
    2. By default, the model assumes that retrofitted capacity contributes to fulfilling minimum retirement requirements.
    3. Should users wish to exclude retrofitted capacity from contributing to minimum retirement requirements, they must set the `Contribute_Min_Retirement` column to 0 for **all** retrofit options within the same retrofit cluster (i.e., sharing the same `Retrofit_Id`).
    4. It's important to note that this additional functionality is not currently supported when `myopic=1`. In this case, the retrofit options are only allowed to contribute to the minimum retirement requirement.

    Example 1: Retrofitted capacity is allowed to contribute to the minimum retirement requirement (i.e., retrofit options in the same cluster (`Retrofit_Id = 1`) all have `Contribute_Min_Retirement = 1`):
    ```
    Thermal.csv

    Resource          │ Zone  | Retrofit | Can_Retrofit | Retrofit_Id | Retrofit_Efficiency
    String            │ Int64 | Int64    | Int64        | Int64       | Float64
    ─────────────────-┼───────┼─────────────────────────┼────────────-┼────────────────────
    coal_1            │ 1     │ 0        │ 1            │ 1           │ 0
    20_NH3_retrofit_1 │ 1     │ 1        │ 0            │ 1           │ 0.85
    20_NH3_retrofit_2 │ 1     │ 1        │ 0            │ 1           │ 0.85
    ```

    ```
    Resource_multistage_data.csv

    Resource          │ Min_Retired_Cap_MW | Contribute_Min_Retirement
    String            │ Float64            | Float64 
    ─────────────────-┼────────────────────┼──────────────────────────
    coal_1            │ 4500               │ 0
    20_NH3_retrofit_1 │ 0                  │ 1                         <---------
    20_NH3_retrofit_2 │ 0                  │ 1                         <---------
    ```

    Example 2: Retrofitted capacity is not allowed to contribute to the minimum retirement requirement (i.e., none of the retrofit options in the same cluster (`Retrofit_Id = 1`) contribute to the minimum retirement requirement (`myopic=0`)):

    Thermal.csv: same as Example 1.

    ```
    Resource_multistage_data.csv

    Resource          │ Min_Retired_Cap_MW | Contribute_Min_Retirement
    String            │ Float64            | Float64
    ─────────────────-┼────────────────────┼──────────────────────────
    coal_1            │ 4500               │ 0
    20_NH3_retrofit_1 │ 0                  │ 0                         <---------
    20_NH3_retrofit_2 │ 0                  │ 0                         <---------
    ```

    And the case where some retrofit options contribute to the minimum retirement requirement and some do not is not currently supported and will be addressed in a future release.

!!! warning "Warning"
    If `New_Build` and `Can_Retire` are both set to 0, the model will not transfer built capacity from one stage to the next, but will instead set capacity to the value of existing capacity from the input files for each stage. Therefore, the user must ensure that the capacity is correctly set in the input files for each stage. Not following this guideline may result in incorrect or unexpected results, particularly when setting a a non-zero value for the `Min_Retired_Cap_MW` parameter. 

#### Settings Files
A separate settings.yml file includes a list of parameters to be specified to formulate the multi-stage planning model.

|                      |                                                                    **multi\_stage\_settings.yml**                                                                    |
|----------------------|:------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| NumStages            | The number of model investment planning stages.                                                                                                                    |
| StageLengths         | A list of lengths of each model stage in years (e.g., [10, 10, 10] for three stages each of length 10). Note that stages could be defined to be of varying length. |
| Myopic               | 0 = perfect foresight, 1 = myopic model (see above table)                                                                                                          |
| ConvergenceTolerance | The relative optimality gap used for convergence of the dual dynamic programming algorithm. Only required when Myopic = 0                                          |
| WACC                 | Rate used to discount non-technology-specific costs from stage to stage (i.e., the “social discount rate”).                                                        |
| WriteIntermittentOutputs | (valid if Myopic = 1) 0 = do not write intermittent outputs, 1 = write intermittent output. |

|                       |                                                                                  **time\_domain\_reduction\_settings.yml**                                                                                  |
|:-----------------------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| MultiStageConcatenate | Designates whether to use time domain reduction for the full set of input data together (1) or to reduce only the first stage data and apply the returned representative periods to the rest of the input data (0). |

### Discounting and cost accounting

Write $DR$ for the general discount rate (the `WACC` field of
`multi_stage_settings.yml`), $L_i$ for the length of stage $i$ in years, and
$N_i = \sum_{s<i} L_s$ for the years elapsed before stage $i$ begins. For a
resource $y$, let $CRP_y$ be its capital recovery period.

**Timing of costs.** All costs are treated as incurred at the end of the year in
which they arise. Stage costs are discounted to the start of the modeling
horizon:

```math
DF_i = \frac{1}{(1+DR)^{N_i}}
```

**Operating and fixed O&M costs.** A stage may span several years, so annual
costs are scaled by

```math
\text{OPEXMULT}_i = \sum_{j=1}^{L_i}\frac{1}{(1+DR)^{j}}
```

**Investment costs.** Annuities are paid from the year after the investment until
the technology's capital recovery period ends or the modeling horizon does,
whichever comes first:

```math
P_{y,i} = \min\left(CRP_y,\; \sum_{s \geq i} L_s\right),
\qquad
A_{y,i} = \sum_{p=1}^{P_{y,i}} \frac{1}{(1+DR)^{p}}
```

Costs falling beyond the horizon are assumed fully recoverable and are excluded,
so the model carries no salvage value. Every annuity is discounted at the general
discount rate $DR$, which represents the planner's time value of money; a
technology-specific cost of capital should be reflected in the annualized
investment cost input itself.

**Age-based retirement.** Capacity reaching the end of its life part way through
a stage remains available for the whole of that stage and retires at the
beginning of the next. Equivalently, capacity built in stage $r$ must have
retired by stage $i$ once $\sum_{t=r}^{i-1} L_t \geq$ its lifetime. This only
differs from measuring to the end of the current stage when stages have unequal
lengths.

**Myopic runs.** The myopic objective charges a single year of each investment
annuity, so it values capital relative to operating costs differently from a
perfect-foresight run, and will tend to build more of it. Reported costs add back
the annuities the objective did not see, so the two modes can be compared; see
the cost output documentation.
