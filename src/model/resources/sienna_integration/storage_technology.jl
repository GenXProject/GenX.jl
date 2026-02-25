"""Get [`StorageTechnology`](@ref) `dn_time`."""
down_time(s::StorageTechnology) = get_time_limits(s).down
"""Get [`StorageTechnology`](@ref) `lifetime`."""
lifetime(s::StorageTechnology) = get_lifetime(s)
"""Get [`StorageTechnology`](@ref) `available`."""
new_build(s::StorageTechnology) = Bool(get_available(s) && (max_cap_mw(s) == 0.0 || max_cap_mwh(s) == 0.0))
"""Get [`StorageTechnology`](@ref) `co2`."""
co2_content(s::StorageTechnology) = get_co2(s)
"""Get [`StorageTechnology`](@ref) `name`."""
resource_name(s::StorageTechnology) = get_name(s)
"""Get [`StorageTechnology`](@ref) `id`."""
resource_id(s::StorageTechnology) = get_id(s)
"""Get [`StorageTechnology`](@ref) `region`."""
region(s::StorageTechnology) = get_region(s)
"""Get [`StorageTechnology`](@ref) `capacity_limits`."""
max_cap_mw(s::StorageTechnology) = get_max(get_capacity_limits_discharge(s))
max_cap_mwh(s::StorageTechnology) = get_max(get_capacity_limits_energy(s))
max_charge_cap_mw(s::StorageTechnology) = get_max(get_capacity_limits_charge(s))
min_cap_mw(s::StorageTechnology) = get_min(get_capacity_limits_discharge(s))
min_cap_mwh(s::StorageTechnology) = get_min(get_capacity_limits_energy(s))
min_charge_cap_mw(s::StorageTechnology) = get_min(get_capacity_limits_charge(s))
"""Get [`StorageTechnology`](@ref) `up_time`."""
up_time(s::StorageTechnology) = get_time_limits(s).up
"""Get [`StorageTechnology`](@ref) `duration_limits`."""
max_duration(s::StorageTechnology) = get_max(get_duration_limits(s))
min_duration(s::StorageTechnology) = get_min(get_duration_limits(s))
self_discharge(s::StorageTechnology) = get_losses(s)
"""Get [`StorageTechnology`](@ref) `efficiency`."""
efficiency_down(s::StorageTechnology) = get_out(get_efficiency(s))
efficiency_up(s::StorageTechnology) = get_in(get_efficiency(s))
inv_cost_per_mwyr(s::StorageTechnology) = PSY.get_proportional_term(get_capital_costs_discharge(s))
inv_cost_per_mwhyr(s::StorageTechnology) = PSY.get_proportional_term(get_capital_costs_energy(s))
inv_cost_charge_per_mwyr(s::StorageTechnology) = PSY.get_proportional_term(get_capital_costs_charge(s))
fixed_om_cost_per_mwyr(s::StorageTechnology) = PSY.get_proportional_term(PSY.get_value_curve(PSY.get_discharge_variable_cost(get_operation_costs(s))))
fixed_om_cost_per_mwhyr(s::StorageTechnology) = PSY.get_fixed(get_operation_costs(s))
fixed_om_cost_charge_per_mwyr(s::StorageTechnology) = PSY.get_proportional_term(PSY.get_value_curve(PSY.get_charge_variable_cost(get_operation_costs(s))))
var_om_cost_per_mwh(s::StorageTechnology) = PSY.get_proportional_term(PSY.get_vom_cost(PSY.get_discharge_variable_cost(get_operation_costs(s))))
var_om_cost_per_mwh_in(s::StorageTechnology) = PSY.get_proportional_term(PSY.get_vom_cost(PSY.get_charge_variable_cost(get_operation_costs(s))))

# """Get [`StorageTechnology`](@ref) `financial_data`."""
# get_financial_data(value::StorageTechnology) = value.financial_data
# """Get [`StorageTechnology`](@ref) `base_power`."""
# get_base_power(value::StorageTechnology) = value.base_power
# """Get [`StorageTechnology`](@ref) `outage_factor`."""
# get_outage_factor(value::StorageTechnology) = value.outage_factor
# """Get [`StorageTechnology`](@ref) `prime_mover_type`."""
# get_prime_mover_type(value::StorageTechnology) = value.prime_mover_type
# """Get [`StorageTechnology`](@ref) `power_systems_type`."""
# get_power_systems_type(value::StorageTechnology) = value.power_systems_type
# """Get [`StorageTechnology`](@ref) `internal`."""
# get_internal(value::StorageTechnology) = value.internal
# """Get [`StorageTechnology`](@ref) `base_year`."""
# get_base_year(value::StorageTechnology) = value.base_year
# """Get [`StorageTechnology`](@ref) `ext`."""
# get_ext(value::StorageTechnology) = value.ext
# """Get [`StorageTechnology`](@ref) `balancing_topology`."""
# get_balancing_topology(value::StorageTechnology) = value.balancing_topology

function symmetric_storage(ts::Vector{Technology})
    findall(t -> isa(t, StorageTechnology) && isnothing(inv_cost_charge_per_mwyr(t)), ts)
end

function asymmetric_storage(ts::Vector{Technology})
    findall(t -> isa(t, StorageTechnology) && !isnothing(inv_cost_charge_per_mwyr(t)), ts)
end

existing_charge_cap_mw(s::StorageTechnology) = 0.0