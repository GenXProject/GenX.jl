@doc raw"""
	curtailable_variable_renewable!(EP::Model, inputs::Dict, setup::Dict)
This function defines the constraints for operation of variable renewable energy (VRE) resources whose output can be curtailed (``y \in \mathcal{VRE}``), such as utility-scale solar PV or wind power resources or run-of-river hydro resources that can spill water.
The operational constraints for VRE resources are a function of each technology's time-dependent hourly capacity factor (or availability factor, ``\rho^{max}_{y,z,t}``), in per unit terms, and the total available capacity (``\Delta^{total}_{y,z}``).

**Power output in each time step**
For each VRE technology type ``y`` and model zone ``z``, the model allows for incorporating multiple bins with different parameters for resource quality (``\rho^{max}_{y,z,t}``), maximum availability (``\overline{\Omega_{y,z}}``) and investment cost (``\Pi^{INVEST}_{y,z}``, for example, due to interconnection cost differences). We define variables related to installed capacity (``\Delta_{y,z}``) and retired capacity (``\Delta_{y,z}``) for all resource bins for a particular VRE resource type ``y`` and zone ``z`` (``\overline{\mathcal{VRE}}^{y,z}``). However, the variable corresponding to power output in each timestep is only defined for the first bin. Parameter ``VREIndex_{y,z}``, is used to keep track of the first bin, where ``VREIndex_{y,z}=1`` for the first bin and ``VREIndex_{y,z}=0`` for the remaining bins. This approach allows for modeling many different bins per VRE technology type and zone while significantly reducing the number of operational variable (related to power output for each time step from each bin) added to the model with every additional bin. Thus, the maximum power output for each VRE resource type in each zone is given by the following equation:
```math
\begin{aligned}
	\Theta_{y,z,t} \leq \sum_{(x,z)\in \overline{\mathcal{VRE}}^{x,z}}{\rho^{max}_{x,z,t} \times \Delta^{total}_{x,z}}  \hspace{2 cm}  \forall y,z \in \{(y,z)|VREIndex_{y,z}=1, z \in \mathcal{Z}\},t \in \mathcal{T}
\end{aligned}
```
The above constraint is defined as an inequality instead of an equality to allow for VRE power output to be curtailed if desired. This adds the possibility of introducing VRE curtailment as an extra degree of freedom to guarantee that generation exactly meets demand in each time step.
Note that if ```OperationalReserves=1``` indicating that frequency regulation and operating reserves are modeled, then this function calls ```curtailable_variable_renewable_operational_reserves!()```, which replaces the above constraints with a formulation inclusive of reserve provision.
"""
function curtailable_variable_renewable!(EP::Model, inputs::Dict, setup::Dict)
    ## Controllable variable renewable generators
    ### Option of modeling VRE generators with multiple availability profiles and capacity limits -  Num_VRE_Bins in Vre.csv  >1
    ## Default value of Num_VRE_Bins ==1
    println("Dispatchable Resources Module")

    gen = inputs["RESOURCES"]

    OperationalReserves = setup["OperationalReserves"]
    CapacityReserveMargin = setup["CapacityReserveMargin"]

    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)

    VRE = inputs["VRE"]

    VRE_POWER_OUT = intersect(VRE, ids_with_positive(gen, num_vre_bins))
    VRE_NO_POWER_OUT = setdiff(VRE, VRE_POWER_OUT)

    ### Expressions ###

    ## Power Balance Expressions ##

    @expression(EP, ePowerBalanceDisp[t = 1:T, z = 1:Z],
        sum(EP[:vP][y, t] for y in intersect(VRE, resources_in_zone_by_rid(gen, z))))
    add_similar_to_expression!(EP[:ePowerBalance], EP[:ePowerBalanceDisp])

    # Capacity Reserves Margin policy
    if CapacityReserveMargin > 0
        @expression(EP,
            eCapResMarBalanceVRE[res = 1:inputs["NCapacityReserveMargin"], t = 1:T],
            sum(derating_factor(gen[y], tag = res) * EP[:eTotalCap][y] *
                inputs["pP_Max"][y, t] for y in VRE))
        add_similar_to_expression!(EP[:eCapResMarBalance], eCapResMarBalanceVRE)
    end

    ### Constraints ###
    if OperationalReserves == 1
        # Constraints on power output and contribution to regulation and reserves
        curtailable_variable_renewable_operational_reserves!(EP, inputs)
        remove_operational_reserves_for_binned_vre_resources!(EP, inputs)
    else
        # For resource for which we are modeling hourly power output
        for y in VRE_POWER_OUT
            # Define the set of generator indices corresponding to the different sites (or bins) of a particular VRE technology (E.g. wind or solar) in a particular zone.
            # For example the wind resource in a particular region could be include three types of bins corresponding to different sites with unique interconnection, hourly capacity factor and maximim available capacity limits.
            VRE_BINS = intersect(resource_id.(gen[resource_id.(gen) .>= y]),
                resource_id.(gen[resource_id.(gen) .<= y + num_vre_bins(gen[y]) - 1]))

            # Maximum power generated per hour by renewable generators must be less than
            # sum of product of hourly capacity factor for each bin times its the bin installed capacity
            # Note: inequality constraint allows curtailment of output below maximum level.
            @constraint(EP,
                [t = 1:T],
                EP[:vP][y,t]<=sum(inputs["pP_Max"][yy, t] * EP[:eTotalCap][yy]
                for yy in VRE_BINS))
        end
    end

    # Set power variables for all bins that are not being modeled for hourly output to be zero
    for y in VRE_NO_POWER_OUT
        fix.(EP[:vP][y, :], 0.0, force = true)
    end
    ##CO2 Polcy Module VRE Generation by zone
    @expression(EP, eGenerationByVRE[z = 1:Z, t = 1:T], # the unit is GW
        sum(EP[:vP][y, t]
        for y in intersect(inputs["VRE"], resources_in_zone_by_rid(gen, z))))
    add_similar_to_expression!(EP[:eGenerationByZone], eGenerationByVRE)
end

@doc raw"""
	curtailable_variable_renewable_operational_reserves!(EP::Model, inputs::Dict)
When modeling operating reserves, this function is called by ```curtailable_variable_renewable()```, which modifies the constraint for maximum power output in each time step from VRE resources to account for procuring some of the available capacity for frequency regulation ($f_{y,z,t}$) and upward operating (spinning) reserves ($r_{y,z,t}$).
```math
\begin{aligned}
	\Theta_{y,z,t} + f_{y,z,t} + r_{y,z,t} \leq \sum_{(x,z)\in \overline{\mathcal{VRE}}^{x,z}}{\rho^{max}_{x,z,t}\times \Delta^{total}_{x,z}}  \hspace{0.1 cm}   \forall y,z \in \{(y,z)|VREIndex_{y,z}=1, z \in \mathcal{Z}\},t \in \mathcal{T}
\end{aligned}
```
The amount of downward frequency regulation reserves also cannot exceed the current power output.
```math
\begin{aligned}
	f_{y,z,t} \leq \Theta_{y,z,t}
	\forall y,z \in \{(y,z)|VREIndex_{y,z}=1, z \in \mathcal{Z}\},t \in \mathcal{T}
\end{aligned}
```
The amount of frequency regulation and operating reserves procured in each time step is bounded by the user-specified fraction ($\upsilon^{reg}_{y,z}$,$\upsilon^{rsv}_{y,z}$) of available capacity in each period for each reserve type, reflecting the maximum ramp rate for the VRE resource in whatever time interval defines the requisite response time for the regulation or reserve products (e.g., 5 mins or 15 mins or 30 mins). These response times differ by system operator and reserve product, and so the user should define these parameters in a self-consistent way for whatever system context they are modeling.
```math
\begin{aligned}
	r_{y,z,t} \leq \upsilon^{rsv}_{y,z} \sum_{(x,z)\in \overline{\mathcal{VRE}}^{x,z}}{\rho^{max}_{x,z,t}\times \Delta^{total}_{x,z}}  \hspace{1 cm}   \forall y,z \in \{(y,z)|VREIndex_{y,z}=1, z \in \mathcal{Z}\},t \in \mathcal{T} \\
	f_{y,z,t} \leq \upsilon^{reg}_{y,z} \sum_{(x,z)\in \overline{\mathcal{VRE}}^{x,z}}{\rho^{max}_{x,z,t}\times \Delta^{total}_{x,z}}  \hspace{1 cm}   \forall y,z \in \{(y,z)|VREIndex_{y,z}=1, z \in \mathcal{Z}\},t \in \mathcal{T}
\end{aligned}
```
"""
function curtailable_variable_renewable_operational_reserves!(EP::Model, inputs::Dict)
    gen = inputs["RESOURCES"]
    T = inputs["T"]

    VRE = inputs["VRE"]
    VRE_POWER_OUT = intersect(VRE, ids_with_positive(gen, num_vre_bins))
    REG = intersect(VRE_POWER_OUT, inputs["REG"])
    RSV = intersect(VRE_POWER_OUT, inputs["RSV"])

    eTotalCap = EP[:eTotalCap]
    vP = EP[:vP]
    vREG = EP[:vREG]
    vRSV = EP[:vRSV]
    hourly_capacity_factor(y, t) = inputs["pP_Max"][y, t]

    hourly_capacity(y, t) = hourly_capacity_factor(y, t) * eTotalCap[y]
    resources_in_bin(y) = UnitRange(y, y + num_vre_bins(gen[y]) - 1)
    hourly_bin_capacity(y, t) = sum(hourly_capacity(yy, t) for yy in resources_in_bin(y))

    @constraint(EP,
        [y in REG, t in 1:T],
        vREG[y, t]<=reg_max(gen[y]) * hourly_bin_capacity(y, t))
    @constraint(EP,
        [y in RSV, t in 1:T],
        vRSV[y, t]<=rsv_max(gen[y]) * hourly_bin_capacity(y, t))

    expr = extract_time_series_to_expression(vP, VRE_POWER_OUT)
    add_similar_to_expression!(expr[REG, :], -vREG[REG, :])
    @constraint(EP, [y in VRE_POWER_OUT, t in 1:T], expr[y, t]>=0)

    expr = extract_time_series_to_expression(vP, VRE_POWER_OUT)
    add_similar_to_expression!(expr[REG, :], +vREG[REG, :])
    add_similar_to_expression!(expr[RSV, :], +vRSV[RSV, :])
    @constraint(EP, [y in VRE_POWER_OUT, t in 1:T], expr[y, t]<=hourly_bin_capacity(y, t))
end

function remove_operational_reserves_for_binned_vre_resources!(EP::Model, inputs::Dict)
    gen = inputs["RESOURCES"]

    VRE = inputs["VRE"]
    VRE_POWER_OUT = intersect(VRE, ids_with_positive(gen, num_vre_bins))
    REG = inputs["REG"]
    RSV = inputs["RSV"]

    VRE_NO_POWER_OUT = setdiff(VRE, VRE_POWER_OUT)

    for y in intersect(VRE_NO_POWER_OUT, REG)
        fix.(EP[:vREG][y, :], 0.0, force = true)
    end
    for y in intersect(VRE_NO_POWER_OUT, RSV)
        fix.(EP[:vRSV][y, :], 0.0, force = true)
    end
end
