# Optimized Scheduled Maintenance
_Added in v0.4_

In the real world, some types of resources (notably, fission) require regular scheduled maintenance, which often takes several weeks.
During this time, the plant produces no power.
This module allows GenX to find the best time of year for plants to undergo maintenance.

Scheduled maintenance is implemented **only** for thermal plants with unit commitment (THERM=1).

## Description of the maintenance model
A plant requires a single contiguous period of $h \ge 1$ hours of maintenance, every $y \ge 1$ years.
For each plant, the best time to start the maintenance period is determined by the optimizer.

During maintenance, the plant cannot be "commited", and therefore

* uses no fuel,
* produces no power,
* and does not contribute to reserves.

Additionally, 

* the plant does not contribute to any Capacity Reserve Margin.

### Treatment of plants that require maintenance only every few years
GenX models a long-term equilibrium,
and each problem generally represents a single full year.
If a plant requires maintenance every $y$ years, we take the simplification that at least $1/y$ of the plants must undergo maintenance in the modeled year.

See also "Interaction with integer unit commitment" below.

### Reduction of number of possible start dates
This module creates constraints which work across long periods, and consequently can be very expensive to solve.
In order to reduce the expense, the set of possible maintenance start dates can be limited.
Rather than have maintenance potentially start every hour, one can have possible start dates which are once per day, once per week, etc.
(In reality, maintenance is likely scheduled months in advance, so optimizing down to the hour may not be realistic anyway.)

## How to use
There are four columns which need to be added to the plant data, i.e. in the resource `.csv` files:

1. `MAINT` should be `1` for plants that require maintenance and `0` otherwise.
2. `Maintenance_Duration` is the number of hours the maintenance period lasts.
3. `Maintenance_Cycle_Length_Years`. If `1`, maintenance every year, if `3` maintenance every 3 years, etc.
4. `Maintenance_Begin_Cadence`. Spacing between hours in which maintenance can start.

The last three fields must be integers which are greater than 0. 
They are ignored for any plants which do not require maintenance.

`Maintenance_Duration` must be less than the total number of hours in the year.

If `Maintenance_Begin_Cadence` is `1` then the maintenance can begin in any hour.
If it is `168` then it can begin in hours 1, 169, 337, etc.

## Restrictions on use
The maintenance module has these restrictions:

- More than a single maintenance period per year (i.e. every three months) is not possible in the current formulation.
- Only full-year cases can be run; there must be only one "representative period".
It would not make sense to model a *month*-long maintenance period when the year is modeled as a series of representative *weeks*, for example.

### Interaction with integer unit commitment
If integer unit commitment is on (`UCommit=1`) this module may not produce correct results; there may be more maintenance than the user wants.
This is because the formulation specifies that the number of plants that go down for maintenance in the simulated year must be at least (the number of plants in the zone)/(the maintenance cycle length in years).
As a reminder, the number of plants is `eTotalCap / Cap_Size`.

If there were three 500 MW plants (total 1500 MW) in a zone, and they require maintenance every three years (`Maintenance_Cycle_Length_Years=3`), 
the formulation will work properly: one of the three plants will go under maintenance.

But if there was only one 500 MW plant, and it requires maintenance every 3 years, the constraint will still make it do maintenance **every year**, because `ceil(1/3)` is `1`. The whole 500 MW plant will do maintenance. This is the unexpected behavior.

However, if integer unit commitment was relaxed to "linearized" unit commitment (`UCommit=2`), the model will have only 500 MW / 3 = 166.6 MW worth of this plant do maintenance.

## Hint: pre-scheduling maintenance
If you want to pre-schedule when maintenance occurs, you might not need this module.
Instead, you could set the maximum power output of the plant to zero for a certain period, or make its fuel extremely expensive during that time.
However, the plant would still be able to contribute to the Capacity Reserve Margin.

## Outputs produced
If at least one plant has `MAINT=1`, a file `maint_down.csv` will be written listing how many plants are down for maintenance in each timestep.

## Notes on mathematical formulation
The formulation of the maintenance state is very similar to the formulation of unit commitment.

There is a variable called something like `vMSHUT` which is analogous to `vSTART` and controls the start of the maintenance period.
There is another variable called something like `vMDOWN` analogous to `vCOMMIT` which controls the maintenance status in any hour.

A constraint ensures that the value of `vMDOWN` in any hour is always more than the number of `vMSHUT`s in the previous `Maintenance_Duration` hours.

Another constraint ensures that the number of plants committed (`vCOMMIT`) at any one time plus the number of plants under maintenance (`vMDOWN`) is less than the total number of plants.

## Developer note: adding maintenance to a resource
The maintenance formulation is applied on a per-resource basis, by calling the function [`GenX.maintenance_formulation!`](@ref). 
See [`GenX.maintenance_formulation_thermal_commit!`](@ref) for an example of how to apply it to a new resource.

* The resource must have a `eTotalCap`-like quantity and a `cap_size`-like parameter; only the ratio of the two is used.
* The resource must have a `vCOMMIT`-like variable which is proportional to the maximum power output, etc at any given timestep.

The generic maintenance module functions are listed below.

```@docs
GenX.maintenance_formulation!
GenX.resources_with_maintenance
GenX.maintenance_down_name
GenX.maintenance_shut_name
GenX.controlling_maintenance_start_hours
GenX.ensure_maintenance_variable_records!
GenX.has_maintenance
GenX.maintenance_down_variables
```