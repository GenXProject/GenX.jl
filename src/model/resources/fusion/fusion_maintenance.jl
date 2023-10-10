# higher level function
function fusion_maintenance_parasitic_power_adjustment!(EP, df::DataFrame)
    @debug "Maintenance modifies fusion parasitic power"

    by_rid(rid, sym) = by_rid_df(rid, sym, df)

    FUSION = resources_with_fusion(df)
    MAINTENANCE = resources_with_maintenance(df)

    for y in intersect(FUSION, MAINTENANCE)
        resource_component(y) = df[y, :Resource]
        reactor = FusionReactorData(parasitic_passive_fraction = by_rid(y, :Recirc_Pass),
                                    eff_down = by_rid(y, :Eff_Down),
                                    component_size = by_rid(y, :Cap_Size),
                                    maintenance_remaining_parasitic_power_fraction = by_rid(y, :Recirc_Pass_Maintenance_Remaining))

        fusion_maintenance_parasitic_power_adjustment!(EP, resource_component, reactor)
    end
end

# lower level function
function fusion_maintenance_parasitic_power_adjustment!(EP::Model, resource_component, reactor::FusionReactorData)
    passive = reactor.parasitic_passive_fraction
    reduction_factor = reactor.maintenance_remaining_parasitic_power_fraction
    η = reactor.eff_down
    cap_size = reactor.component_size

    reduction = passive * (1 - reduction_factor)

    eTotalParasitic = EP[Symbol(fusion_parasitic_total_name(resource_component))]
    vMDOWN = EP[Symbol(maintenance_down_name(resource_component))]

    eReduction = -reduction * η * cap_size * vMDOWN

    add_similar_to_expression!(eTotalParasitic, eReduction)
end
