# Optimized Scheduled Maintenance
_Added in v0.4_

In the real world, some types of resources (notably, fission) require regular scheduled maintenance, which often takes several weeks.
During this time, the plant produces no power.
This module allows GenX to find the best time of year for plants to undergo maintenance.

GenX can model scheduled maintenance for only some types of plants:

* Thermal plants with Unit Commitment (THERM=1)

## Description of the maintenance model
A plant requires a single contiguous period of $h \ge 1$ hours of maintenance, every $y \ge 1$ years.
For each plant, the best time to start the maintenance period is determined by the optimizer.

During maintenance, the plant cannot be "committed", and therefore

* uses no fuel,
* produces no power,
* and does not contribute to reserves.

Additionally, 

* the plant does not contribute to any Capacity Reserve Margin.

### Treatment of plants that require maintenance only every few years
GenX models a long-term equilibrium,
and each problem generally represents a single full year.
If a plant requires maintenance every $y$ years, we take the simplification that at least $1/y$ of the plants must undergo maintenance in the modeled year.

See also "Interaction with integer unit committment" below.

### Reduction of number of possible start dates
This module creates constraints which work across long periods, and consequently can be very expensive to solve.
In order to reduce the expense, the set of possible maintenance start dates can be limited.
Rather than have maintenance potentially start every hour, one can have possible start dates which are once per day, once per week, etc.
(In reality, maintenance is likely scheduled months in advance, so optimizing down to the hour may not be realistic anyway.)

## How to add scheduled maintenance requirements for a plant
There are four columns which need to be added to the plant data, i.e. in `Generators_data.csv`:

1. `MAINT` should be `1` for plants that require maintenance and `0` otherwise.
2. `Maintenance_Duration` is the number of hours the maintenance period lasts.
3. `Maintenance_Frequency_Years`. If `1`, maintenance every year, if `3` maintenance every 3 years, etc.
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
- Multi-stage has not yet been tested (but please let us know what happens if you test it!).

### Interaction with integer unit committment
If integer unit committment is on (`UCommit=1`), this module may not produce sensible results.
This module works on the level of individual resources (i.e. a specific type of plant in a specific zone.).
If there is only 1 unit of a given resource built in a zone, then it will undergo maintenance every year regardless of its `Maintenance_Frequency_Years`.

## Hint: pre-scheduling maintenance
If you want to pre-schedule when maintenance occurs, you might not need this module.
Instead, you could set the maximum power output of the plant to zero for a certain period, or make its fuel extremely expensive during that time.
However, the plant would still be able to contribute to the Capacity Reserve Margin.

## Outputs produced
If at least one plant has `MAINT=1`, a file `maint_down.csv` will be written listing how many plants are down for maintenance in each timestep.
