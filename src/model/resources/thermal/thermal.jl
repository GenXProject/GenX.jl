@doc raw"""
    thermal!(EP::Model, inputs::Dict, setup::Dict)
The thermal module creates decision variables, expressions, and constraints related to thermal power plants e.g. coal, oil or natural gas steam plants, natural gas combined cycle and combustion turbine plants, nuclear, hydrogen combustion etc.
This module uses the following 'helper' functions in separate files: ```thermal_commit()``` for thermal resources subject to unit commitment decisions and constraints (if any) and ```thermal_no_commit()``` for thermal resources not subject to unit commitment (if any).
"""
function thermal!(EP::Model, inputs::Dict, setup::Dict)
    gen = inputs["RESOURCES"]

    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones

    THERM_COMMIT = inputs["THERM_COMMIT"]
    THERM_NO_COMMIT = inputs["THERM_NO_COMMIT"]
    THERM_ALL = inputs["THERM_ALL"]
    MAINT = ids_with_maintenance(gen)
    FUSION = ids_with(gen, fusion)

    if !isempty(THERM_COMMIT)
        thermal_commit!(EP, inputs, setup)
    end

    if !isempty(THERM_NO_COMMIT)
        thermal_no_commit!(EP, inputs, setup)
    end
    ##CO2 Polcy Module Thermal Generation by zone
    @expression(EP, eGenerationByThermAll[z = 1:Z, t = 1:T], # the unit is GW
        sum(EP[:vP][y, t]
        for y in intersect(inputs["THERM_ALL"], resources_in_zone_by_rid(gen, z))))
    add_similar_to_expression!(EP[:eGenerationByZone], eGenerationByThermAll)

    # Capacity Reserves Margin policy
    if setup["CapacityReserveMargin"] > 0
        ncapres = inputs["NCapacityReserveMargin"]
        @expression(EP, eCapResMarBalanceThermal[capres in 1:ncapres, t in 1:T],
            sum(derating_factor(gen[y], tag = capres) * EP[:eTotalCap][y]
            for y in THERM_ALL))
        add_similar_to_expression!(EP[:eCapResMarBalance], eCapResMarBalanceThermal)

        if !isempty(intersect(MAINT, THERM_COMMIT))
            thermal_maintenance_capacity_reserve_margin_adjustment!(EP, inputs)
        end

        if !isempty(intersect(FUSION, THERM_COMMIT))
            fusion_capacity_reserve_margin_adjustment!(EP, inputs)
        end
    end

    if setup["EnergyShareRequirement"] > 0
        if !isempty(intersect(FUSION, THERM_COMMIT))
            fusion_parasitic_power_adjust_energy_share_requirement!(EP, inputs)
        end
    end
end
