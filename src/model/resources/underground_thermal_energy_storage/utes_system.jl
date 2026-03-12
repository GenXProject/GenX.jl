function utes_system!(EP::Model, inputs::Dict, setup::Dict)
    # Setup variables, constraints, and expressions common to all storage resources
    println("Underground Thermal Energy Storage Module")
    MultiStage = setup["MultiStage"]
    gen = inputs["RESOURCES"]
    CapacityReserveMargin = setup["CapacityReserveMargin"] > 0
    HourlyMatching = setup["HourlyMatching"]

    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones

    UTES = inputs["UTES"]     # Number of UTES resources
    NEW_CAP_UTES = intersect(inputs["NEW_CAP"], UTES)
    RET_CAP_UTES = intersect(inputs["RET_CAP"], UTES)
    pAmbientTemp = inputs["pAmbientTemp"]     # Ambient temprature in C

    # UTES components
     # by default, i = 1 -> dry cooler; i = 2 -> chiller; i = 3 -> pump in the tertiary loop; i = 4 -> thermal storage; 
     dry_cooler, chiller, pump, storage = 1, 2, 3, 4
    
    # get component-wise parameter data
    utes_dict = inputs["utes_dict"]

    # Variables
    # retired capacity of UTES 
    @variable(EP, vRETCAP_UTES[y in UTES, i = 1:3]  >= 0)
    # new capacity of UTES
    @variable(EP, vCAP_UTES[y in UTES, i = 1:3]  >= 0)

    if MultiStage == 1
        @variable(EP, vEXISTING_UTES[y in UTES, i = 1:3]>=0)
    end

    # Expressions and constraints related to UTES costs
    # capacity expressions
    @expression(EP, eExistingCap_UTES[y in UTES, i = 1:3], utes_dict[y, "existing_cap"][i])

    # Note: UTES is not compatiable with RETRO for now.
    @expression(EP, eTotalCap_UTES[y in UTES, i in 1:3],
    if y in intersect(NEW_CAP_UTES, RET_CAP_UTES) # Resources eligible for new capacity and retirements 
        eExistingCap_UTES[y, i] + EP[:vCAP_UTES][y, i] - EP[:vRETCAP_UTES][y,i]

    elseif y in setdiff(RET_CAP_UTES, NEW_CAP_UTES) # Resources eligible for only capacity retirement
        eExistingCap_UTES[y,i] - EP[:vRETCAP_UTES][y,i]
    elseif y in setdiff(NEW_CAP_UTES, RET_CAP_UTES) # Resources eligible for new capacity
        eExistingCap_UTES[y,i] + EP[:vCAP_UTES][y,i] 
    else # Resources not eligible for new capacity or retirement
        eExistingCap_UTES[y,i]
    end)

     # maximum capacity constraints
     for y in UTES, i in 1:3
        maxcap = utes_dict[y, "max_cap"][i]
        mincap = utes_dict[y, "min_cap"][i]
        if maxcap >= 0
            @constraint(EP, eTotalCap_UTES[y, i] <= maxcap)
        end
        if mincap >= 0
            @constraint(EP, eTotalCap_UTES[y, i] >= mincap)
        end
    end

    # investment costs expressions
    @expression(EP, eCFix_UTES[y in UTES, i in 1:3],
    if y in NEW_CAP_UTES # Resources eligible for new capacity
        utes_dict[y,"inv_cost"][i] * EP[:vCAP_UTES][y, i]+
        utes_dict[y,"fom_cost"][i] * eTotalCap_UTES[y,i]
    else
        utes_dict[y,"fom_cost"][i]  * eTotalCap_UTES[y,i]
    end)

    # connect eCFix_UTES_System to eCFix
    @expression(EP, eCFix_UTES_System[y in UTES], sum(EP[:eCFix_UTES][y,i] for i in 1:3))
    @expression(EP, eTotalCFix_UTES, sum(EP[:eCFix_UTES_System][y] for y in UTES))
    # add this to eTotalCFix
    add_to_expression!(EP[:eTotalCFix], eTotalCFix_UTES)
    # add to Obj
    add_to_expression!(EP[:eObj], eTotalCFix_UTES)

    # no other variable costs for UTES
    # Remove vP (UTES does not produce power so vP = 0 for all periods)
    @constraints(EP, begin
        [y in UTES, t in 1:T], EP[:vP][y, t] == 0
    end)

    # energy consumption from data center computers (include here or in demand_data.csv?)
    @expression(EP, ePowerBalance_Computing[t in 1:T, z in 1:Z],
        inputs["pD_Computing"][t,z])
    # add to the power balance
    EP[:ePowerBalance] -= ePowerBalance_Computing

    # detailed operational constraints for UTES components
    # determine cooling mode based on COP comparison (endogenous calculation)
    COP_DC = inputs["COP_DC"]
    COP_Chiller = inputs["COP_Chiller"]
    cooling_mode = Dict(
        (y, t) => (
            use_chiller = COP_Chiller[y][t] > COP_DC[y][t],
            use_dry_cooler = COP_DC[y][t] >= COP_Chiller[y][t]
        )
        for y in UTES, t in 1:T
    )

    # Enforce coordinated temperature behavior depending on cooling mode
    enforce_cooling_logic!(EP, gen, inputs, cooling_mode)

    # Dry cooler
    dry_cooler!(EP, inputs, setup)
    # Chiller
    chiller!(EP, inputs, setup)
    # Thermal storage
    if setup["withUTES"] == 1
        rtes!(EP, inputs, setup)
    elseif setup["withUTES"] == 2
        ates!(EP, inputs, setup)
    end

    if MultiStage == 1
        @constraint(EP,
            cExistingCap_UTES[y in UTES, i in 1:3],
            EP[:vEXISTING_UTES][y, i] == utes_dict[y, "existing_cap"][i])
    end
end

function enforce_cooling_logic!(EP, gen, inputs, cooling_mode)
    gen = inputs["RESOURCES"]
    T = inputs["T"]     # Number of time steps (hours)
    UTES = inputs["UTES"]     # Number of UTES resources
    pAmbientTemp = inputs["pAmbientTemp"]     # Ambient temprature in C
    # variables 
    @variable(EP, vTemp_Chiller[y in UTES, t=1:T])   # Output temperature of working fluid from chillers (unit: C)
    @variable(EP, vTemp_DC[y in UTES, t=1:T])   # Output temperature of working fluid from dry coolers (unit: C)

    for y in UTES, t in 1:T
        mode = cooling_mode[(y, t)]
    
        if mode.use_chiller
            @constraint(EP, vTemp_DC[y,t] >= vTemp_Chiller[y,t])
        else
            @constraint(EP, vTemp_Chiller[y,t] == vTemp_DC[y,t])
        end
    
        if mode.use_dry_cooler
            @constraint(EP, vTemp_DC[y,t] >= pAmbientTemp[gen[y].zone, t] + gen[y].approach_temp_dry_cooler)
            # @constraint(EP, vTemp_DC[y,t] ==21)
        # elseif !mode.use_chiller
        else
            # If neither is active, fix vTemp_DC
            @constraint(EP, vTemp_DC[y,t] == gen[y].temp_data_center_out_c)
        end
    end
end