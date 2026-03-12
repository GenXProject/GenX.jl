@doc raw"""
	dry_cooler!(EP::Model, inputs::Dict, setup::Dict)

Sets up variables and constraints for dry cooler resources in the UTES system. 
"""
function dry_cooler!(EP::Model, inputs::Dict, setup::Dict)
    # Setup variables, constraints, and expressions common to all storage resources
    println("Underground Thermal Energy Storage (Dry Cooler) Module")

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

    # variables 
    # @variable(EP, vTemp_DC[y in UTES, t=1:T])   # Output temperature of working fluid from dry coolers (unit: C)
    vTemp_DC = EP[:vTemp_DC]

    # expressions
    # Output temperature of secondary loop working fluid from secondary-tertiary heat exchanger to primary-secondary heat exchanger (unit: C)
    @expression(EP, eTemp_HX_12[y in UTES, t=1:T],
                gen[y].temp_max_data_center_in_c
    )

    # mass flow of the second loop is determined by the heat rejection from the data center.
    @expression(EP, eMassFlow_Sec_Loop[y in UTES, t = 1:T],
        Q[t, gen[y].zone]/(gen[y].thermal_capacity_second_loop * max(1e-6, gen[y].temp_data_center_out_c-eTemp_HX_12[y,t]))
    )

    # thermal power of the dry cooler
    @expression(EP, eThermalPower_DC[y in UTES, t =1:T],
        gen[y].thermal_capacity_second_loop * EP[:eMassFlow_Sec_Loop][y, t] * (gen[y].temp_data_center_out_c-vTemp_DC[y,t]))

    # efficiency of the dry cooler (pre-computed from lookup table or default equation)
    COP_DC = inputs["COP_DC"]
    @expression(EP, eCOP_DC[y in UTES, t = 1:T], COP_DC[y][t])

    # Precompute a boolean mask (true if cooler should be used)
    # Use dry cooler if its COP is higher than or equal to the Chiller's COP
    COP_Chiller = inputs["COP_Chiller"]
    use_dry_cooler = Dict((y, t) => COP_DC[y][t] >= COP_Chiller[y][t]
        for y in UTES, t = 1:T)

    # Use ternary operator in the expression
    @expression(EP, eElec_DC[y in UTES, t = 1:T],
    use_dry_cooler[(y, t)] ? eThermalPower_DC[y,t] / eCOP_DC[y,t] : 0
    )

    @expression(EP, ePowerBalance_DC[t = 1:T, z = 1:Z],
        sum(EP[:eElec_DC][y, t]
        for y in intersect(UTES, resources_in_zone_by_rid(gen, z))))

    # add to the power balance
    EP[:ePowerBalance] -= ePowerBalance_DC

    # constraints

    # limits on the secondary cooling loop working fluid temperature:
    @constraint(EP, cTemp_DC_max[y in UTES, t = 1:T],
                vTemp_DC[y,t]<=gen[y].max_working_fluid_temp_second_loop)
    @constraint(EP, cTemp_DC_min[y in UTES, t = 1:T],
                vTemp_DC[y,t]>=gen[y].min_working_fluid_temp_second_loop)

    # Energy consumption by dry cooler must be possitive
    @constraint(EP, cElec_DC_pos[y in UTES, t = 1:T],
                eElec_DC[y,t] >= 0)

    # Energy consumption by dry cooler is less than or equal to the capacity of the dry cooler
    @constraint(EP, cElec_DC_Cap[y in UTES, t = 1:T],
                eElec_DC[y,t] <= EP[:eTotalCap_UTES][y,dry_cooler])
end