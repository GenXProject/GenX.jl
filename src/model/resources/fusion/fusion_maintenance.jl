function maintenance_fusion_modification!(EP::Model, inputs::Dict)
    @debug "Maintenance modifies fusion expressions"

    dfGen = inputs["dfGen"]

    T = 1:inputs["T"]     # Number of time steps (hours)

    by_rid(rid, sym) = by_rid_df(rid, sym, inputs["dfTS"])

    FUSION = resources_with_fusion(inputs)
    MAINTENANCE = get_maintenance(inputs)

    vMDOWN = EP[:vMDOWN]

    frac_passive_to_reduce(y) = by_rid(y, :Recirc_Pass) * (1 - by_rid(y, :Recirc_Pass_Maintenance_Reduction))
    for y in intersect(FUSION, MAINTENANCE), t in T
            add_to_expression!(EP[:ePassiveRecircFus][t,y],
                               -by_rid(y,:Cap_Size) * vMDOWN[t,y] * dfGen[y,:Eff_Down] * frac_passive_to_reduce(y))
    end
end
