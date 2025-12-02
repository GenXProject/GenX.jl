function chiller!(EP::Model, inputs::Dict, setup::Dict)
    # Setup variables, constraints, and expressions common to all storage resources
    println("Underground Thermal Energy Storage (Chiller) Module")

    gen = inputs["RESOURCES"]
    CapacityReserveMargin = setup["CapacityReserveMargin"] > 0
    HourlyMatching = setup["HourlyMatching"]

    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    UTES = inputs["UTES"]     # Number of UTES resources

    dD_computing = inputs["pD_Computing"]     # Computing demand in MW
    pAmbientTemp = inputs["pAmbientTemp"]     # Ambient temprature in C
    Q = dD_computing    # Thermal rejection from the data center is assumed to be equal to computing load
    
    # UTES components
    # by default, i = 1 -> dry cooler; i = 2 -> chiller; i = 3 -> pump in the tertiary loop; i = 4 -> thermal storage; 
    dry_cooler, chiller, pump, storage = 1, 2, 3, 4

    # # variables 
    # @variable(EP, vTemp_Chiller[y in UTES, t=1:T])   # Output temperature of working fluid from chillers (unit: C)
    vTemp_Chiller = EP[:vTemp_Chiller]
    vTemp_DC = EP[:vTemp_DC]

    # Precompute a boolean mask (true if chiller should be used)
    use_chiller = Dict((y, t) => pAmbientTemp[gen[y].zone, t] + gen[y].temp_lift_chiller_c + gen[y].temp_approach_chiller_c - gen[y].temp_evaporator_chiller_c > 0
        for y in UTES, t = 1:T)
    # Precompute a boolean mask (true if cooler should be used)
    use_dry_cooler = Dict((y, t) => pAmbientTemp[gen[y].zone, t] < gen[y].switch_temp_c
        for y in UTES, t = 1:T)

    # thermal power of the chiller
    @expression(EP, eThermalPower_Chiller[y in UTES, t =1:T],
        gen[y].thermal_capacity_second_loop * EP[:eMassFlow_Sec_Loop][y, t] * (vTemp_DC[y,t] - vTemp_Chiller[y,t]))

    # efficiency of the chiller
    # assuming that chiller output temperatures-chiller output temperatures>T^evap 

    @expression(EP, eCOP_Chiller[y in UTES, t=1:T],
        gen[y].irreversibility_factor_chiller * (gen[y].temp_evaporator_chiller_c+273.15)/(pAmbientTemp[gen[y].zone, t]+ gen[y].temp_lift_chiller_c + gen[y].temp_approach_chiller_c - gen[y].temp_evaporator_chiller_c)
    )

    @expression(EP, eCOP_Chiller_plus_Pump[y in UTES, t=1:T],
        max(0.001, Q[t, gen[y].zone]/(Q[t, gen[y].zone]/eCOP_Chiller[y,t] + gen[y].chiller_pump_load_mw)))

    @expression(EP, eElec_Chiller_Fan[y in UTES, t=1:T],
        eThermalPower_Chiller[y,t]*(1+1/eCOP_Chiller[y,t]) * (gen[y].fractional_pressure_chiller_fan * gen[y].ambient_pressure_pa)/(1.013 * gen[y].temp_lift_chiller_c * 1.2 * gen[y].fan_coefficient_chiller*1000)
    )

    @expression(EP, eElec_Chiller[y in UTES, t = 1:T],
            use_chiller[(y, t)] ? eThermalPower_Chiller[y,t]/eCOP_Chiller_plus_Pump[y,t] + eElec_Chiller_Fan[y,t] : 0)


    @expression(EP, ePowerBalance_Chiller[t in 1:T, z in 1:Z],
        sum(EP[:eElec_Chiller][y, t]
        for y in intersect(UTES, resources_in_zone_by_rid(gen, z))))
    # add to the power balance
    EP[:ePowerBalance] -= ePowerBalance_Chiller

    # constraints

    # limits on the secondary cooling loop working fluid temperature:
    @constraint(EP, cTemp_Chiller_max[y in UTES, t = 1:T],
                vTemp_Chiller[y,t]<=gen[y].max_working_fluid_temp_second_loop)
    @constraint(EP, cTemp_Chiller_min[y in UTES, t = 1:T],
                vTemp_Chiller[y,t]>=gen[y].min_working_fluid_temp_second_loop)

    # Chillers are characterized by their thermal capacity
    @constraint(EP, cChillerTempDrop_ub[y in UTES, t=1:T],
        vTemp_DC[y,t] - vTemp_Chiller[y,t] <= EP[:eTotalCap_UTES][y, chiller]/(gen[y].thermal_capacity_second_loop * EP[:eMassFlow_Sec_Loop][y, t]))

end