function ates!(EP::Model, inputs::Dict, setup::Dict)
    # Setup variables, constraints, and expressions common to all storage resources
    println("Underground Thermal Energy Storage (ATES) Module")

    T = inputs["T"]
    Z = inputs["Z"]
    UTES = inputs["UTES"]
    STOR_UTES_SHORT_DURATION = inputs["STOR_UTES_SHORT_DURATION"]
    gen  = inputs["RESOURCES"]

    dD_computing = inputs["pD_Computing"]     # Computing demand in MW
    pAmbientTemp = inputs["pAmbientTemp"]     # Ambient temprature in C
    Q = dD_computing    # Thermal rejection from the data center is assumed to be equal to computing load

    # UTES components
    # by default, i = 1 -> dry cooler; i = 2 -> chiller; i = 3 -> pump in the tertiary loop; i = 4 -> thermal storage; 
    dry_cooler, chiller, pump, storage = 1, 2, 3, 4

    # time related 
    p = inputs["hours_per_subperiod"]
    representative_periods = inputs["REP_PERIOD"]
    START_SUBPERIODS = inputs["START_SUBPERIODS"]
    INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]

    use_chiller = Dict((y, t) => pAmbientTemp[gen[y].zone, t] + gen[y].temp_lift_chiller_c + gen[y].temp_approach_chiller_c - gen[y].temp_evaporator_chiller_c > 0
        for y in UTES, t = 1:T)

    use_dry_cooler = Dict((y, t) => pAmbientTemp[gen[y].zone, t] < gen[y].switch_temp_c
        for y in UTES, t = 1:T)


    # Decision variables
    @variable(EP, vTemp_Cold[y in UTES, t=1:T])     # Temperature in the cold well
    @variable(EP, vTemp_Hot[y in UTES, t=1:T])      # Temperature in the hot well
    @variable(EP, vQ_Cold[y in UTES, t=1:T])   # Heat transferred to the cold well
    @variable(EP, vQ_Hot[y in UTES, t=1:T])    # Heat transferred to the hot well
    @variable(EP, vPump_pos[y in UTES, t=1:T]>=0)      # take the positive part in the balence
    @variable(EP, vPump_neg[y in UTES, t=1:T]>= 0)  # take the negative part in the balence
    @variable(EP, vAux_Chiller[y in UTES, t=1:T]>=0)#auxilary cooling provided by chiller to thermal storage to chargeenables bi-directional flow
    @variable(EP, vAux_DC[y in UTES, t=1:T]>=0)     #auxilary cooling provided by dry cooler to thermal storage to chargeenables bi-directional flow
    # Expressions

    # 1. Cooling provided by the dry cooler
    @expression(EP, eThermalPower_DC_final[y in UTES, t=1:T],
                use_dry_cooler[(y, t)] ? EP[:eThermalPower_DC][y, t] : 0)
    # 2. Cooling provided by the chiller
    @expression(EP, eThermalPower_Chiller_final[y in UTES, t=1:T],
                use_chiller[(y, t)] ? EP[:eThermalPower_Chiller][y, t] : 0)

    # 3. Auxillary cooling provided by chillers and dry coolers
    @expression(EP, eAux[y in UTES, t = 1:T], 
                vAux_Chiller[y, t] + vAux_DC[y, t])

    # 4. Total cooling provided in the data center at the unit level
    @expression(EP, eCooling[y in UTES, t=1:T],
         (-vQ_Cold[y, t] - vQ_Hot[y, t]) - EP[:eThermalPower_DC_final][y, t] - EP[:eThermalPower_Chiller_final][y, t] - EP[:eAux][y, t]
    ) # negative values indicate cooling
    # need to correct the sign convenction for the equation above. vQ is for heat. but eThermalPower is for cold.

    # 5. Total cooling at the zonal level
    @expression(EP, eCooling_zone[t = 1:T, z = 1:Z],
            sum(eCooling[y, t] for y in intersect(resources_in_zone_by_rid(gen, z), UTES)))

    # 6. Pump flow and power consumption
    @expression(EP, ePump_flow[y in UTES, t = 1:T],
            0.001 * vQ_Cold[y, t])
    @expression(EP, eElec_pump[y in UTES, t = 1:T],
            vPump_pos[y, t] + vPump_neg[y, t])

    # 7. Aux electricity conumption
    @expression(EP, eElec_Aux_Chiller[y in UTES, t = 1:T],
            use_chiller[(y, t)] ? EP[:vAux_Chiller][y, t] / EP[:eCOP_Chiller][y,t] : 0)
    @expression(EP, eElec_Aux_DC[y in UTES, t = 1:T],
            use_dry_cooler[(y, t)] ? EP[:vAux_DC][y, t] / EP[:eCOP_DC][y,t] : 0)

    # 6. Power balance
    @expression(EP, ePowerBalance_ATES[t in 1:T, z in 1:Z],
        sum((EP[:eElec_pump][y, t] + EP[:eElec_Aux_Chiller][y, t] + EP[:eElec_Aux_DC][y, t])
        for y in intersect(UTES, resources_in_zone_by_rid(gen, z))))

    # Added to the power balance
    EP[:ePowerBalance] -= ePowerBalance_ATES

    # Constraints
    # 1. Bounds for variables
    @constraint(EP, [y in UTES, t=1:T], gen[y].min_temp_cold_well_c <= vTemp_Cold[y, t])
    @constraint(EP, [y in UTES, t=1:T], vTemp_Cold[y, t] <= gen[y].max_temp_cold_well_c)
    @constraint(EP, [y in UTES, t=1:T], gen[y].min_temp_hot_well_c <= vTemp_Hot[y, t])
    @constraint(EP, [y in UTES, t=1:T], vTemp_Hot[y, t] <= gen[y].max_temp_hot_well_c)
    @constraint(EP, [y in UTES, t=1:T], vQ_Cold[y, t] <= gen[y].q_cold_max)
    @constraint(EP, [y in UTES, t=1:T], vQ_Hot[y, t] <= gen[y].q_hot_max)

    # 2. Meet cooling demand at data center
    @constraint(EP, cCoolingBalance[t=1:T, z=1:Z], eCooling_zone[t, z] == -Q[t, z])

    # 3. Relationship between q_cold and q_hot????
    @constraint(EP, cCoolHeat[y in UTES, t=1:T], vQ_Hot[y, t] <=  -0.3 * vQ_Cold[y, t])

    # 4. Pump flow and power consumption
    @constraint(EP, cPump_flow[y in UTES, t=1:T], 
                ePump_flow[y, t] == vPump_pos[y, t] - vPump_neg[y, t])
    @constraint(EP, cPump_cap_lb[y in UTES, t = 1:T], 
                ePump_flow[y, t] >= -EP[:eTotalCap_UTES][y, pump])
    @constraint(EP, cPump_cap_ub[y in UTES, t = 1:T], 
                ePump_flow[y, t] <= EP[:eTotalCap_UTES][y, pump])

    # 5. Initial conditions
    @constraint(EP, cInitial_Cold_Well[y in UTES], vTemp_Cold[y, 1] == gen[y].temp_init_cold_well_c)
    @constraint(EP, cInitial_Hot_Well[y in UTES], vTemp_Hot[y, 1]  == gen[y].temp_init_hot_well_c)

    # 7. Lumped dynamics with ONLY self-discharge and flows (no in/out terms)
    # add LDS constraints later

    # constraints that only apply to short duration storage
    if representative_periods > 1 && !isempty(inputs["STOR_UTES_LONG_DURATION"])
        CONSTRAINTSET_UTES = STOR_UTES_SHORT_DURATION
    else
        CONSTRAINTSET_UTES = UTES
    end

    # during the start period, different for long and short-duration UTES
    @constraint(EP, cSOC_ATES_Cold_Start[y in CONSTRAINTSET_UTES, t in START_SUBPERIODS],
                gen[y].c_eff_c * (vTemp_Cold[y, t] - vTemp_Cold[y, hoursbefore(p, t, 1)]) ==
                (vQ_Cold[y, t] + gen[y].alpha_loss_cold * gen[y].c_eff_c * (gen[y].max_temp_cold_well_c - vTemp_Cold[y, t]))
    )

    @constraint(EP, cSOC_ATES_Hot_Start[y in CONSTRAINTSET_UTES, t in START_SUBPERIODS],
                gen[y].c_eff_h * (vTemp_Hot[y, t] - vTemp_Hot[y, hoursbefore(p, t, 1)]) ==
                (vQ_Hot[y, t] - gen[y].alpha_loss_hot * gen[y].c_eff_h * (vTemp_Hot[y, t] - gen[y].min_temp_hot_well_c))
    )

    # during the interior period, same for long and short-duration UTES
    @constraint(EP, cSOC_ATES_Cold_Interior[y in UTES, t in INTERIOR_SUBPERIODS], 
                gen[y].c_eff_c * (vTemp_Cold[y, t] - vTemp_Cold[y, hoursbefore(p, t, 1)]) ==
                (vQ_Cold[y, t] + gen[y].alpha_loss_cold * gen[y].c_eff_c * (gen[y].max_temp_cold_well_c - vTemp_Cold[y, t]))
        ) 

    @constraint(EP, cSOC_ATES_Hot_Interior[y in UTES, t in INTERIOR_SUBPERIODS],
                gen[y].c_eff_h * (vTemp_Hot[y, t] - vTemp_Hot[y, hoursbefore(p, t, 1)]) ==
                (vQ_Hot[y, t] - gen[y].alpha_loss_hot * gen[y].c_eff_h * (vTemp_Hot[y, t] - gen[y].min_temp_hot_well_c))
    )

    # 6. Ensure that the cold well is always colder than the hot well
    @constraint(EP, cColdHot[y in UTES, t=1:T], vTemp_Cold[y, t] <= vTemp_Hot[y, t])
    
    # add CRM contribution later
    # if CapacityReserveMargin > 0
    # end
end
