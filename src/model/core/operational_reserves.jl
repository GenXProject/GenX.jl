##########################################################################################################################################
# The operational_reserves.jl module contains functions to creates decision variables related to frequency regulation and reserves provision
# and constraints setting overall system requirements for regulation and operating reserves.
##########################################################################################################################################

@doc raw"""
	operational_reserves!(EP::Model, inputs::Dict, setup::Dict)

This function sets up reserve decisions and constraints, using the operational_reserves_core()` and operational_reserves_contingency()` functions.
"""
function operational_reserves!(EP::Model, inputs::Dict, setup::Dict)
    UCommit = setup["UCommit"]

    if inputs["pStatic_Contingency"] > 0 ||
       (UCommit >= 1 && inputs["pDynamic_Contingency"] >= 1)
        operational_reserves_contingency!(EP, inputs, setup)
    end

    operational_reserves_core!(EP, inputs, setup)
end

@doc raw"""
	operational_reserves_contingency!(EP::Model, inputs::Dict, setup::Dict)

This function establishes several different versions of contingency reserve requirement expression, $CONTINGENCY$ used in the operational_reserves_core() function below.

Contingency operational reserves represent requirements for upward ramping capability within a specified time frame to compensated for forced outages or unplanned failures of generators or transmission lines (e.g. N-1 contingencies).

There are three options for the $Contingency$ expression, depending on user settings:
	1. a static contingency, in which the contingency requirement is set based on a fixed value (in MW) specified in the '''Operational_reserves.csv''' input file;
	2. a dynamic contingency based on installed capacity decisions, in which the largest 'installed' generator is used to determine the contingency requirement for all time periods; and
	3. dynamic unit commitment based contingency, in which the largest 'committed' generator in any time period is used to determine the contingency requirement in that time period.

Note that the two dynamic contigencies are only available if unit commitment is being modeled.

**Static contingency**
Option 1 (static contingency) is expressed by the following constraint:
```math
\begin{aligned}
	Contingency = \epsilon^{contingency}
\end{aligned}
```
where $\epsilon^{contingency}$ is static contingency requirement in MWs.

**Dynamic capacity-based contingency**
Option 2 (dynamic capacity-based contingency) is expressed by the following constraints:
```math
\begin{aligned}
	& Contingency \geq \Omega^{size}_{y,z} \times \alpha^{Contingency,Aux}_{y,z} & \forall y \in \mathcal{UC}, z \in \mathcal{Z}\\
	& \alpha^{Contingency,Aux}_{y,z} \leq \Delta^{\text{total}}_{y,z} & \forall y \in \mathcal{UC}, z \in \mathcal{Z}\\
	& \Delta^{\text{total}}_{y,z} \leq M_y \times \alpha^{Contingency,Aux}_{y,z} & \forall y \in \mathcal{UC}, z \in \mathcal{Z}\\
\end{aligned}
```

where $M_y$ is a `big M' constant equal to the largest possible capacity that can be installed for generation cluster $y$, and $\alpha^{Contingency,Aux}_{y,z} \in [0,1]$ is a binary auxiliary variable that is forced by the second and third equations above to be 1 if the total installed capacity $\Delta^{\text{total}}_{y,z} > 0$ for any generator $y \in \mathcal{UC}$ and zone $z$, and can be 0 otherwise. Note that if the user specifies contingency option 2, and is also using the linear relaxation of unit commitment constraints, the capacity size parameter for units in the set $\mathcal{UC}$ must still be set to a discrete unit size for this contingency to work as intended.

**Dynamic commitment-based contingency**
Option 3 (dynamic commitment-based contingency) is expressed by the following set of constraints:
```math
\begin{aligned}
	& Contingency \geq \Omega^{size}_{y,z} \times Contingency\_Aux_{y,z,t} & \forall y \in \mathcal{UC}, z \in \mathcal{Z}\\
	& Contingency\_Aux_{y,z,t} \leq \nu_{y,z,t} & \forall y \in \mathcal{UC}, z \in \mathcal{Z}\\
    & \nu_{y,z,t} \leq M_y \times Contingency\_Aux_{y,z,t} & \forall y \in \mathcal{UC}, z \in \mathcal{Z}\\
\end{aligned}
```

where $M_y$ is a `big M' constant equal to the largest possible capacity that can be installed for generation cluster $y$, and $Contingency\_Aux_{y,z,t} \in [0,1]$ is a binary auxiliary variable that is forced by the second and third equations above to be 1 if the commitment state for that generation cluster $\nu_{y,z,t} > 0$ for any generator $y \in \mathcal{UC}$ and zone $z$ and time period $t$, and can be 0 otherwise. Note that this dynamic commitment-based contingency can only be specified if discrete unit commitment decisions are used (e.g. it will not work if relaxed unit commitment is used).
"""
function operational_reserves_contingency!(EP::Model, inputs::Dict, setup::Dict)
    println("Operational Reserves Contingency Module")

    gen = inputs["RESOURCES"]

    T = inputs["T"]     # Number of time steps (hours)
    UCommit = setup["UCommit"]
    COMMIT = inputs["COMMIT"]

    if UCommit >= 1
        pDynamic_Contingency = inputs["pDynamic_Contingency"]
    end

    ### Variables ###

    # NOTE: If Dynamic_Contingency == 0, then contingency is a fixed parameter equal the value specified in Operational_reserves.csv via pStatic_Contingency.
    if UCommit == 1 && pDynamic_Contingency == 1
        # Contingency = largest installed thermal unit
        @variable(EP, vLARGEST_CONTINGENCY>=0)
        # Auxiliary variable that is 0 if vCAP = 0, 1 otherwise
        @variable(EP, vCONTINGENCY_AUX[y in COMMIT], Bin)
    elseif UCommit == 1 && pDynamic_Contingency == 2
        # Contingency = largest committed thermal unit in each time period
        @variable(EP, vLARGEST_CONTINGENCY[t = 1:T]>=0)
        # Auxiliary variable that is 0 if vCOMMIT = 0, 1 otherwise
        @variable(EP, vCONTINGENCY_AUX[y in COMMIT, t = 1:T], Bin)
    end

    ### Expressions ###
    if UCommit == 1 && pDynamic_Contingency == 1
        # Largest contingency defined as largest installed generator
        println("Dynamic Contingency Type 1: Modeling the largest contingency as the largest installed generator")
        @expression(EP, eContingencyReq[t = 1:T], vLARGEST_CONTINGENCY)
    elseif UCommit == 1 && pDynamic_Contingency == 2
        # Largest contingency defined for each hour as largest committed generator
        println("Dynamic Contingency Type 2: Modeling the largest contingency as the largest largest committed generator")
        @expression(EP, eContingencyReq[t = 1:T], vLARGEST_CONTINGENCY[t])
    else
        # Largest contingency defined fixed as user-specifed static contingency in MW
        println("Static Contingency: Modeling the largest contingency as user-specifed static contingency")
        @expression(EP, eContingencyReq[t = 1:T], inputs["pStatic_Contingency"])
    end

    ### Constraints ###

    # Dynamic contingency related constraints
    # option 1: ensures vLARGEST_CONTINGENCY is greater than the capacity of the largest installed generator
    if UCommit == 1 && pDynamic_Contingency == 1
        @constraint(EP,
            cContingency[y in COMMIT],
            vLARGEST_CONTINGENCY>=cap_size(gen[y]) * vCONTINGENCY_AUX[y])
        # Ensure vCONTINGENCY_AUX = 0 if total capacity = 0
        @constraint(EP, cContAux1[y in COMMIT], vCONTINGENCY_AUX[y]<=EP[:eTotalCap][y])
        # Ensure vCONTINGENCY_AUX = 1 if total capacity > 0
        @constraint(EP,
            cContAux2[y in COMMIT],
            EP[:eTotalCap][y]<=inputs["pContingency_BigM"][y] * vCONTINGENCY_AUX[y])

        # option 2: ensures vLARGEST_CONTINGENCY is greater than the capacity of the largest commited generator in each hour
    elseif UCommit == 1 && pDynamic_Contingency == 2
        @constraint(EP,
            cContingency[y in COMMIT, t = 1:T],
            vLARGEST_CONTINGENCY[t]>=cap_size(gen[y]) * vCONTINGENCY_AUX[y, t])
        # Ensure vCONTINGENCY_AUX = 0 if vCOMMIT = 0
        @constraint(EP,
            cContAux[y in COMMIT, t = 1:T],
            vCONTINGENCY_AUX[y, t]<=EP[:vCOMMIT][y, t])
        # Ensure vCONTINGENCY_AUX = 1 if vCOMMIT > 0
        @constraint(EP,
            cContAux2[y in COMMIT, t = 1:T],
            EP[:vCOMMIT][y, t]<=inputs["pContingency_BigM"][y] * vCONTINGENCY_AUX[y, t])
    end
end

@doc raw"""
	operational_reserves_core!(EP::Model, inputs::Dict, setup::Dict)

This function creates decision variables related to frequency regulation and reserves provision and constraints setting overall system requirements for regulation and operating reserves.

**Regulation and reserves decisions**
$f_{y,t,z} \geq 0$ is the contribution of generation or storage resource $y \in Y$ in time $t \in T$ and zone $z \in Z$ to frequency regulation

$r_{y,t,z} \geq 0$ is the contribution of generation or storage resource $y \in Y$ in time $t \in T$ and zone $z \in Z$ to operating reserves up

We assume frequency regulation is symmetric (provided in equal quantity towards both upwards and downwards regulation). To reduce computational complexity, operating reserves are only modeled in the upwards direction, as downwards reserves requirements are rarely binding in practice.

Storage resources ($y \in \mathcal{O}$) have two pairs of auxilary variables to reflect contributions to regulation and reserves when charging and discharging, where the primary variables ($f_{y,z,t}$ and $r_{y,z,t}$) becomes equal to sum of these auxilary variables.

Co-located VRE-STOR resources are described further in the reserves function for colocated VRE and storage resources (```vre_stor_operational_reserves!()```).

**Unmet operating reserves**

$unmet\_rsv_{t} \geq 0$ denotes any shortfall in provision of operating reserves during each time period $t \in T$

There is a penalty $C^{rsv}$ added to the objective function to penalize reserve shortfalls, equal to:

```math
\begin{aligned}
	C^{rvs} = \sum_{t \in T} \omega_t \times unmet\_rsv_{t}
\end{aligned}
```

**Frequency regulation requirements**

Total requirements for frequency regulation (aka primary reserves) in each time step $t$ are specified as fractions of hourly demand (to reflect demand forecast errors) and variable renewable avaialblity in the time step (to reflect wind and solar forecast errors).

```math
\begin{aligned}
& \sum_{y \in Y, z \in Z} f_{y,t,z} \geq \epsilon^{demand}_{reg} \times \sum_{z \in Z} \mathcal{D}_{z,t} + \epsilon^{vre}_{reg} \times (\sum_{z \in Z} \rho^{max}_{y,z,t} \times \Delta^{\text{total}}_{y,z} \\
& + \sum_{z \in Z} \rho^{max,pv}_{y,z,t} \times \Delta^{\text{total,pv}}_{y,z} + \sum_{z \in Z} \rho^{max,wind}_{y,z,t} \times \Delta^{\text{total,wind}}_{y,z}) \quad \forall t \in T
\end{aligned}
```
where $\mathcal{D}_{z,t}$ is the forecasted electricity demand in zone $z$ at time $t$ (before any demand flexibility);
$\rho^{max}_{y,z,t}$ is the forecasted capacity factor for standalone variable renewable resources $y \in VRE$ and zone $z$ in time step $t$;
$\rho^{max,pv}_{y,z,t}$ is the forecasted capacity factor for co-located solar PV resources $y \in \mathcal{VS}^{pv}$ and zone $z$ in time step $t$;
$\rho^{max,wind}_{y,z,t}$ is the forecasted capacity factor for co-located wind resources $y \in \mathcal{VS}^{pv}$ and zone $z$ in time step $t$;
$\Delta^{\text{total,pv}}_{y,z}$ is the total installed capacity of co-located solar PV resources $y \in \mathcal{VS}^{pv}$ and zone $z$;
$\Delta^{\text{total,wind}}_{y,z}$ is the total installed capacity of co-located wind resources $y \in \mathcal{VS}^{wind}$ and zone $z$;
and $\epsilon^{demand}_{reg}$ and $\epsilon^{vre}_{reg}$ are parameters specifying the required frequency regulation as a fraction of forecasted demand and variable renewable generation.

**Operating reserve requirements**

Total requirements for operating reserves in the upward direction (aka spinning reserves or contingency reserces or secondary reserves) in each time step $t$ are specified as fractions of time step's demand (to reflect demand forecast errors) and variable renewable avaialblity in the time step (to reflect wind and solar forecast errors) plus the largest planning contingency (e.g. potential forced generation outage).

```math
\begin{aligned}
	& \sum_{y \in Y, z \in Z} r_{y,z,t} + r^{unmet}_{t} \geq \epsilon^{demand}_{rsv} \times \sum_{z \in Z} \mathcal{D}_{z,t} + \epsilon^{vre}_{rsv} \times (\sum_{z \in Z} \rho^{max}_{y,z,t} \times \Delta^{\text{total}}_{y,z} \\
	& + \sum_{z \in Z} \rho^{max,pv}_{y,z,t} \times \Delta^{\text{total,pv}}_{y,z} + \sum_{z \in Z} \rho^{max,wind}_{y,z,t} \times \Delta^{\text{total,wind}}_{y,z}) + Contingency \quad \forall t \in T
\end{aligned}
```

where $\mathcal{D}_{z,t}$ is the forecasted electricity demand in zone $z$ at time $t$ (before any demand flexibility);
$\rho^{max}_{y,z,t}$ is the forecasted capacity factor for standalone variable renewable resources $y \in VRE$ and zone $z$ in time step $t$;
$\rho^{max,pv}_{y,z,t}$ is the forecasted capacity factor for co-located solar PV resources $y \in \mathcal{VS}^{pv}$ and zone $z$ in time step $t$;
$\rho^{max,wind}_{y,z,t}$ is the forecasted capacity factor for co-located wind resources $y \in \mathcal{VS}^{wind}$ and zone $z$ in time step $t$;
$\Delta^{\text{total}}_{y,z}$ is the total installed capacity of standalone variable renewable resources $y \in VRE$ and zone $z$;
$\Delta^{\text{total,pv}}_{y,z}$ is the total installed capacity of co-located solar PV resources $y \in \mathcal{VS}^{pv}$ and zone $z$;
$\Delta^{\text{total,wind}}_{y,z}$ is the total installed capacity of co-located wind resources $y \in \mathcal{VS}^{wind}$ and zone $z$;
and $\epsilon^{demand}_{rsv}$ and $\epsilon^{vre}_{rsv}$ are parameters specifying the required contingency reserves as a fraction of forecasted demand and variable renewable generation. $Contingency$ is an expression defined in the operational\_reserves\_contingency!() function meant to represent the largest `N-1` contingency (unplanned generator outage) that the system operator must carry operating reserves to cover and depends on how the user wishes to specify contingency requirements.
"""
function operational_reserves_core!(EP::Model, inputs::Dict, setup::Dict)

    # DEV NOTE: After simplifying reserve changes are integrated/confirmed, should we revise such that reserves can be modeled without UC constraints on?
    # Is there a use case for economic dispatch constraints with reserves?

    println("Operational Reserves Core Module")

    gen = inputs["RESOURCES"]
    UCommit = setup["UCommit"]

    T = inputs["T"]     # Number of time steps (hours)

    REG = inputs["REG"]
    RSV = inputs["RSV"]
    STOR_ALL = inputs["STOR_ALL"]

    pDemand = inputs["pD"]
    pP_Max(y, t) = inputs["pP_Max"][y, t]

    systemwide_hourly_demand = sum(pDemand, dims = 2)
    function must_run_vre_generation(t)
        sum(
            pP_Max(y, t) * EP[:eTotalCap][y]
            for y in intersect(inputs["VRE"], inputs["MUST_RUN"]);
            init = 0)
    end

    ### Variables ###

    ## Integer Unit Commitment configuration for variables

    ## Decision variables for operational reserves
    @variable(EP, vREG[y in REG, t = 1:T]>=0) # Contribution to regulation (primary reserves), assumed to be symmetric (up & down directions equal)
    @variable(EP, vRSV[y in RSV, t = 1:T]>=0) # Contribution to operating reserves (secondary reserves or contingency reserves); only model upward reserve requirements

    # Storage techs have two pairs of auxilary variables to reflect contributions to regulation and reserves
    # when charging and discharging (primary variable becomes equal to sum of these auxilary variables)
    @variable(EP, vREG_discharge[y in intersect(STOR_ALL, REG), t = 1:T]>=0) # Contribution to regulation (primary reserves) (mirrored variable used for storage devices)
    @variable(EP, vRSV_discharge[y in intersect(STOR_ALL, RSV), t = 1:T]>=0) # Contribution to operating reserves (secondary reserves) (mirrored variable used for storage devices)
    @variable(EP, vREG_charge[y in intersect(STOR_ALL, REG), t = 1:T]>=0) # Contribution to regulation (primary reserves) (mirrored variable used for storage devices)
    @variable(EP, vRSV_charge[y in intersect(STOR_ALL, RSV), t = 1:T]>=0) # Contribution to operating reserves (secondary reserves) (mirrored variable used for storage devices)

    @variable(EP, vUNMET_RSV[t = 1:T]>=0) # Unmet operating reserves penalty/cost

    ### Expressions ###
    ## Total system reserve expressions
    # Regulation requirements as a percentage of demand and scheduled variable renewable energy production in each hour
    # Reg up and down requirements are symmetric
    @expression(EP,
        eRegReq[t = 1:T],
        inputs["pReg_Req_Demand"] *
        systemwide_hourly_demand[t]+
        inputs["pReg_Req_VRE"] * must_run_vre_generation(t))
    # Operating reserve up / contingency reserve requirements as ˚a percentage of demand and scheduled variable renewable energy production in each hour
    # and the largest single contingency (generator or transmission line outage)
    @expression(EP,
        eRsvReq[t = 1:T],
        inputs["pRsv_Req_Demand"] *
        systemwide_hourly_demand[t]+
        inputs["pRsv_Req_VRE"] * must_run_vre_generation(t))

    # N-1 contingency requirement is considered only if Unit Commitment is being modeled
    if UCommit >= 1 &&
       (inputs["pDynamic_Contingency"] >= 1 || inputs["pStatic_Contingency"] > 0)
        add_similar_to_expression!(EP[:eRsvReq], EP[:eContingencyReq])
    end

    ## Objective Function Expressions ##

    # Penalty for unmet operating reserves
    @expression(EP,
        eCRsvPen[t = 1:T],
        inputs["omega"][t]*inputs["pC_Rsv_Penalty"]*vUNMET_RSV[t])
    @expression(EP,
        eTotalCRsvPen,
        sum(eCRsvPen[t] for t in 1:T)+
        sum(reg_cost(gen[y]) * vRSV[y, t] for y in RSV, t in 1:T)+
        sum(rsv_cost(gen[y]) * vREG[y, t] for y in REG, t in 1:T))
    add_to_expression!(EP[:eObj], eTotalCRsvPen)
end

function operational_reserves_constraints!(EP, inputs)
    T = inputs["T"]     # Number of time steps (hours)

    REG = inputs["REG"]
    RSV = inputs["RSV"]
    vREG = EP[:vREG]
    vRSV = EP[:vRSV]
    vUNMET_RSV = EP[:vUNMET_RSV]
    eRegulationRequirement = EP[:eRegReq]
    eReserveRequirement = EP[:eRsvReq]

    ## Total system reserve constraints
    # Regulation requirements as a percentage of demand and scheduled
    # variable renewable energy production in each hour.
    # Note: frequency regulation up and down requirements are symmetric and all resources
    # contributing to regulation are assumed to contribute equal capacity to both up
    # and down directions
    if !isempty(REG)
        @constraint(EP,
            cReg[t = 1:T],
            sum(vREG[y, t] for y in REG)>=eRegulationRequirement[t])
    end
    if !isempty(RSV)
        @constraint(EP,
            cRsvReq[t = 1:T],
            sum(vRSV[y, t] for y in RSV) + vUNMET_RSV[t]>=eReserveRequirement[t])
    end
end
