@doc raw"""
	generate_model(setup::Dict,inputs::Dict,OPTIMIZER::MOI.OptimizerWithAttributes,modeloutput = nothing)

This function sets up and solves a constrained optimization model of electricity system capacity expansion and operation problem and extracts solution variables for later processing.

In addition to calling a number of other modules to create constraints for specific resources, policies, and transmission assets, this function initializes two key expressions that are successively expanded in each of the resource-specific modules: (1) the objective function; and (2) the zonal power balance expression. These two expressions are the only expressions which link together individual modules (e.g. resources, transmission assets, policies), which otherwise are self-contained in defining relevant variables, expressions, and constraints.

**Objective Function**

The objective function of GenX minimizes total annual electricity system costs over the following six components shown in the equation below:

```math
\begin{aligned}
	&\sum_{y \in \mathcal{G} } \sum_{z \in \mathcal{Z}}
	\left( (\pi^{INVEST}_{y,z} \times \overline{\Omega}^{size}_{y,z} \times  \Omega_{y,z})
	+ (\pi^{FOM}_{y,z} \times \overline{\Omega}^{size}_{y,z} \times  \Delta^{total}_{y,z})\right) + \notag \\
	&\sum_{y \in \mathcal{O} } \sum_{z \in \mathcal{Z}}
	\left( (\pi^{INVEST,energy}_{y,z} \times    \Omega^{energy}_{y,z})
	+ (\pi^{FOM,energy}_{y,z} \times  \Delta^{total,energy}_{y,z})\right) + \notag \\
	&\sum_{y \in \mathcal{O}^{asym} } \sum_{z \in \mathcal{Z}}
	\left( (\pi^{INVEST,charge}_{y,z} \times    \Omega^{charge}_{y,z})
	+ (\pi^{FOM,charge}_{y,z} \times  \Delta^{total,charge}_{y,z})\right) + \notag \\
	& \sum_{y \in \mathcal{G} } \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}} \left( \omega_{t}\times(\pi^{VOM}_{y,z} + \pi^{FUEL}_{y,z})\times \Theta_{y,z,t}\right) + \sum_{y \in \mathcal{O \cup DF} } \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}} \left( \omega_{t}\times\pi^{VOM,charge}_{y,z} \times \Pi_{y,z,t}\right) +\notag \\
	&\sum_{s \in \mathcal{S} } \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}}\left(\omega_{t} \times n_{s}^{slope} \times \Lambda_{s,z,t}\right) + \sum_{t \in \mathcal{T} } \left(\omega_{t} \times \pi^{unmet}_{rsv} \times r^{unmet}_{t}\right) \notag \\
	&\sum_{y \in \mathcal{H} } \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}}\left(\omega_{t} \times \pi^{START}_{y,z} \times \chi_{s,z,t}\right) + \notag \\
	& \sum_{l \in \mathcal{L}}\left(\pi^{TCAP}_{l} \times \bigtriangleup\varphi^{max}_{l}\right)
\end{aligned}
```

The first summation represents the fixed costs of generation/discharge over all zones and technologies, which refects the sum of the annualized capital cost, $\pi^{INVEST}_{y,z}$, times the total new capacity added (if any),  plus the Fixed O&M cost, $\pi^{FOM}_{y,z}$, times the net installed generation capacity, $\overline{\Omega}^{size}_{y,z} \times \Delta^{total}_{y,z}$ (e.g., existing capacity less retirements plus additions).

The second summation corresponds to the fixed cost of installed energy storage capacity and is summed over only the storage resources. This term includes the sum of the annualized energy capital cost, $\pi^{INVEST,energy}_{y,z}$, times the total new energy capacity added (if any), plus the Fixed O&M cost, $\pi^{FOM, energy}_{y,z}$, times the net installed energy storage capacity, $\Delta^{total,energy}_{y,z}$ (e.g., existing capacity less retirements plus additions).

The third summation corresponds to the fixed cost of installed charging power capacity and is summed over only over storage resources with independent/asymmetric charge and discharge power components ($\mathcal{O}^{asym}$). This term includes the sum of the annualized charging power capital cost, $\pi^{INVEST,charge}_{y,z}$, times the total new charging power capacity added (if any), plus the Fixed O&M cost, $\pi^{FOM, energy}_{y,z}$, times the net installed charging power capacity, $\Delta^{total,charge}_{y,z}$ (e.g., existing capacity less retirements plus additions).

The fourth and fifth summations corresponds to the operational cost across all zones, technologies, and time steps. The fourth summation represents the sum of fuel cost, $\pi^{FUEL}_{y,z}$ (if any), plus variable O&M cost, $\pi^{VOM}_{y,z}$ times the energy generation/discharge by generation or storage resources (or demand satisfied via flexible demand resources, $y\in\mathcal{DF}$) in time step $t$, $\Theta_{y,z,t}$, and the weight of each time step $t$, $\omega_t$, where $\omega_t$ is equal to 1 when modeling grid operations over the entire year (8760 hours), but otherwise is equal to the number of hours in the year represented by the representative time step, $t$ such that the sum of $\omega_t \forall t \in T = 8760$, approximating annual operating costs. The fifth summation represents the variable charging O&M cost, $\pi^{VOM,charge}_{y,z}$ times the energy withdrawn for charging by storage resources (or demand deferred by flexible demand resources) in time step $t$ , $\Pi_{y,z,t}$ and the annual weight of time step $t$,$\omega_t$.

The sixth summation represents the total cost of unserved demand across all segments $s$ of a segment-wise price-elastic demand curve, equal to the marginal value of consumption (or cost of non-served energy), $n_{s}^{slope}$, times the
amount of non-served energy, $\Lambda_{y,z,t}$, for each segment on each zone during each time step (weighted by $\omega_t$).

The seventh summation represents the total cost of not meeting hourly operating reserve requirements, where $\pi^{unmet}_{rsv}$ is the cost penalty per unit of non-served reserve requirement, and $r^{unmet}_t$ is the amount of non-served reserve requirement in each time step (weighted by $\omega_t$).

The eighth summation corresponds to the startup costs incurred by technologies to which unit commitment decisions apply (e.g. $y \in \mathcal{UC}$), equal to the cost of start-up, $\pi^{START}_{y,z}$, times the number of startup events, $\chi_{y,z,t}$, for the cluster of units in each zone and time step (weighted by $\omega_t$).

The last term corresponds to the transmission reinforcement or construction costs, for each transmission line in the model. Transmission reinforcement costs are equal to the sum across all lines of the product between the transmission reinforcement/construction cost, $\pi^{TCAP}_{l}$, times the additional transmission capacity variable, $\bigtriangleup\varphi^{max}_{l}$. Note that fixed O\&M and replacement capital costs (depreciation) for existing transmission capacity is treated as a sunk cost and not included explicitly in the GenX objective function.

In summary, the objective function can be understood as the minimization of costs associated with five sets of different decisions: (1) where and how to invest on capacity, (2) how to dispatch or operate that capacity, (3) which consumer demand segments to serve or curtail, (4) how to cycle and commit thermal units subject to unit commitment decisions, (5) and where and how to invest in additional transmission network capacity to increase power transfer capacity between zones. Note however that each of these components are considered jointly and the optimization is performed over the whole problem at once as a monolithic co-optimization problem.

**Power Balance**

The power balance constraint of the model ensures that electricity demand is met at every time step in each zone. As shown in the constraint, electricity demand, $D_{t,z}$, at each time step and for each zone must be strictly equal to the sum of generation, $\Theta_{y,z,t}$, from thermal technologies ($\mathcal{H}$), curtailable VRE ($\mathcal{VRE}$), must-run resources ($\mathcal{MR}$), and hydro resources ($\mathcal{W}$). At the same time, energy storage devices ($\mathcal{O}$) can discharge energy, $\Theta_{y,z,t}$ to help satisfy demand, while when these devices are charging, $\Pi_{y,z,t}$, they increase demand. For the case of flexible demand resources ($\mathcal{DF}$), delaying demand (equivalent to charging virtual storage), $\Pi_{y,z,t}$, decreases demand while satisfying delayed demand (equivalent to discharging virtual demand), $\Theta_{y,z,t}$, increases demand. Price-responsive demand curtailment, $\Lambda_{s,z,t}$, also reduces demand. Finally, power flows, $\Phi_{l,t}$, on each line $l$ into or out of a zone (defined by the network map $\varphi^{map}_{l,z}$), are considered in the demand balance equation for each zone. By definition, power flows leaving their reference zone are positive, thus the minus sign in the below constraint. At the same time losses due to power flows increase demand, and one-half of losses across a line linking two zones are attributed to each connected zone. The losses function $\beta_{l,t}(\cdot)$ will depend on the configuration used to model losses (see Transmission section).

```math
\begin{aligned}
	& \sum_{y\in \mathcal{H}}{\Theta_{y,z,t}} +\sum_{y\in \mathcal{VRE}}{\Theta_{y,z,t}} +\sum_{y\in \mathcal{MR}}{\Theta_{y,z,t}} + \sum_{y\in \mathcal{O}}{(\Theta_{y,z,t}-\Pi_{y,z,t})} + \notag\\
	& \sum_{y\in \mathcal{DF}}{(-\Theta_{y,z,t}+\Pi_{y,z,t})} +\sum_{y\in \mathcal{W}}{\Theta_{y,z,t}}+ \notag\\
	&+ \sum_{s\in \mathcal{S}}{\Lambda_{s,z,t}}  - \sum_{l\in \mathcal{L}}{(\varphi^{map}_{l,z} \times \Phi_{l,t})} -\frac{1}{2} \sum_{l\in \mathcal{L}}{(\varphi^{map}_{l,z} \times \beta_{l,t}(\cdot))} = D_{z,t}
	\forall z\in \mathcal{Z},  t \in \mathcal{T}
\end{aligned}
```

# Arguments
- `setup::Dict`: Dictionary containing the settings for the model.
- `inputs::Dict`: Dictionary containing the inputs for the model.
- `OPTIMIZER::MOI.OptimizerWithAttributes`: The optimizer to use for solving the model.

# Returns
- `Model`: The model object containing the entire optimization problem model to be solved by solve_model.jl
"""
function generate_model(setup::Dict, inputs::Dict, OPTIMIZER::MOI.OptimizerWithAttributes)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones

    ## Start pre-solve timer
    presolver_start_time = time()

    # Generate Energy Portfolio (EP) Model
    EP = if Bool(setup["EnableJuMPDirectModel"])
        opt_instance = MOI.instantiate(OPTIMIZER)
        direct_model(opt_instance)
    else
        Model(OPTIMIZER)
    end
    #set_string_names_on_creation(EP, Bool(setup["EnableJuMPStringNames"]))

    # Initialize Objective Function Expression
    EP[:eObj] = AffExpr(0.0)

    #NEW: Guard against unsupported Benders + VRE-STOR combination
    if setup["Benders"] == 1 
        if setup["LDSAdditionalConstraints"] == 1
            @warn "LDSAdditionalConstraints=1 applies to problems with non-representative periods and is not supported in the current Benders implementation. Benders will proceed as if LDSAdditionalConstraints=0"
        end
    end
    #NEW: Delegate to planning_model! and operation_model! helper functions.
    # planning_model! handles all investment/capacity decisions and must run first
    # so that investment variables exist when operation_model! references them.
    planning_model!(EP, setup, inputs)
    operation_model!(EP, setup, inputs)

    if setup["ModelingToGenerateAlternatives"] == 1
        mga!(EP, inputs, setup)
    end

    ## Define the objective function
    @objective(EP, Min, setup["ObjScale"]*EP[:eObj])

    ## Record pre-solver time
    presolver_time = time() - presolver_start_time
    if setup["PrintModel"] == 1
        filepath = joinpath(pwd(), "YourModel.lp")
        JuMP.write_to_file(EP, filepath)
        println("Model Printed")
    end

    return EP
end

#NEW: planning_model! contains all investment/capacity decisions. These are separated
# from operational decisions to support Benders decomposition, where investment
# (first-stage) variables must be fixed before solving operational (second-stage) subproblems.
# For non-Benders runs (setup["Benders"]==0) this produces an identical model to the
# original monolithic generate_model, just with investment calls grouped here.
function planning_model!(EP::Model, setup::Dict, inputs::Dict)

    if setup["MinCapReq"] == 1
        create_empty_expression!(EP, :eMinCapRes, inputs["NumberOfMinCapReqs"])
    end

    if setup["MaxCapReq"] == 1
        create_empty_expression!(EP, :eMaxCapRes, inputs["NumberOfMaxCapReqs"])
    end

    # Infrastructure
    investment_discharge!(EP, inputs, setup)

    if inputs["Z"] > 1
        investment_transmission!(EP, inputs, setup)
    end

    if !isempty(inputs["STOR_ALL"])
        investment_storage!(EP, inputs, setup)
    end

    # Model constraints, variables, expression related to retrofit technologies
    if !isempty(inputs["RETROFIT_OPTIONS"])
        EP = retrofit(EP, inputs)
    end

    #NEW: Benders-only long-duration storage planning constraints (cross-period state-of-charge)
    if setup["Benders"] == 1 && inputs["REP_PERIOD"] > 1 && !isempty(inputs["STOR_LONG_DURATION"])
        long_duration_storage_planning!(EP, inputs, setup)
    end

    #NEW: Benders-only hydro inter-period linkage planning constraints
    if setup["Benders"] == 1 && inputs["REP_PERIOD"] > 1 && !isempty(inputs["STOR_HYDRO_LONG_DURATION"])
        hydro_inter_period_linkage_planning!(EP, inputs)
    end

    # Policies

    if setup["MultiStage"] > 0
        # Endogenous Retirements
        endogenous_retirement!(EP, inputs, setup)
    end

    if setup["MinCapReq"] == 1
        minimum_capacity_requirement!(EP, inputs, setup)
    end

    if setup["MaxCapReq"] == 1
        maximum_capacity_requirement!(EP, inputs, setup)
    end

    #NEW: Benders-only planning-phase CO2 cap constraints (annual budget on investment)
    if setup["CO2Cap"] > 0 && setup["Benders"] == 1
        co2_cap_planning!(EP, inputs, setup)
    end

    #NEW: Benders-only planning-phase energy share requirement constraints
    if setup["EnergyShareRequirement"] >= 1 && setup["Benders"] == 1
        energy_share_requirement_planning!(EP, inputs, setup)
    end

    if setup["HydrogenMinimumProduction"] > 0 && setup["Benders"] == 1
        hydrogen_demand_planning!(EP, inputs, setup)
    end
end

#NEW: operation_model! contains all operational constraints, variables, and technology modules.
# For non-Benders runs (setup["Benders"]==0) this produces an identical model to the
# original monolithic generate_model. For Benders runs it uses subperiod-specific variants
# of certain constraints to allow decomposition across representative periods.
function operation_model!(EP::Model, setup::Dict, inputs::Dict)

    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones

    # Initialize Power Balance Expression
    # Expression for "baseline" power balance constraint
    create_empty_expression!(EP, :ePowerBalance, (T, Z))

    create_empty_expression!(EP, :eGenerationByZone, (Z, T))

    # Energy losses related to technologies
    create_empty_expression!(EP, :eELOSSByZone, Z)

    # Initialize Capacity Reserve Margin Expression
    if setup["CapacityReserveMargin"] > 0
        create_empty_expression!(EP,
            :eCapResMarBalance,
            (inputs["NCapacityReserveMargin"], T))
    end

    # Energy Share Requirement
    if setup["EnergyShareRequirement"] >= 1
        create_empty_expression!(EP, :eESR, inputs["nESR"])
    end

    # Hourly Matching Requirement
    if setup["HourlyMatchingRequirement"] == 1
        create_empty_expression!(EP, :eHM, (T, inputs["nHM"]))
    end

    if setup["HydrogenMinimumProduction"] > 0
        create_empty_expression!(EP, :eH2DemandRes, inputs["NumberOfH2DemandReqs"])
    end

    # Infrastructure

    #NEW: capacity_decisions! creates capacity variables needed by Benders subproblems.
    # The haskey guard prevents double-registration when planning_model! already set up
    # eTotalCap (e.g. via investment_discharge!).
    if setup["Benders"] == 1
        capacity_decisions!(EP, inputs, setup)
    end

    discharge!(EP, inputs, setup)

    non_served_energy!(EP, inputs, setup)

    if setup["UCommit"] > 0
        ucommit!(EP, inputs, setup)
    end

    fuel!(EP, inputs, setup)

    co2!(EP, inputs)

    if setup["OperationalReserves"] > 0
        operational_reserves!(EP, inputs, setup)
    end

    if Z > 1
        transmission!(EP, inputs, setup)
    end

    if Z > 1 && setup["DC_OPF"] != 0
        dcopf_transmission!(EP, inputs, setup)
    end

    #NEW: lds_slack! adds slack variables used by Benders to relax long-duration storage
    # inter-period linkage constraints within each subproblem.
    if (setup["Benders"] == 1 && (!isempty(inputs["STOR_LONG_DURATION"]) || !isempty(inputs["STOR_HYDRO_LONG_DURATION"]))) ||
       (inputs["REP_PERIOD"] > 1 && (!isempty(inputs["STOR_LONG_DURATION"]) || !isempty(inputs["STOR_HYDRO_LONG_DURATION"])))
        lds_slack!(EP, inputs, setup)
    end

    # Technologies
    # Model constraints, variables, expression related to dispatchable renewable resources
    if !isempty(inputs["VRE"])
        curtailable_variable_renewable!(EP, inputs, setup)
    end

    # Model constraints, variables, expression related to non-dispatchable renewable resources
    if !isempty(inputs["MUST_RUN"])
        must_run!(EP, inputs, setup)
    end

    # Model constraints, variables, expression related to energy storage modeling
    if !isempty(inputs["STOR_ALL"])
        storage!(EP, inputs, setup)
        if setup["Benders"] == 1
            if !isempty(inputs["STOR_LONG_DURATION"])
                long_duration_storage_subperiod!(EP, inputs, setup)
            end
        else
            # Include Long Duration Storage only when modeling representative periods and long-duration storage
            if inputs["REP_PERIOD"] > 1 && !isempty(inputs["STOR_LONG_DURATION"])
                long_duration_storage!(EP, inputs, setup)
            end
        end
    end

    # Model constraints, variables, expression related to reservoir hydropower resources
    if !isempty(inputs["HYDRO_RES"])
        hydro_res!(EP, inputs, setup)
    end

    # Allam Cycle LOX
    if !isempty(inputs["ALLAM_CYCLE_LOX"])
        allamcyclelox!(EP, inputs, setup)
    end

    # Model constraints, variables, expression related to reservoir hydropower resources with long duration storage
    if setup["Benders"] == 1 && !isempty(inputs["STOR_HYDRO_LONG_DURATION"])
        #NEW: Benders uses subperiod variant of hydro inter-period linkage
        hydro_inter_period_linkage_subperiod!(EP, inputs)
    elseif inputs["REP_PERIOD"] > 1 && !isempty(inputs["STOR_HYDRO_LONG_DURATION"])
        hydro_inter_period_linkage!(EP, inputs, setup)
    end

    # Model constraints, variables, expression related to demand flexibility resources
    if !isempty(inputs["FLEX"])
        flexible_demand!(EP, inputs, setup)
    end

    # Model constraints, variables, expression related to thermal resource technologies
    if !isempty(inputs["THERM_ALL"])
        thermal!(EP, inputs, setup)
    end

    # Model constraints, variables, expression related to retrofit technologies
    # (non-Benders only; Benders errors in planning_model! if RETROFIT_OPTIONS non-empty)
    # Already called in planning_model! for non-Benders, so skipped here.

    # Model constraints, variables, expressions related to the co-located VRE-storage resources
    # (Benders case with VRE_STOR already errored at generate_model entry point)
    if !isempty(inputs["VRE_STOR"])
        vre_stor!(EP, inputs, setup)
    end

    # Model constraints, variables, expressions related to electrolyzers.
    # Also active for VRE-STOR cases that embed an electrolyzer (VS_ELEC).
    if !isempty(inputs["ELECTROLYZER"]) ||
       (!isempty(inputs["VRE_STOR"]) && !isempty(inputs["VS_ELEC"]))
        electrolyzer!(EP, inputs, setup)
    end

    # Policies

    if setup["OperationalReserves"] > 0
        operational_reserves_constraints!(EP, inputs)
    end

    # CO2 emissions limits
    if setup["CO2Cap"] > 0
        if setup["Benders"] == 1
            #NEW: Benders uses subperiod-scaled CO2 cap for each operational subproblem
            co2_cap_subperiod!(EP, inputs, setup)
        else
            co2_cap!(EP, inputs, setup)
        end
    end

    # Energy Share Requirement
    if setup["EnergyShareRequirement"] >= 1
        if setup["Benders"] == 1
            #NEW: Benders uses subperiod-scaled ESR for each operational subproblem
            energy_share_requirement_subperiod!(EP, inputs, setup)
        else
            energy_share_requirement!(EP, inputs, setup)
        end
    end

    # Hourly Matching Requirement
    if setup["HourlyMatchingRequirement"] == 1
        hourly_matching!(EP, inputs) #TODO: Handle this with Benders too
    end

    # Capacity Reserve Margin
    if setup["CapacityReserveMargin"] > 0
        cap_reserve_margin!(EP, inputs, setup)
    end

    # Hydrogen demand limits
    if setup["HydrogenMinimumProduction"] > 0
        if setup["Benders"] == 1
            hydrogen_demand_subperiod!(EP, inputs, setup)
        else
            hydrogen_demand!(EP, inputs, setup)
        end
    end

    ## Power balance constraints
    # demand = generation + storage discharge - storage charge - demand deferral + deferred demand satisfaction - demand curtailment (NSE)
    #          + incoming power flows - outgoing power flows - flow losses - charge of heat storage + generation from NACC

    # @variable(EP, overproduction[t = 1:T, z = 1:Z] >= 0)
    # add_to_expression!(EP[:eObj], 1e8 * sum(overproduction))
    # @constraint(EP,
    #     cPowerBalance[t = 1:T, z = 1:Z],
        # EP[:ePowerBalance][t, z] + overproduction[t, z]==inputs["pD"][t, z])
    @constraint(EP,
        cPowerBalance[t = 1:T, z = 1:Z],
        EP[:ePowerBalance][t, z]==inputs["pD"][t, z])
end



function generate_model_legacy(setup::Dict, inputs::Dict, OPTIMIZER::MOI.OptimizerWithAttributes)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones

    ## Start pre-solve timer
    presolver_start_time = time()

    # Generate Energy Portfolio (EP) Model
    EP = if Bool(setup["EnableJuMPDirectModel"])
        opt_instance = MOI.instantiate(OPTIMIZER)
        direct_model(opt_instance)
    else
        Model(OPTIMIZER)
    end
    set_string_names_on_creation(EP, Bool(setup["EnableJuMPStringNames"]))

    # Initialize Objective Function Expression
    EP[:eObj] = AffExpr(0.0)

    # Delegate to planning_model! and operation_model! helper functions.
    # planning_model! handles all investment/capacity decisions and must run first
    # so that investment variables exist when operation_model! references them.
    planning_model!(EP, setup, inputs)
    operation_model!(EP, setup, inputs)

    if setup["ModelingToGenerateAlternatives"] == 1
        mga!(EP, inputs, setup)
    end

    ## Define the objective function
    @objective(EP, Min, setup["ObjScale"]*EP[:eObj])

    ## Record pre-solver time
    presolver_time = time() - presolver_start_time
    if setup["PrintModel"] == 1
        filepath = joinpath(pwd(), "YourModel.lp")
        JuMP.write_to_file(EP, filepath)
        println("Model Printed")
    end

    return EP
end

# planning_model! contains all investment/capacity decisions. These are separated
# from operational decisions to support Benders decomposition, where investment
# (first-stage) variables must be fixed before solving operational (second-stage) subproblems.
# For non-Benders runs (setup["Benders"]==0) this produces an identical model to the
# original monolithic generate_model, just with investment calls grouped here.
function planning_model!(EP::Model, setup::Dict, inputs::Dict)

    if setup["MinCapReq"] == 1
        create_empty_expression!(EP, :eMinCapRes, inputs["NumberOfMinCapReqs"])
    end

    if setup["MaxCapReq"] == 1
        create_empty_expression!(EP, :eMaxCapRes, inputs["NumberOfMaxCapReqs"])
    end

    # Infrastructure
    investment_discharge!(EP, inputs, setup)

    if inputs["Z"] > 1
        investment_transmission!(EP, inputs, setup)
    end

    if !isempty(inputs["STOR_ALL"])
        investment_storage!(EP, inputs, setup)
    end

    if !isempty(inputs["VRE_STOR"])
        investment_discharge_vre_stor!(EP, inputs, setup)
    end

    # Model constraints, variables, expression related to retrofit technologies
    if !isempty(inputs["RETROFIT_OPTIONS"])
        EP = retrofit(EP, inputs)
    end

    # Benders-only long-duration storage planning constraints (cross-period state-of-charge)
    if setup["Benders"] == 1 && haskey(inputs, "SubPeriod_Index") && !isempty(inputs["STOR_LONG_DURATION"])
        long_duration_storage_planning!(EP, inputs, setup)
    end

    # Benders-only hydro inter-period linkage planning constraints
    if setup["Benders"] == 1 && haskey(inputs, "SubPeriod_Index") && !isempty(inputs["STOR_HYDRO_LONG_DURATION"])
        hydro_inter_period_linkage_planning!(EP, inputs)
    end

    # Policies

    if setup["MultiStage"] > 0
        # Endogenous Retirements
        endogenous_retirement!(EP, inputs, setup)
    end

    if setup["MinCapReq"] == 1
        minimum_capacity_requirement!(EP, inputs, setup)
    end

    if setup["MaxCapReq"] == 1
        maximum_capacity_requirement!(EP, inputs, setup)
    end

    # Benders-only planning-phase CO2 cap constraints (annual budget on investment)
    if setup["CO2Cap"] > 0 && setup["Benders"] == 1
        co2_cap_planning!(EP, inputs, setup)
    end

    # Benders-only planning-phase energy share requirement constraints
    if setup["EnergyShareRequirement"] >= 1 && setup["Benders"] == 1
        energy_share_requirement_planning!(EP, inputs, setup)
    end

    if setup["HydrogenMinimumProduction"] > 0 && setup["Benders"] == 1
        hydrogen_demand_planning!(EP, inputs, setup)
    end

    if setup["HourlyMatchingRequirement"] == 1 && setup["Benders"] == 1
        hourly_matching_planning!(EP, inputs)
    end
end

# operation_model! contains all operational constraints, variables, and technology modules.
# For non-Benders runs (setup["Benders"]==0) this produces an identical model to the
# original monolithic generate_model. For Benders runs it uses subperiod-specific variants
# of certain constraints to allow decomposition across representative periods.
function operation_model!(EP::Model, setup::Dict, inputs::Dict)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones

    if setup["Benders"] == 1 
        if setup["LDSAdditionalConstraints"] == 1
            @warn "LDSAdditionalConstraints=1 applies to problems with non-representative periods and is not supported in the current Benders implementation. Benders will proceed as if LDSAdditionalConstraints=0"
        end
    end

    # Initialize Power Balance Expression
    # Expression for "baseline" power balance constraint
    create_empty_expression!(EP, :ePowerBalance, (T, Z))

    create_empty_expression!(EP, :eGenerationByZone, (Z, T))

    # Energy losses related to technologies
    create_empty_expression!(EP, :eELOSSByZone, Z)

    # Initialize Capacity Reserve Margin Expression
    if setup["CapacityReserveMargin"] > 0
        create_empty_expression!(EP,
            :eCapResMarBalance,
            (inputs["NCapacityReserveMargin"], T))
    end

    # Energy Share Requirement
    if setup["EnergyShareRequirement"] >= 1
        create_empty_expression!(EP, :eESR, inputs["nESR"])
    end

    # Hourly Matching Requirement
    if setup["HourlyMatchingRequirement"] == 1
        create_empty_expression!(EP, :eHM, (T, inputs["nHM"]))
    end

    if setup["HydrogenMinimumProduction"] > 0
        create_empty_expression!(EP, :eH2DemandRes, inputs["NumberOfH2DemandReqs"])
    end

    # Infrastructure

    # capacity_decisions! creates capacity variables needed by Benders subproblems.
    # The haskey guard prevents double-registration when planning_model! already set up
    # eTotalCap (e.g. via investment_discharge!).
    if setup["Benders"] == 1
        capacity_decisions!(EP, inputs, setup)
    end

    discharge!(EP, inputs, setup)

    non_served_energy!(EP, inputs, setup)

    if setup["UCommit"] > 0
        ucommit!(EP, inputs, setup)
    end

    fuel!(EP, inputs, setup)

    co2!(EP, inputs)

    if setup["OperationalReserves"] > 0
        operational_reserves!(EP, inputs, setup)
    end

    if Z > 1
        transmission!(EP, inputs, setup)
    end

    if Z > 1 && setup["DC_OPF"] != 0
        dcopf_transmission!(EP, inputs, setup)
    end

    # inter-period linkage constraints within each subproblem.
    if setup["LDES_Feasible"] == 0 && ((setup["Benders"] == 1 && (!isempty(inputs["STOR_LONG_DURATION"]) || !isempty(inputs["STOR_HYDRO_LONG_DURATION"]))) ||
       (inputs["REP_PERIOD"] > 1 && (!isempty(inputs["STOR_LONG_DURATION"]) || !isempty(inputs["STOR_HYDRO_LONG_DURATION"]))))
        lds_slack!(EP, inputs, setup)
    end

    # Technologies
    # Model constraints, variables, expression related to dispatchable renewable resources
    if !isempty(inputs["VRE"])
        curtailable_variable_renewable!(EP, inputs, setup)
    end

    # Model constraints, variables, expression related to non-dispatchable renewable resources
    if !isempty(inputs["MUST_RUN"])
        must_run!(EP, inputs, setup)
    end

    # Model constraints, variables, expression related to energy storage modeling
    if !isempty(inputs["STOR_ALL"])
        storage!(EP, inputs, setup)
        if setup["Benders"] == 1
            if !isempty(inputs["STOR_LONG_DURATION"])
                long_duration_storage_subperiod!(EP, inputs, setup)
            end
        else
            # Include Long Duration Storage only when modeling representative periods and long-duration storage
            if inputs["REP_PERIOD"] > 1 && !isempty(inputs["STOR_LONG_DURATION"])
                long_duration_storage!(EP, inputs, setup)
            end
        end
    end

    # Model constraints, variables, expression related to reservoir hydropower resources
    if !isempty(inputs["HYDRO_RES"])
        hydro_res!(EP, inputs, setup)
    end

    # Allam Cycle LOX
    if !isempty(inputs["ALLAM_CYCLE_LOX"])
        allamcyclelox!(EP, inputs, setup)
    end

    # Model constraints, variables, expression related to reservoir hydropower resources with long duration storage
    if setup["Benders"] == 1 && !isempty(inputs["STOR_HYDRO_LONG_DURATION"])
        # Benders uses subperiod variant of hydro inter-period linkage
        hydro_inter_period_linkage_subperiod!(EP, inputs)
    elseif inputs["REP_PERIOD"] > 1 && !isempty(inputs["STOR_HYDRO_LONG_DURATION"])
        hydro_inter_period_linkage!(EP, inputs, setup)
    end

    # Model constraints, variables, expression related to demand flexibility resources
    if !isempty(inputs["FLEX"])
        flexible_demand!(EP, inputs, setup)
    end

    # Model constraints, variables, expression related to thermal resource technologies
    if !isempty(inputs["THERM_ALL"])
        thermal!(EP, inputs, setup)
    end

    # Model constraints, variables, expressions related to the co-located VRE-storage resources
    if !isempty(inputs["VRE_STOR"])
        if setup["LDES_Feasible"] == 0 && ((setup["Benders"] == 1 && haskey(inputs, "SubPeriod_Index") && !isempty(inputs["VS_LDS"])) || ((inputs["REP_PERIOD"] > 1) && !isempty(inputs["VS_LDS"])))
            vre_stor_lds_slack!(EP, inputs, setup)
        end
        vre_stor!(EP, inputs, setup)
    end

    # Model constraints, variables, expressions related to electrolyzers.
    # Also active for VRE-STOR cases that embed an electrolyzer (VS_ELEC).
    if !isempty(inputs["ELECTROLYZER"]) || (!isempty(inputs["VRE_STOR"]) && !isempty(inputs["VS_ELEC"]))
        electrolyzer!(EP, inputs, setup)
    end

    # Policies

    if setup["OperationalReserves"] > 0
        operational_reserves_constraints!(EP, inputs)
    end

    # CO2 emissions limits
    if setup["CO2Cap"] > 0
        if setup["Benders"] == 1
            # Benders uses subperiod-scaled CO2 cap for each operational subproblem
            co2_cap_subperiod!(EP, inputs, setup)
        else
            co2_cap!(EP, inputs, setup)
        end
    end

    # Energy Share Requirement
    if setup["EnergyShareRequirement"] >= 1
        if setup["Benders"] == 1
            # Benders uses subperiod-scaled ESR for each operational subproblem
            energy_share_requirement_subperiod!(EP, inputs, setup)
        else
            energy_share_requirement!(EP, inputs, setup)
        end
    end

    # Hourly Matching Requirement
    if setup["HourlyMatchingRequirement"] == 1
        if setup["Benders"] == 1
            hourly_matching_subperiod!(EP, inputs)
        else
            hourly_matching!(EP, inputs)
        end
    end

    # Capacity Reserve Margin
    if setup["CapacityReserveMargin"] > 0
        cap_reserve_margin!(EP, inputs, setup)
    end

    # Hydrogen demand limits
    if setup["HydrogenMinimumProduction"] > 0
        if setup["Benders"] == 1
            hydrogen_demand_subperiod!(EP, inputs, setup)
        else
            hydrogen_demand!(EP, inputs, setup)
        end
    end

    ## Power balance constraints
    # demand = generation + storage discharge - storage charge - demand deferral + deferred demand satisfaction - demand curtailment (NSE)
    #          + incoming power flows - outgoing power flows - flow losses - charge of heat storage + generation from NACC
    @constraint(EP,
        cPowerBalance[t = 1:T, z = 1:Z],
        EP[:ePowerBalance][t, z]==inputs["pD"][t, z])
end
