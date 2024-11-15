
function ppa!(EP::Model, inputs::Dict, setup::Dict)
    println("Power Purchase Agreement (PPA) Module")

    gen = inputs["RESOURCES"]

    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    G = inputs["G"]     # Number of generators

    PPA = inputs["PPA"]
    omega = inputs["omega"]
    @expression(EP, eVariableSubsidiesByPlant[y = 1:G, t = 1:T],
                if y in PPA
                    EP[:vP][y, t] * gen[y].var_om_cost_per_mwh_ppa
                else
                    0.0
                end)
    # @expression(EP, eVariableSubsidiesByZone[z = 1:Z, t = 1:T],
    #         sum(eVariableSubsidiesByPlant[y, t] for y in resources_in_zone_by_rid(gen, z)))
    @expression(EP, eTotalVariableSubsidies,
                sum(omega[t] * eVariableSubsidiesByPlant[y, t] for t in 1:T, y in PPA))

    @expression(EP, eFixedSubsidiesByPlant[y in 1:G, t = 1:T],
                if y in PPA
                    inputs["pP_Max"][y, t] * EP[:eTotalCap][y] * gen[y].fixed_om_cost_per_mwh_ppa
                else
                    0.0
                end)
    # @expression(EP, eFixedSubsidiesByZone[z = 1:Z, t = 1:T],
    #         sum(eFixedSubsidiesByPlant[y, t] for y in resources_in_zone_by_rid(gen, z)))
    @expression(EP, eTotalFixedSubsidies,
            sum(omega[t] * eFixedSubsidiesByPlant[y, t] for t in 1:T, y in PPA))
    add_to_expression!(EP[:eObj], - EP[:eTotalVariableSubsidies] - EP[:eTotalFixedSubsidies])
end