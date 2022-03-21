# Simple example using minimum and maximum supply constraints.

Example run using fuel-supply constraints.

Can be used to constrain total annual fuel use by fuel type or to create stepwise supply curve for resource constrained fuels (e.g. biofuels).

Sum of fuel consumed by each resource using a contrained fuel type (`dfFuels[:Maximum_Supply_MMBTU].>=0`), must be less than maximum fuel supply specified. Vice versa for minimum supply constraint.
 
* The variable `Minimum_Supply_MMBTU` is provided in the first row of the `Fuels_data.csv` input file. If smaller than 0, no constraint will be added for the fuel.
* The variable `Maximum_Supply_MMBTU` is provided in the second row of the `Fuels_data.csv` input file. If smaller than 0, no constraint will be added for the fuel.

## No fuel-supply constraints

In the example, when no fuel-supply constraints are provided:

* `natural_gas_combined` generator type generates about 46 GWh.
* `solar_pv` generator type is not built out at all.

## With fuel-supply constraints

Adding fuel-supply constraints:

* Maximum for fuel 'NG': 170229 MMBTU (`natural_gas_combined`) which corresponds to half of what was generated without fuel-supply constraints.
* Minimum for fuel 'sun': 100 MMBTU (`solar_pv`) which corresponds to 100 MWh.

Results in capacity expansion:

* `natural_gas_combined` generator type generates about 23 GWh.
* `solar_pv` generator type is built and generates 100 MWh.