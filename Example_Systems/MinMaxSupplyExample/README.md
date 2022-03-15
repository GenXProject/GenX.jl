# Simple example using minimum and maximum supply constraints.

Example run using fuel-supply constraints.

Can be used to constrain total annual fuel use by fuel type or to create stepwise supply curve for resource constrained fuels (e.g. biofuels).

Sum of fuel consumed by each resource using a contrained fuel type (`dfFuels[:Maximum_Supply_MMBTU].>=0`), must be less than maximum fuel supply specified. Vice versa for minimum supply constraint.
 
* The variable `Minimum_Supply_MMBTU` is provided in the first row of the `Fuels_data.csv` input file. If smaller than 0, no constraint will be added for the fuel.
* The variable `Maximum_Supply_MMBTU` is provided in the second row of the `Fuels_data.csv` input file. If smaller than 0, no constraint will be added for the fuel.

## No fuel-supply constraints

In the example, when no fuel-supply constraints are provided:

* `natural_gas_combined` generator type generates about 18 TWh.
* `solar_pv` generator type is not built out at all.

## With fuel-supply constraints

Adding fuel-supply constraints:

* Maximum for fuel 'NG': 67873273 MMBTU (`natural_gas_combined`).
* Minimum for fuel 'sun': 100 MMBTU (`solar_pv`).

Results in capacity expansion:

* `natural_gas_combined` generator type generates about 9 TWh.
* `solar_pv` generator type is built and generates 100 MWh.