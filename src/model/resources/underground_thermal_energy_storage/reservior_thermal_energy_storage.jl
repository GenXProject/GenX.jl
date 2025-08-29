function rtes!(EP::Model, inputs::Dict, setup::Dict)
    # Setup variables, constraints, and expressions common to all storage resources
    println("Underground Thermal Energy Storage (Reservior Thermal Energy Storage) Module")

    gen = inputs["RESOURCES"]
    CapacityReserveMargin = setup["CapacityReserveMargin"] > 0
    HourlyMatching = setup["HourlyMatching"]

    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    UTES = inputs["UTES"]     # Number of UTES resources
    STOR_UTES_SHORT_DURATION = inputs["STOR_UTES_SHORT_DURATION"]

    dD_computing = inputs["pD_Computing"]     # Computing demand in MW
    pAmbientTemp = inputs["pAmbientTemp"]     # Ambient temprature in C
    Q = dD_computing    # Thermal rejection from the data center is assumed to be equal to computing load
    # time related 
    p = inputs["hours_per_subperiod"]
    representative_periods = inputs["REP_PERIOD"]
    START_SUBPERIODS = inputs["START_SUBPERIODS"]
    INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]


    # UTES components
     # by default, i = 1 -> dry cooler; i = 2 -> chiller; i = 3 -> pump in the tertiary loop; i = 4 -> thermal storage; 
     dry_cooler, chiller, pump, storage = 1, 2, 3, 4

    # Variables
    # state of charge of the thermal storage (Unit: MWh)
    @variable(EP, vSOC_RTES[y in UTES, t = 1:T] >=0) 

    # mass flow in RTES (Unit: kg/s)
    @variable(EP, vMassFlow_RTES[y in UTES, t = 1:T]) # can be positive or negative, indicating flow directions 
    # absoluate value of the mass flow in RTES
    @variable(EP, vMassFlow_RTES_abs[y in UTES, t=1:T] >= 0)

    # constraints that only apply to short duration storage
    if representative_periods > 1 && !isempty(inputs["STOR_UTES_LONG_DURATION"])
        CONSTRAINTSET_UTES = STOR_UTES_SHORT_DURATION
    else
        CONSTRAINTSET_UTES = UTES
    end

    # The status of charge of the thermal storage is equal to the sum of the thermal mass and the energy input/output (Unit: MWh) 

    # during the start period, different for long and short-duration UTES
    @constraint(EP, cSOC_RTES_Start[y in CONSTRAINTSET_UTES, t in START_SUBPERIODS], 
        vSOC_RTES[y, t] == (1 - gen[y].self_disch) * vSOC_RTES[y, hoursbefore(p, t, 1)] + gen[y].thermal_capacity_second_loop * EP[:eMassFlow_Sec_Loop][y, t] * (- EP[:vTemp_Chiller][y, t] + EP[:eTemp_HX_12][y, t])) 
    
    # during the interior period, same for long and short-duration UTES
    @constraint(EP, cSOC_RTES_Interior[y in UTES, t in INTERIOR_SUBPERIODS], 
        vSOC_RTES[y, t] == (1 - gen[y].self_disch) * vSOC_RTES[y, hoursbefore(p, t, 1)] + gen[y].thermal_capacity_second_loop * EP[:eMassFlow_Sec_Loop][y, t] * (- EP[:vTemp_Chiller][y, t] + EP[:eTemp_HX_12][y, t])) 

    # The status of charge of the thermal storage is constrained by the thermal mass of the storage
    @constraint(EP, cSOC_RTES_ub[y in UTES, t = 1:T], 
        vSOC_RTES[y, t] <= EP[:eTotalCap_UTES][y, storage] * gen[y].thermal_capacity_tertiary_loop * (gen[y].temp_hot_thermal_storage - gen[y].temp_cold_thermal_storage)/3600) # devided by 3600 to convert MJ to MWh

    # mass flow in RTES, assuming no heat loss during the tertiary loop and the storage
    @constraint(EP, cMassFlow_RTES[y in UTES, t = 1:T], 
        EP[:vMassFlow_RTES][y, t] == EP[:eMassFlow_Sec_Loop][y, t] * gen[y].thermal_capacity_second_loop * (- EP[:vTemp_Chiller][y, t] + EP[:eTemp_HX_12][y, t])/(gen[y].thermal_capacity_tertiary_loop * (gen[y].temp_hot_thermal_storage - gen[y].temp_cold_thermal_storage)))

    @constraint(EP, [y in UTES, t in 1:T],
        vMassFlow_RTES_abs[y, t] >=  EP[:vMassFlow_RTES][y, t])
    @constraint(EP, [y in UTES, t in 1:T],
        vMassFlow_RTES_abs[y, t] >= -EP[:vMassFlow_RTES][y, t])
    
    # energy consumption by RTES (i.e., pump)
    @expression(EP, eElec_RTES[y in UTES, t = 1:T],
        EP[:vMassFlow_RTES_abs][y, t] * gen[y].pump_total_pressure_drop_bar * (1/1000) * 100000 / gen[y].efficiency_rtes_pump / 1000000 # convert to MW
    ) # 1000 is the water density and 100000 is the unit conversion from bar to Pa.
    # energy consumption by RTES (i.e., pump) is cinstrained by the pumping capacity
    @constraint(EP, cElec_RTES_ub[y in UTES, t = 1:T], 
    eElec_RTES[y, t] <= EP[:eTotalCap_UTES][y, pump])

    @expression(EP, ePowerBalance_RTES[t in 1:T, z in 1:Z],
        sum(EP[:eElec_RTES][y, t]
        for y in intersect(UTES, resources_in_zone_by_rid(gen, z))))

    # Added to the power balance
    EP[:ePowerBalance] -= ePowerBalance_RTES

    if CapacityReserveMargin > 0
        use_chiller = Dict((y, t) => pAmbientTemp[gen[y].zone, t] + gen[y].temp_lift_chiller_c + gen[y].temp_approach_chiller_c - gen[y].temp_evaporator_chiller_c > 0
        for y in UTES, t = 1:T)

        use_dry_cooler = Dict((y, t) => pAmbientTemp[gen[y].zone, t] < gen[y].switch_temp_c
        for y in UTES, t = 1:T)

        nCRMZones = inputs["NCapacityReserveMargin"]
        @variable(EP, vCRM_RTES[y in UTES, t = 1:T]) # CRM contribution from RTES
        @expression(EP, eCRM_RTES_thermal[y in UTES, t = 1:T], 
             -EP[:vMassFlow_RTES][y, t] * gen[y].thermal_capacity_tertiary_loop * ((gen[y].temp_hot_thermal_storage - gen[y].temp_cold_thermal_storage)))

        @expression(EP, eCRM_Chiller[y in UTES, t = 1:T],
            use_chiller[(y, t)] ? 
            ((EP[:eCRM_RTES_thermal][y, t]/EP[:eCOP_Chiller_plus_Pump][y, t]) + EP[:eElec_Chiller_Fan][y,t]) : 0)

        @expression(EP, eCRM_DC[y in UTES, t = 1:T],
            use_dry_cooler[(y, t)] ? 
            EP[:eCRM_RTES_thermal][y, t]/EP[:eCOP_DC][y, t] : 0)

        @constraint(EP, cCRM_RTES_electric[y in UTES, t = 1:T],
            vCRM_RTES[y, t] == EP[:eCRM_Chiller][y, t] + EP[:eCRM_DC][y, t]
             - EP[:eElec_RTES][y, t])
        
        @expression(EP,
            eCapResMarBalanceRTES[res = 1:nCRMZones, t = 1:T],
            sum(derating_factor(gen[y], tag = res) * EP[:vCRM_RTES][y, t] for y in UTES))
        add_similar_to_expression!(EP[:eCapResMarBalance], eCapResMarBalanceRTES)
    end

end