# Utility functions for TransmissionTechnology and AggregateTransportTechnology

#TODO: get_wacc, get_capital_recovery_factor, get_line_max_flow_possible_mw

PowerSystemsInvestmentsPortfolios.get_line_loss(value::NodalACTransportTechnology) = 0#value.line_loss

start_region(t::TransmissionTechnology) = get_start_node(t)
end_region(t::TransmissionTechnology) = get_end_node(t)

zone_id_inter(t::RegionTopology) = get_id(t)
zone_id(::Type{T}, p::Portfolio) where T<:RegionTopology = sort(collect(get_regions(T, p)), by=x->get_id(x))

start_region(t::AggregateTransportTechnology) = get_start_region(t)
end_region(t::AggregateTransportTechnology) = get_end_region(t)

line_loss(t::TransmissionTechnology) = get_line_loss(t)
voltage(t::TransmissionTechnology) = get_voltage(t)
resistance(t::TransmissionTechnology) = get_resistance(t)
reactance(t::TransmissionTechnology) = get_reactance(t)
angle_limit(t::TransmissionTechnology) = get_angle_limit(t)

line_reinforcement_cost(t::TransmissionTechnology) = IS.get_proportional_term(GenX.get_capital_costs(t))
line_reinforcement_max(t::TransmissionTechnology) = get_max(get_capacity_limits(t))