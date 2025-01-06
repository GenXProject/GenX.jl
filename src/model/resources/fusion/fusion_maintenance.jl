# higher level function
function fusion_maintenance_adjust_parasitic_power!(EP, rs::Vector{<:AbstractResource})
    @debug "Maintenance modifies fusion parasitic power"

    FUSION = ids_with(rs, fusion)
    MAINTENANCE = ids_with_maintenance(rs)

    for y in intersect(FUSION, MAINTENANCE)
        resource_component = resource_name(rs[y])
        reactor = FusionReactorData(rs, y)
        _fusion_maintenance_parasitic_power_adjustment!(EP, resource_component, reactor)
    end
end

# lower level function
function _fusion_maintenance_parasitic_power_adjustment!(
        EP::Model, resource_component, reactor::FusionReactorData)
    passive = reactor.parasitic_passive_fraction
    reduction_factor = reactor.maintenance_remaining_parasitic_power_fraction
    η = reactor.eff_down
    component_size = reactor.component_size

    reduction = passive * (1 - reduction_factor)

    from_model(f::Function) = EP[f(resource_component)]

    ePassiveParasitic = from_model(fusion_parasitic_passive_name)
    vMDOWN = EP[Symbol(maintenance_down_name(resource_component))]

    eReduction = -reduction * η * component_size * vMDOWN

    add_similar_to_expression!(ePassiveParasitic, eReduction)
end
