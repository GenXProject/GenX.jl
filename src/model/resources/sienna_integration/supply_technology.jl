can_retire(t::ResourceTechnology) = IS.has_supplemental_attributes(RetirementPotential, t)
IS.get_proportional_term(c::IS.PiecewiseIncrementalCurve) = first(c.function_data.y_coords)
"""Get [`SupplyTechnology`](@ref) `heat_rate_mmbtu_per_mwh`."""
heat_rate_mmbtu_per_mwh(t::SupplyTechnology) = IS.get_proportional_term(IS.get_value_curve(PSY.get_variable(get_operation_costs(t))))
"""Get [`SupplyTechnology`](@ref) `capital_costs`."""
#inv_cost_per_mwyr(t::SupplyTechnology) = IS.get_proportional_term(get_capital_costs(t))
inv_cost_per_mwyr(t::SupplyTechnology) = IS.get_proportional_term(get_capital_costs(t)) * 0.044 / (1 - (1 + 0.044)^(-30))
"""Get [`SupplyTechnology`](@ref) `dn_time`."""
down_time(t::SupplyTechnology) = get_time_limits(t).down
"""Get [`SupplyTechnology`](@ref) `lifetime`."""
lifetime(t::SupplyTechnology) = get_lifetime(t)
"""Get [`SupplyTechnology`](@ref) `ramp_dn_percentage`."""
ramp_down_fraction(t::SupplyTechnology) = get_ramp_limits(t).down
"""Get [`SupplyTechnology`](@ref) `available`."""
new_build(t::SupplyTechnology) = Bool(get_available(t) && !(IS.has_supplemental_attributes(ExistingCapacity, t)))
"""Get [`SupplyTechnology`](@ref) `co2`."""
co2_content(t::SupplyTechnology) = get_co2(t)
"""Get [`SupplyTechnology`](@ref) `name`."""
resource_name(t::SupplyTechnology) = get_name(t)
"""Get [`SupplyTechnology`](@ref) `id`."""
resource_id(t::SupplyTechnology) = get_id(t)
# """Get [`SupplyTechnology`](@ref) `initial_capacity`."""
# existing_cap_mw(t::SupplyTechnology) = get_initial_capacity(t)
"""Get [`SupplyTechnology`](@ref) `start_fuel_mmbtu_per_mw`."""
start_fuel_mmbtu_per_mw(t::SupplyTechnology) = get_start_fuel_mmbtu_per_mw(t)
"""Get [`SupplyTechnology`](@ref) `variable_om_cost_per_mwh`."""
var_om_cost_per_mwh(t::SupplyTechnology) = IS.get_proportional_term(IS.get_vom_cost(PSY.get_variable(get_operation_costs(t))))
PSY.get_fixed(c::PSY.RenewableGenerationCost) = c.variable.value_curve.function_data.constant_term
"""Get [`SupplyTechnology`](@ref) `fixed_om_cost_per_mwhyr`."""
fixed_om_cost_per_mwyr(t::SupplyTechnology) = PSY.get_fixed(get_operation_costs(t))
# fixed_om_cost_per_mwyr(t::SupplyTechnology{PSY.ThermalStandard}) = PSY.get_fixed(get_operation_costs(t))
# function fixed_om_cost_per_mwyr(t::SupplyTechnology{T}) where {T <: Union{PSY.RenewableDispatch, PSY.RenewableNonDispatch}}
#    return IS.get_proportional_term(get_capital_costs(t))
# end
"""Get [`SupplyTechnology`](@ref) `fuel`."""
fuel(t::SupplyTechnology) = get_fuel(t)
"""Get [`SupplyTechnology`](@ref) `cofire_start_limits`."""
cofire_start_limits(t::SupplyTechnology) = get_cofire_start_limits(t)
"""Get [`SupplyTechnology`](@ref) `cofire_level_limits`."""
get_cofire_level_limits(value::SupplyTechnology) = value.cofire_level_limits
"""Get [`SupplyTechnology`](@ref) `region`."""
region(t::SupplyTechnology) = get_region(t)
"""Get [`SupplyTechnology`](@ref) `ramp_up_percentage`."""
ramp_up_fraction(t::SupplyTechnology) = get_ramp_limits(t).up
"""Get [`SupplyTechnology`](@ref) `unit_size`."""
cap_size(t::SupplyTechnology) = 1#get_unit_size(t)
"""Get [`SupplyTechnology`](@ref) `min_generation_percentage`."""
min_power(t::SupplyTechnology) = get_min_generation_fraction(t)
get_start_up(operation_costs::PSY.ThermalGenerationCost) = operation_costs.start_up
"""Get [`SupplyTechnology`](@ref) `start_cost_per_mw`."""
start_cost_per_mw(t::SupplyTechnology) = get_start_up(get_operation_costs(t))
"""Get [`SupplyTechnology`](@ref) `capacity_limits`."""
get_max_cap_mw(t::SupplyTechnology) = get_capacity_limits(t).max
get_min_cap_mw(t::SupplyTechnology) = get_capacity_limits(t).min
max_cap_mw(t::SupplyTechnology) = get_max_cap_mw(t)
min_cap_mw(t::SupplyTechnology) = get_min_cap_mw(t)
"""Get [`SupplyTechnology`](@ref) `up_time`."""
up_time(t::SupplyTechnology) = get_time_limits(t).up
fuel_costs(t::SupplyTechnology) = PSY.get_fuel_cost(PSY.get_variable(get_operation_costs(t)))
# """Get [`SupplyTechnology`](@ref) `financial_data`."""
# get_financial_data(value::SupplyTechnology) = value.financial_data
# """Get [`SupplyTechnology`](@ref) `base_power`."""
# get_base_power(value::SupplyTechnology) = value.base_power
# """Get [`SupplyTechnology`](@ref) `outage_factor`."""
# get_outage_factor(value::SupplyTechnology) = value.outage_factor
# """Get [`SupplyTechnology`](@ref) `prime_mover_type`."""
# get_prime_mover_type(value::SupplyTechnology) = value.prime_mover_type
# """Get [`SupplyTechnology`](@ref) `power_systems_type`."""
# get_power_systems_type(value::SupplyTechnology) = value.power_systems_type
# """Get [`SupplyTechnology`](@ref) `internal`."""
# get_internal(value::SupplyTechnology) = value.internal
# """Get [`SupplyTechnology`](@ref) `base_year`."""
# get_base_year(value::SupplyTechnology) = value.base_year
# """Get [`SupplyTechnology`](@ref) `ext`."""
# get_ext(value::SupplyTechnology) = value.ext
# """Get [`SupplyTechnology`](@ref) `balancing_topology`."""
# get_balancing_topology(value::SupplyTechnology) = value.balancing_topology
