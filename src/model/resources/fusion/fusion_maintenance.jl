# higher level function
function fusion_maintenance_adjust_parasitic_power!(EP, df::DataFrame)
    @debug "Maintenance modifies fusion parasitic power"

    FUSION = resources_with_fusion(df)
    MAINTENANCE = resources_with_maintenance(df)

    for y in intersect(FUSION, MAINTENANCE)
        resource_component = df[y, :Resource]
        reactor = FusionReactorData(df, y)
        _fusion_maintenance_parasitic_power_adjustment!(EP, resource_component, reactor)
    end
end

# lower level function
function _fusion_maintenance_parasitic_power_adjustment!(EP::Model, resource_component, reactor::FusionReactorData)
    passive = reactor.parasitic_passive_fraction
    reduction_factor = reactor.maintenance_remaining_parasitic_power_fraction
    η = reactor.eff_down
    cap_size = reactor.component_size

    reduction = passive * (1 - reduction_factor)

    get_from_model(f::Function) = EP[Symbol(f(resource_component))]

    ePassiveParasitic = get_from_model(fusion_parasitic_passive_name)
    vMDOWN = get_from_model(maintenance_down_name)

    eReduction = -reduction * η * cap_size * vMDOWN

    add_similar_to_expression!(ePassiveParasitic, eReduction)
end
