# Policy Slack Variables
_Added in 0.3.5_

Rather than modeling policy requirements as inflexible constraints, it may be advantageous to instead allow these requirements to be violated at some predetermined cost. 
This is accomplished via 'slack variables,' which can be used by the model to meet a policy constraint if it cannot be met cost-effectively by normal means. 
Once the incremental shadow price of meeting a policy constraint rises above a cost threshold set by the user, the model will rely on the slack variable to fill any remaining gap. 

Using slack variables rather than hard constraints may be useful for GenX users who wish to avoid unexpected infeasibilities resulting from policy requirements that cannot be met. 
Using slack variables with very high cost thresholds, users can quickly identify specific policy constraints that are effectively infeasible without causing errors. 

Slack variables with lower assigned costs can also be used to model policies with built-in cost thresholds, for example a CO2 Cap with a maximum allowable carbon price of \$200/ton. 
They can be activated for each individual policy type available in GenX, including: Capacity Reserve Margins, Energy Share Requirements, CO2 Caps, Minimum Capacity Requirements, and Maximum Capacity Requirements. 

## Running cases with slack variables

Slack variables are turned off by default in GenX, but can be automatically activated for each policy type by providing the relevant inputs. 
Slack variables will only be activated when the relevant policy type is itself activated in `GenX_settings.yml`. 
For some policy types, slack variables are activated by providing a new input file, while for others they are activated by modifying an existing file. 
Instructions for each policy type are listed below:

## Capacity Reserve Margin

Slack variables for Capacity Reserve Margin constraints are created when GenX detects the presence of the file `Capacity_reserve_margin_slack.csv` in the Inputs folder. 
This file should contain two columns: one titled 'CRM_Constraint' naming the individual Capacity Reserve Margin constraints in the same order in which they are listed in the first row of `Capacity_reserve_margin.csv`, and a second titled 'PriceCap' containing the price thresholds for each constraint. 
The units for these thresholds are $/MW.

## CO2 Cap
Slack variables for CO2 Cap constraints are created when GenX detects the presence of the file `CO2_cap_slack.csv` in the Inputs folder. 
This file should contain two columns: one titled 'CO2_Cap_Constraint' naming the individual CO2 Cap constraints in the same order in which they are listed in the first row of `CO2_Cap.csv`, and a second titled 'PriceCap' containing the price thresholds for each constraint.  The units for these thresholds are $/ton. 
The CO2 Cap slack variable itself is always in units of tons of CO2, even if the CO2 Cap is a rate-based cap.

## Energy Share Requirement

Slack variables for Energy Share Requirement constraints are created when GenX detects the presence of the file `Energy_share_requirement_slack.csv` in the Inputs folder. 
This file should contain two columns: one titled 'ESR_Constraint' naming the individual Energy Share Requirement constraints in the same order in which they are listed in the first row of `Energy_share_requirement.csv`, and a second titled 'PriceCap' containing the price thresholds for each constraint. 
The units for these thresholds are \$/MWh.

## Minimum Capacity Requirement

Slack variables for Minimum Capacity Requirement constraints are created when GenX detects the presence of a column titled 'PriceCap' in the file `Minimum_capacity_requirement.csv`. 
This column contains the price thresholds for each Minimum Capacity Requirement constraint, in units of \$/MW. 

## Maximum Capacity Requirement

Slack variables for Maximum Capacity Requirement constraints are created when GenX detects the presence of a column titled 'PriceCap' in the file `Maximum_capacity_requirement.csv`. 
This column contains the price thresholds for each Maximum Capacity Requirement constraint, in units of \$/MW. 

## Slack Variables Results Files

By default, a policy type's result files include the shadow prices for each policy constraint. 
When slack variables are activated, outputs also include the final values of the slack variables (i.e. the amount by which the policy constraint was violated), and the total costs associated with those slack variables. 
These files are named using the convention `X_prices_and_penalties.csv`, where `X` is the name of the relevant policy type.

GenX will also print the total cost associated with each activated slack variable type in the file `costs.csv`.

## Slack Variables Example

The folder `Example_Systems/SmallNewEngland/ThreeZones_Slack_Variables_Example` contains examples of the input files needed to activate slack variables for each of the policy types in GenX. 
Running this example with a given set of policy constraints activated will generate the relevant slack variables and print their outputs.
 