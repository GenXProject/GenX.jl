# Method\_of\_morris\_range.csv ([Example](https://github.com/GenXProject/GenX/blob/main/Example_Systems/MethodofMorrisExample/OneZone/Method_of_morris_range.csv))

This file contains the settings parameters required to run the Method of Morris algorithm in GenX. 

!!! note "Note"
    This file is needed if the `MethodofMorris` flag is ON in the YAML file `genx_settings.yml`.

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
2. Percentage variation for uncertain parameters in a given group is identical. For example, if solar cluster 1 and solar cluster 2 both belong to the ‘solar’ group, their `Lower_bound` and `Upper_bound` must be identical.
3. `P_steps` should at least be = 1%, i.e., `Upper_bound – Lower_bound < p_steps`
4. `P_steps` for parameters in one group must be identical
5. `Total_num_trajectory` should be around 3 to 4 times the total number of uncertain parameters
6. `num_trajectory` should be approximately equal to the total number of uncertain parameters
7. `len_design_mat` should be 1.5 to 2 times the total number of uncertain parameters
8. Higher number of `num_trajectory` and `len_design_mat` would lead to higher accuracy
9. Upper and lower bounds should be specified for all the resources included in the `Generators_data.csv` file. If a parameter related to a particular resource is not uncertain, specify upper bound = lower bound = 0.