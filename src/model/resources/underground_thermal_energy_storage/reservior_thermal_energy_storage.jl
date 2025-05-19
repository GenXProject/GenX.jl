function rtes!(EP::Model, inputs::Dict, setup::Dict)
    # Setup variables, constraints, and expressions common to all storage resources
    println("Underground Thermal Energy Storage (Reservior Thermal Energy Storage) Module")

    gen = inputs["RESOURCES"]
    CapacityReserveMargin = setup["CapacityReserveMargin"] > 0
    HourlyMatching = setup["HourlyMatching"]

    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    UTES = inputs["UTES"]     # Number of UTES resources

    dD_computing = inputs["pD_Computing"]     # Computing demand in MW
    pAmbientTemp = inputs["pAmbientTemp"]     # Ambient temprature in C
    Q = dD_computing    # Thermal rejection from the data center is assumed to be equal to computing load
    # time related 
    p = inputs["hours_per_subperiod"]

    # UTES components
     # by default, i = 1 -> dry cooler; i = 2 -> chiller; i = 3 -> pump in the tertiary loop; i = 4 -> thermal storage; 
     dry_cooler, chiller, pump, storage = 1, 2, 3, 4

    # Variables
    # state of charge of the thermal storage
    @variable(EP, vSOC_RTES[y in UTES, t = 1:T] >=0) 

    # mass flow in RTES
    @variable(EP, vMassFlow_RTES[y in UTES, t = 1:T]) # can be positive or negative, indicating flow directions 
    # absoluate value of the mass flow in RTES
    @variable(EP, vMassFlow_RTES_abs[y in UTES, t=1:T] >= 0)

    # Expressions
    # Thermal mass of RTES (Unit: MJ)
    @expression(EP, eThermalMass_RTES[y in UTES, t =1:T],
    EP[:eTotalCap_UTES][y, storage] * gen[y].thermal_capacity_tertiary_loop * (gen[y].temp_hot_thermal_storage - gen[y].temp_cold_thermal_storage))

    # constraints

    # The status of charge of the thermal storage is equal to the sum of the thermal mass and the energy input/output (Unit: MJ) 
    @constraint(EP, cSOC_RTES[y in UTES, t = 1:T], 
        vSOC_RTES[y, t] == (1 - gen[y].self_disch) * vSOC_RTES[y, hoursbefore(p, t, 1)] + gen[y].thermal_capacity_second_loop * EP[:eMassFlow_Sec_Loop][y, t] * (EP[:vTemp_Chiller][y, t] - EP[:eTemp_HX_12][y, t])) # MJ/s = MW

    # The status of charge of the thermal storage is constrained by the thermal mass of the storage
    @constraint(EP, cSOC_RTES_ub[y in UTES, t = 1:T], 
        vSOC_RTES[y, t] <= eThermalMass_RTES[y, t])

    # mass flow in RTES, assuming no heat loss during the tertiary loop and the storage
    @constraint(EP, cMassFlow_RTES[y in UTES, t = 1:T], 
        EP[:vMassFlow_RTES][y, t] == EP[:eMassFlow_Sec_Loop][y, t] * gen[y].thermal_capacity_second_loop * (EP[:vTemp_Chiller][y, t] - EP[:eTemp_HX_12][y, t])/(gen[y].thermal_capacity_tertiary_loop * (gen[y].temp_hot_thermal_storage - gen[y].temp_cold_thermal_storage)))

    @constraint(EP, [y in UTES, t in 1:T],
        vMassFlow_RTES_abs[y, t] >=  EP[:vMassFlow_RTES][y, t])
    @constraint(EP, [y in UTES, t in 1:T],
        vMassFlow_RTES_abs[y, t] >= -EP[:vMassFlow_RTES][y, t])
    
    # energy consumption by RTES (i.e., pump)
    @expression(EP, eElec_RTES[y in UTES, t = 1:T],
        EP[:vMassFlow_RTES_abs][y, t] * gen[y].gravity_m_s2 * gen[y].depth_well_m / gen[y].efficiency_rtes_pump / 1000000 # convert to MW
    )
    # energy consumption by RTES (i.e., pump) is cinstrained by the pumping capacity
    @constraint(EP, cElec_RTES_ub[y in UTES, t = 1:T], 
    eElec_RTES[y, t] <= EP[:eTotalCap_UTES][y, pump])

    @expression(EP, ePowerBalance_RTES[t in 1:T, z in 1:Z],
        sum(EP[:eElec_RTES][y, t]
        for y in intersect(UTES, resources_in_zone_by_rid(gen, z))))

    # Added to the power balance
    EP[:ePowerBalance] -= ePowerBalance_RTES

end