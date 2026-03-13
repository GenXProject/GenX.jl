@doc raw"""
    chiller!(EP::Model, inputs::Dict, setup::Dict)

This module models the chiller component of the Underground Thermal Energy Storage (UTES) system. 
The chiller is one of the main components alongside dry cooler, pump, and thermal storage for dissipating 
heat generated from data centers.

## Key Features

The module computes the electrical power consumption of chillers based on:
- Thermal power load from the secondary cooling loop
- Coefficient of Performance (COP) of the chiller
- Pump load for circulating working fluid
- Fan power consumption

## External COP File Support

When an external COP file (UTES_COP.csv) is provided via the `use_external_cop` flag:
- **`eCOP_Chiller_plus_Pump`** is set equal to `COP_Chiller[y][t]`, representing the **entire system COP** 
  including both chiller compressor and pump losses. The external COP value already accounts for all component losses.
- **`eElec_Chiller_Fan`** is set to 0, assuming fan power losses are already included in the external COP values.

When external COP is not used (default):
- `eCOP_Chiller_plus_Pump` is calculated as the combined COP of the chiller and pump separately
- `eElec_Chiller_Fan` is calculated based on thermodynamic fan power requirements

## Chiller Operating Logic

The chiller is selected over the dry cooler when its COP is strictly higher than the dry cooler's COP 
for a given time step. This ensures the model uses the most efficient cooling component.
"""
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
    # Use chiller if its COP is strictly higher than the Dry Cooler's COP
    COP_DC = inputs["COP_DC"]
    COP_Chiller = inputs["COP_Chiller"]
    use_chiller = Dict((y, t) => COP_Chiller[y][t] > COP_DC[y][t]
        for y in UTES, t = 1:T)
    # Precompute a boolean mask (true if cooler should be used)
    use_dry_cooler = Dict((y, t) => COP_DC[y][t] >= COP_Chiller[y][t]
        for y in UTES, t = 1:T)

    # thermal power of the chiller
    @expression(EP, eThermalPower_Chiller[y in UTES, t =1:T],
        gen[y].thermal_capacity_second_loop * EP[:eMassFlow_Sec_Loop][y, t] * (vTemp_DC[y,t] - vTemp_Chiller[y,t]))

    # efficiency of the chiller (pre-computed from lookup table or default equation)
    COP_Chiller = inputs["COP_Chiller"]
    COP_Chiller_Data_Center = get(inputs, "COP_Chiller_Data_Center", COP_Chiller)
    COP_Chiller_Reservoir = get(inputs, "COP_Chiller_Reservoir", COP_Chiller)
    @expression(EP, eCOP_Chiller[y in UTES, t=1:T], COP_Chiller[y][t])
    @expression(EP, eCOP_Chiller_Data_Center[y in UTES, t=1:T], COP_Chiller_Data_Center[y][t])
    @expression(EP, eCOP_Chiller_Reservoir[y in UTES, t=1:T], COP_Chiller_Reservoir[y][t])

    # Check if any external COP lookup is being used for the chiller.
    lookups_by_purpose = get(inputs, "UTES_COP_Lookups", Dict{String, Any}())
    legacy_lookup = get(inputs, "UTES_COP_Lookup", nothing)
    use_external_cop = (legacy_lookup !== nothing && get(legacy_lookup, "chiller", nothing) !== nothing) ||
        any(begin
            lookup = get(lookups_by_purpose, purpose, nothing)
            lookup !== nothing && get(lookup, "chiller", nothing) !== nothing
        end for purpose in ("data_center", "reservoir"))

    @expression(EP, eCOP_Chiller_plus_Pump[y in UTES, t=1:T],
        use_external_cop ? COP_Chiller[y][t] : max(0.001, Q[t, gen[y].zone]/(Q[t, gen[y].zone]/eCOP_Chiller[y,t] + gen[y].chiller_pump_load_mw)))

    @expression(EP, eCOP_Chiller_plus_Pump_Data_Center[y in UTES, t=1:T],
        use_external_cop ? COP_Chiller_Data_Center[y][t] : max(0.001, Q[t, gen[y].zone]/(Q[t, gen[y].zone]/eCOP_Chiller_Data_Center[y,t] + gen[y].chiller_pump_load_mw)))

    @expression(EP, eCOP_Chiller_plus_Pump_Reservoir[y in UTES, t=1:T],
        use_external_cop ? COP_Chiller_Reservoir[y][t] : max(0.001, Q[t, gen[y].zone]/(Q[t, gen[y].zone]/eCOP_Chiller_Reservoir[y,t] + gen[y].chiller_pump_load_mw)))

    @expression(EP, eElec_Chiller_Fan[y in UTES, t=1:T],
        use_external_cop ? 0 : eThermalPower_Chiller[y,t]*(1+1/eCOP_Chiller[y,t]) * (gen[y].fractional_pressure_chiller_fan * gen[y].ambient_pressure_pa)/(1.013 * gen[y].temp_lift_chiller_c * 1.2 * gen[y].fan_coefficient_chiller*1000)
    )

    @expression(EP, eThermalPower_Chiller_Reservoir[y in UTES, t = 1:T],
        use_chiller[(y, t)] ? EP[:eThermalPower_UTES_Reservoir][y, t] : 0)

    @expression(EP, eThermalPower_Chiller_Total[y in UTES, t = 1:T],
        use_chiller[(y, t)] ? eThermalPower_Chiller[y, t] : 0)

    @expression(EP, eThermalPower_Chiller_Data_Center[y in UTES, t = 1:T],
        use_chiller[(y, t)] ? eThermalPower_Chiller_Total[y, t] - eThermalPower_Chiller_Reservoir[y, t] : 0)

    @expression(EP, eElec_Chiller_Data_Center[y in UTES, t = 1:T],
        use_chiller[(y, t)] ? eThermalPower_Chiller_Data_Center[y,t] / eCOP_Chiller_plus_Pump_Data_Center[y,t] : 0)

    @expression(EP, eElec_Chiller_Reservoir[y in UTES, t = 1:T],
        use_chiller[(y, t)] ? eThermalPower_Chiller_Reservoir[y,t] / eCOP_Chiller_plus_Pump_Reservoir[y,t] : 0)

    @expression(EP, eElec_Chiller[y in UTES, t = 1:T],
            eElec_Chiller_Data_Center[y,t] + eElec_Chiller_Reservoir[y,t] + (use_chiller[(y, t)] ? eElec_Chiller_Fan[y,t] : 0))


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
        vTemp_DC[y,t] - vTemp_Chiller[y,t] <= EP[:eTotalCap_UTES][y, chiller]/(gen[y].thermal_capacity_second_loop * max(1e-6, EP[:eMassFlow_Sec_Loop][y, t])))
end