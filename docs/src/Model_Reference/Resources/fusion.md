# Fusion
_Added in v0.4.2_

Fusion power plants could be a future source of clean, firm electricity.
Most proposals for fusion plants use a thermal cycle, where the energy of fusion heats a working fluid.
The working fluid passes through a turbine connected to a generator.
These plants would be broadly similar to fission plants.
They might also have some fusion-specific operational behaviors, which are implemented in this module.

This fusion module is implemented **only** for thermal plants with unit commitment (THERM=1).

(Some proposals for fusion plants, notably those by Helion Energy, would not need a thermal cycle and are not well-described by this module.)

## Description of the fusion model

There are three domains in which a fusion plant of this model may differ from a standard thermal plant.

1. **Parasitic power**. Fusion plants may require significant parasitic ("recirculating") power for various subsystems, or to initiate and drive the reactions.
2. **Hourly-scale pulsed operational behavior**. Pulsed _tokamak_ plants may need to operate in cycles lasting one to a few hours.
3. **Maintenance and associated constraints.** Maintenance may be more significant for fusion than other plants, and materials-engineering-related limitations may constrain plant operation.

There are nine optional parameters for fusion in this model; all can be mixed and matched.
Some of the properties span more than one of these domains.

### Parasitic power
Fusion plant designs often require significant amounts of electrical energy (and instantenous power)

1. to maintain the vacuum pumps, cryogenic systems, tritium plants,
2. for heating systems, control magnet systems, target manufacturing, or lasers, 
3. or for starting up a fusion plasma pulse.

These correspond to what we term
1. Passive parasitic power: systems which are always on regardless of whether the plant is in the committed state (actively producing electricity). These parasitic loads may be reduced during extended scheduled maintenance periods.
2. Active parasitic power: systems which are required while the plant is producing electricity. In magnetic fusion devices the amount of power required for these systems is likely nearly independent of the power level of the plant. Therefore in this model the active parasitic power depends on the commitment state of the plant, not the power level.
3. Pulse start power and pulse start energy. Magnetic fusion devices may require a large amount of power to start the plasma pulse. This can be up to hundreds of MW, but only for a few seconds to minutes. GenX is an hourly electricity systems model, so this behavior cannot be resolved in detail. Instead, the peak power draw from the grid and the time-integral of the power draw (pulse start energy) are input parameters.
The pulse start _power_ is used as part of the capacity reserve margin formulation, and the pulse start _energy_ is used elsewhere.
(In practical designs this power draw would largely be buffered on-site, so the external grid would not see a sudden spike.)

### Hourly-scale pulsed operational behavior

Pulsed tokamaks (as opposed to steady-state tokamaks) often call for an operational cycle where the plasma is on for 30 minutes to a few hours before carefully being drawn down.
The _maximum pulse length_ is typically limited by the engineering of the "central solenoid", one of the large magnets.
A _dwell time_ of a few minutes to 30 minutes is taken to allow various systems to be reset and readied for the next plasma pulse; during this time there is no plasma and no fusion occuring.
Restarting the plasma may require a significant amount of parasitic power draw, described above.

#### Pulses are stressful
Starting a plasma pulse stresses the central solenoid (for pulsed tokamaks), magnets more generally (in other designs), first wall components, and other systems.
Concerns of cyclic thermal fatigue may limit the number of pulse starts.

This module implements a limit expressed in maximum starts per year.

### Maintenance and maintenance-driven operational constraints

Maintenance is likely more lengthy (and therefore more economically significant) for fusion than for existing types of power plants.
This fusion module is fully compatible with the scheduled maintenance module.
There also also three fusion-specific aspects. 
1. The reduction of passive parasitic power during scheduled maintenance (mentioned above), 
2. the constraint on the maximum pulse starts per year (mentioned above).
3. In many designs, neutrons damage the first wall, blanket, and/or vacuum vessel of the plant and they eventually need to be replaced. This can be expressed as a limit on the total (gross) energy produced by the plant between maintenance cycles. This module implements a constraint that can limit the total energy production (as measured in full-power-years) over a year.

## How to use
A fusion plant is a type of Thermal resource.
In addition to the standard Thermal columns (cost, up time, down time, ramp rates, min power) there is one required `fusion` column and nine optional columns in `Thermal.csv` file:

1. `fusion` should be `1` for fusion plants and `0` otherwise.
2. `parasitic_passive`.
3. `parasitic_active`.
4. `parasitic_start_energy`.
5. `parasitic_start_power`.
6. `dwell_time`.
7. `max_up_time`.
8. `max_starts`.
9. `max_fpy_per_year`.
10. `parasitic_passive_maintenance_remaining`.

The purpose, defaults, units, and valid ranges for these parameters are described below.

#### Parasitic power parameters
The parameters `parasitic_passive`, `parasitic_active`, `parasitic_start_energy`, and `parasitic_start_power` must have values of zero or more.
These values are expressed as fractions of the plant's gross capacity.
For example, if `vCAP` is 1000 MW and `parasitic_passive` is 0.1, the plant would require a 100 MW parasitic power draw.
The maximum gross output of the plant is 1000 MW, and the maximum net output is 900 MW.
By default these four parasitic load parameters are $0$.

The `parasitic_start_energy` and `parasitic_start_power` are related, as described above.
If starting a plasma pulse in a 1000-MW-gross plant requires a draw of 500 MW for 3 minutes, then `parasitic_start_power` would be $0.5$ and `parasitic_start_energy` would be $(500/1000) * (3/60) = 0.025$, where 60 is the number of minutes in an hour. 
The plasma startup sequence is assumed to be shorter than an hour: while this is not checked programatically, the `parasitic_start_power` should, logically, always be equal to or larger than the `parasitic_start_energy`.

#### Dwell time
The `dwell_time` parameter is expressed in fractions of an hour.
It must be between $0$ and $1$.
The default is $0$.

The dwell time is counted in the same hour as the start of a plasma pulse.
Therefore the pulse start hour may have less net generation due to the `parasitic_start_energy` as well as the dwell time.

_Nota bene_: while at first blush the dwell time and `parastic_start_energy` might seem interchangeable as ways to reduce the net power output during the start hour, a dwell time does not contribute to the accumulated gross power generation as is constrained by `max_fpy_per_year`.

#### Operational constraints
The `max_up_time` constraint is activated by entering an integer denoting the length of the pulse in hours.
The value must logically be positive and less than the number of hours in the simulation.
A `max_up_time` of `1` will result in a new pulse starting every hour.
A `max_up_time` of `0` is not well defined; the default of no restriction is entered with `-1`.

_Note_: if the `dwell_time` is nonzero, the actual pulse length always will be shorter than the `max_pulse_length` here.

The `max_starts` constraint is activated by entering a positive integer denoting the maximum number of starts per year.
A `max_starts` of `0` would prevent the plant from starting; the default of no restriction is entered with `-1`.

The `max_fpy_per_year` constraint is activated by entering a fraction between $0$ and $1$.
This constrains the total gross power production as a fraction of the gross capacity measured in full-power years (FPY).
The default of no restriction is entered with `-1`.
Note that if the plant has a dwell time $t_\mathrm{dw} > 0$ and a maximum up time, the theoretical maximum gross power production is already less than one full-power year per year.
For example, if there is a 0.5 hour dwell time and a max up time of 2 hours, then the plant can operate at peak power for 1.5 hours out of every 2, which yields a theoretical maximum throughput of 0.75 FPY per year.
In this case a `max_fpy_per_year` of 0.75 or more would have no effect.

#### Modification to parasitic power during maintenance

The `parasitic_passive_maintenance_remaining` parameter is only used for plants also using the scheduled maintenance module (`maint = 1`).
The value must be between $0$ and $1$.
The default is $0$; in this case there is no parasitic power during scheduled maintenance periods.
With a value of $1$ the parasitic power does not decrease during maintenance.
With a value of $0.5$ it is reduced by half, and so on.

## Outputs produced

Use of the fusion module leads to two new outputs files, and changes to existing output files.

- `fusion_pulse_starts`. This file is similar to `start/commit/shutdown.csv` for unit committment.
There is a column for each fusion resource component and a row for each timestep.
Values are number of plant units (of a given resource component) starting a fusion pulse in each timestep.

- `fusion_parasitic_power`. This file is similar to `charge.csv`.
There is a column for each fusion resource component and a row for each timestep.
Values are the parasitic energy in MWh drawn by each resource component in each timestep.
This is the sum of the passive parasitic power, the active parasitic power, and the pulse start energy.
Values are always nonnegative. Positive values represent power flowing from the grid to the plant.

- `fusion_net_capacity_factor`. This is the ratio of the net power production (gross - parasitic) to the annual net capacity of the plant. The numerator here is always smaller than that of the standard capacity factor and could even be negative if the parasitic power is very large and the plant is not used often. The denominator is also smaller than that in the standard capacity factor because it accounts for parasitic power and dwell time.

### Notes on other outputs

- `capacity_factor`: This standard output file reports the _gross_ capacity factor for the plant:
The ratio of the gross power produced to (the gross capacity * one year). Compare with the `fusion_net_capacity_factor` above.

- `charge`: fusion parasitic power is reported in this file.

## Mathematical formulation of fusion module

### Pulse start and pulse status
There are two new variables, representing the number of pulse starts ($\chi^{pulse}_{y,z,t}$) and pulses underway ($\nu^{pulse}_{y,z,t}$).
These are similar to the conventional unit commitment start $\chi$ and commit status $\nu$.

```math
\begin{align*}
0 & \le \chi^{pulse}_{y,z,t} \le \overline{\Omega}^{size}_{y,z} \cdot \Delta^\mathrm{total}_{y,z} \\
0 & \le \nu^{pulse}_{y,z,t} \le  \overline{\Omega}^{size}_{y,z} \cdot \Delta^\mathrm{total}_{y,z}
\end{align*}
```

The two pulse variables are linked using $\tau^{pulse,up}_{y,z}$, the `max_up_time`:

```math
\nu^{pulse}_{y,z,t} \le  \sum_{\hat{t} = t - (\tau^{pulse,up}_{y,z} -1)}^{t} \chi^{pulse}_{y,z,\hat{t}}
```

They are further constrained by the plant's _conventional_ commitment state,

```math
\begin{align*}
\nu^{pulse}_{y,z,t} & \le \nu_{y,z,t} \\
\quad \quad \chi^{pulse}_{y,z,t} & \le \nu_{y,z,t}.
\end{align*}
```

The optional constraint on the maximum number of pulses per year, `max_starts` $\overline{\chi}^{pulse}_{y,z}$ is formulated as

```math
\sum_{t \in \mathcal{T}} \chi^{pulse}_{y,z,t} \cdot \omega_t \cdot \overline{\Omega}^{size}_{y,z} \le \overline{\chi}^{pulse}_{y,z} \cdot \Delta^{\mathrm{total}}_{y,z}.
```

### Dwell time limit on power
During the hours when the plant starts, the power generation $\Theta_{y,z,t}$ is limited due to the `dwell_time` $\tau^{dwell}_{y,z}$ by the constraint

```math
\Theta_{y,z,t} \le \overline{\Omega}^{size}_{y,z} \cdot \left(\nu^{pulse}_{y,z,t} - \tau^{dwell}_{y,z} \chi^{pulse}_{y,z,t}\right).
```

### Max FPY per year constraint
Optionally, the gross power generation during the year is limited by the maximum-FPY-per-year parameter $\overline{\Theta}^{FPY}_{y,z}$

```math
\sum_{t \in \mathcal{T}} \Theta_{y,z,t} \le T \cdot \Delta^{\mathrm{total}}_{y,z} \cdot \overline{\Theta}^{FPY}_{y,z}
```

where $T$ is the number of hours in the year.

### Parasitic power

The passive parasitic power is 

```math
\Pi^{parasitic,pass}_{y,z,t} = f^{parasitic,pass}_{y,z} \cdot \left(\Delta^{total}_{y,z} - \chi^{maint}_{y,z,t} \left(1 - f^{parasitic,pass,maint}_{y,z}\right) \overline{\Omega}^{size}_{y,z}\right)
```

where $\chi^{maint}_{y,z,t}$ is the number of units under maintenance and $f^{parasitic,pass,maint}_{y,z}$ is fraction of passive parasitic power which remains during maintenance.

The active parasitic power is

```math
\Pi^{parasitic,act}_{y,z,t} = \left(\nu^{pulse}_{y,z,t} - \chi^{pulse}_{y,z,t} \cdot \tau^{dwell}_{y,z}\right) \cdot f^{parasitic,act}_{y,z} \cdot \overline{\Omega}^{size}_{y,z}
```

and the parasitic pulse start energy is 

```math
\Pi^{parasitic,pulse,energy}_{y,z,t} = \chi^{pulse}_{y,z,t} \cdot f^{parasitic,pulse,energy}_{y,z} \cdot \overline{\Omega}^{size}_{y,z}.
```

The **total parasitic power** from each technology $y$ in zone $z$ is

```math
\Pi^{parasitic,total}_{y,z,t} = \Pi^{parasitic,pass}_{y,z,t} + \Pi^{parasitic,act}_{y,z,t} + \Pi^{parasitic,pulse,energy}_{y,z,t};
```

the sum of the parasitic power across all fusion technologies $y$ in zone $z$ is subtracted from the power balance in that zone.

The parasitic pulse start power, used for the capacity reserve margin formulation, is

```math
\Pi^{parasitic,pulse,power}_{y,z,t} = \chi^{pulse}_{y,z,t} \cdot f^{parasitic,pulse,power}_{y,z} \cdot \overline{\Omega}^{size}_{y,z}.
```

### Capacity reserve margin contribution

The capacity 

As a reminder, for standard thermal plants the capacity reserve margin contribution is $\epsilon^{CRM}_{y,z,p} \cdot \Delta^{total}$.

For fusion plants, the contribution depends on $\nu^{pulse}_{y,z,t}$ rather than $\Delta^{\mathrm{total}}_{y,z}$.

```math

\epsilon^{CRM}_{y,z,p} \left(\nu^{pulse}_{y,z,t}
- \chi^{pulse}_{y,z,t} \cdot \tau^{dwell}_{y,z}
\right) \overline{\Omega}^{size}_{y,z}

- \epsilon^{CRM}_{y,z,p} \left(\Pi^{parasitic,act}_{y,z,t} + \Pi^{parasitic,pulse,power}_{y,z,t}\right) - \Pi^{parasitic, pass}_{y,z,t}

```

The first term is gross power production possible during an hour, depending on the pulse state.
The second term subtracts the parasitic active and start power. 
The last term subtracts the passive parasitic power.
Unlike the first two it is not subject to the reliability derating $\epsilon^{CRM}$ because passive power is assumed to be drawn even during unscheduled downtime.

Note that in this formulation, it is possible for CRM contribution to be negative (particularly, not not necessarily, if the plant is a net sink of electricity).

This formulation is cross-compatible with the maintenance module. If a plant is undergoing maintenance the first two terms will be zero, and the parasitic passive power will be reduced (see formula above).

### Energy share requirement

The total parasitic power is subtracted from a plant's contribution to an energy share requirement.
Thus for fusion the plant contributes its _net_ energy production.

# Developer's docs

The Fusion module was written so that its constraints of the module could be "bolted on" to anything with 

- a power-like expression (e.g. `vP[y,:]` or `vP[y,:] + vREG[y,:] + vRSV[y,:]`), 
- a capacity-like expression (`eTotalCap`) and 
- a commitment-state expression (`vCOMMIT`).

So far it has only been attached to thermal plants with unit commitment, but it could be used in the future for more complicated entities like a heat source attached to a thermal storage unit and a generator.
Like the `maintenance` module, the constraints of the fusion module apply to one "resource component" at a time, rather than a `"SET"` of resources.
The time-series variables and expressions for each fusion component have unique `base_name`s, like `vFusionPulseStart_MA_fusion[t=1:T]` for a resource named `MA_fusion`.
This makes writing output slightly trickier, as the variables and expressions are evaluated (with `JuMP.value`) one at a time.

Many of the functions below assume little about what they are attached to.
Others act as the interface between fusion and a plant built with the `thermal_commit` module.


```@autodocs
Modules = [GenX]
Pages = ["fusion.jl", "fusion_maintenance.jl", "fusion_policy_adjustments.jl"]
```

