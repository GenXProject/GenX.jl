# Fusion test case without pulse behavior

These fusion plants have
- 0.2 passive parasitic power factor
- 0.1 active parasitic power factor
- 0.05 start energy parasitic power factor, estart
- a 1 hour max pulse time (pulsing every hour), τpu
- 0.125 hour dwell time, τdw

Their nominal "active fraction" is f_act = 1 - τdw / τpu = 0.875

Their nominal "core net capacity factor" is
f_netavgcap = f_act (1 - f_{parasitic,act}) - f_{parasitic,pass} - estart / τpu = 0.5375

Therefore in a linear model, a steady-state demand of 1000MW will require a peak gross capacity of 1860.47 MW, which we see in capacity.csv.
See also that `fusion_net_capacity.csv` has 1000 MW of NetCapacity.
The maximum hourly gross energy output is f_act * 1860.47 = 1627.91, seen in power_balance.csv.
The parasitic power will be 1860.47 * (f_act * f_{parasitic,act} + f_{parasitic,pass} + estart) = 627.91 MW.
The net power generation then equals the demand of 1000 MW.

The plants require 8 hours of maintenance every other "day". (every 2 "years" in the input)
In this example, plants have half of their normal passive parasitic power when under maintenance, or 0.1 of the gross capacity.

During the 8 lull hours the demand is 300MW.
558.14 MW of plants are needed to support the load of 300 MW, since 558.14 * fnetavgcap = 300
To find the number of plants m that can go down for maintenance, solve:

1000 - m 100 fnetavgcap = 300 + 0.1 100 m

where m is the number of plants and the cap_size is 100.
This reduces to m = 10.98, which is what we see in `maint_down.csv`.

Therefore 762.43 MW (gross capacity) of plants do *not* go down for maintenance; they produce fact * 762.42 = 667.12 MW, as seen in power_balance.csv.

The parasitic load during these hours is 10.98 * 0.1 * 100 + 762.42 * (fact * ra + rp + estart) = 367.12, which we see in power_balance.csv.

Calculate total objective
-------------------------
The investment cost is 100000 per MW, so 1860.47 * 100000 = 1.860e8
Each day the gross generation is 667.12 * 8 + 1626.91 * 16 and there are 365 per year, for a variable O&M cost of 1.1455e8
The total objective is then 3.0059626e8.
