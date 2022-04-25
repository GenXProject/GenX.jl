# Multi-stage modeling overview
This section describes the available features, inputs and model components related to formulating and solving multi-stage investment planning problems. Two different types of multi-stage problems can be setup:
* Perfect foresight: A single multi-stage investment planning problem that simultaneously optimizes capacity and operations across all specified investment stages
* Myopic: Sequential solution of single-stage investment planning for each investment stage, where capacity additions and retirements from the previous stages are used to determine initial (or existing) capacity at the beginning of the current stage. 

The table below summarizes the key differences in the two model setups.

|                                              | Perfect foresight | Myopic                               |
| :------------------------------------------ | :-----------------: | :------------------------------------: |
| No. of optimization problems solved        | 1                 | Equal to number of investment stages |
| Objective function cost basis              | Net present value | Annualized costs                     |
| Price/dual variable information available? | No                | Yes                                  |

## Additional inputs needed for multi-stage modeling (need to convert to tables)

###  Input data files
Instead of one set of input files, there is one directory of input files that needs to be provided for each planning period or stage (e.g., “Inputs/Inputs_p1/” for the first period “Inputs/Inputs_p2/” for the second period, etc.). Below we list the additional parameters that must be provided in the corresponding stage-specific input files to instantiate a multi-stage planning problem.


|                              |                                                                   **Generators_data.csv**                                                                  |
|:------------------------------|:----------------------------------------------------------------------------------------------------------------------------------------------------------|
| Min\_Retired\_Cap\_MW        | Minimum capacity in MW that must retire in this planning stage.                                                                                            |
| Min\_Retired\_Energy\_Cap\_MW | Minimum energy capacity in MW that must retire in this planning stage.                                                                                     |
| Min\_Retired\_Charge\_Cap\_MW | Minimum charge capacity in MW that must retire in this planning stage.                                                                                     |
| Lifetime                     | The operational lifespan in years of this technology after which it must be retired.                                                                       |
| Capital\_Recovery\_Period      | The technology-specific period in years over which initial capital costs must be recovered.                                                                |
| WACC                         | The technology-specific weighted average cost of capital.                                                                                                  |


|                           |                                                                       **Network.csv**                                                                      |
|:---------------------------|:----------------------------------------------------------------------------------------------------------------------------------------------------------|
| Line\_Max\_Flow\_Possible\_MW | The maximum transmission capacity of the line, as opposed to Line\_Max\_Reinforcement\_MW which now specifies the maximum expansion to the line in one stage. |
| Capital\_Recovery\_Period   | The line-specific period in years over which initial capital costs must be recovered.                                                                |
| WACC                      | The line-specific weighted average cost of capital.                                                                                                  |


### Settings Files
A separate settings.yml file includes a list of parameters to be specified to formulate the multi-stage planning model.

|                      |                                                                    **multi\_stage\_settings.yml**                                                                    |
|----------------------|:------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| NumStages            | The number of model investment planning stages.                                                                                                                    |
| StageLengths         | A list of lengths of each model stage in years (e.g., [10, 10, 10] for three stages each of length 10). Note that stages could be defined to be of varying length. |
| Myopic               | 0 = perfect foresight, 1 = myopic model (see above table)                                                                                                          |
| ConvergenceTolerance | The relative optimality gap used for convergence of the dual dynamic programming algorithm. Only required when Myopic = 0                                          |
| WACC                 | Rate used to discount non-technology-specific costs from stage to stage (i.e., the “social discount rate”).                                                        |

|                       |                                                                                  **time\_domain\_reduction\_settings.yml**                                                                                  |
|:-----------------------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| MultiStageConcatenate | Designates whether to use time domain reduction for the full set of input data together (1) or to reduce only the first stage data and apply the returned representative periods to the rest of the input data (0). |
