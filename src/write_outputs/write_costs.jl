"""Sum a 1-D JuMP expression container over `ids`, returning 0.0 when empty."""
_sum_over(expr, ids) = isempty(ids) ? 0.0 : sum(value.(expr[ids]))

"""Sum a 2-D (resource, time) JuMP expression container over `ids` and all time."""
_sum_over_time(expr, ids) = isempty(ids) ? 0.0 : sum(value.(expr[ids, :]))

"""Accumulate `value(expr[y])` into `acc[y]` for every `y` in `ids`."""
function _accumulate!(acc::Vector{Float64}, expr, ids)
    for y in ids
        acc[y] += value(expr[y])
    end
    return acc
end

"""Accumulate the time-sum of `expr[y, :]` into `acc[y]` for every `y` in `ids`."""
function _accumulate_over_time!(acc::Vector{Float64}, expr, ids)
    for y in ids
        acc[y] += sum(value.(expr[y, :]))
    end
    return acc
end

@doc raw"""
    cost_breakdown(EP::Model, inputs::Dict, setup::Dict)

Collect the solved cost terms that make up `costs.csv`, in model units and
before any scaling.

Costs that can be attributed to a resource are returned as vectors indexed by
resource id, so that the system total is the sum of the vector and a zone's
value is the sum over the resources in that zone. This is what makes the zone
columns add up to the `Total` column by construction, rather than by two
independent accumulations that can drift apart.

Costs with no per-resource attribution are returned as scalars
(`unmet_rsv`, `netexp`, `policy_penalty`) or per-zone vectors (`nse`).

Returns a `NamedTuple`; see [`assemble_costs`](@ref) for how it becomes a table.
"""
function cost_breakdown(EP::Model, inputs::Dict, setup::Dict)
    gen = inputs["RESOURCES"]
    G = length(gen)
    Z = inputs["Z"]

    VRE_STOR = inputs["VRE_STOR"]
    ALLAM_CYCLE_LOX = inputs["ALLAM_CYCLE_LOX"]
    STOR_ALL = inputs["STOR_ALL"]
    STOR_ASYMMETRIC = inputs["STOR_ASYMMETRIC"]
    FLEX = inputs["FLEX"]
    COMMIT = inputs["COMMIT"]
    CCS = inputs["CCS"]

    zeros_G() = zeros(Float64, G)
    fix, var, fuel, start = zeros_G(), zeros_G(), zeros_G(), zeros_G()
    co2, h2, grid = zeros_G(), zeros_G(), zeros_G()

    # --- Fixed costs -------------------------------------------------------
    # eTotalCFix is the sum of eCFix over all resources plus the Allam plant
    # term, so both are needed here to reproduce it.
    _accumulate!(fix, EP[:eCFix], 1:G)
    !isempty(STOR_ALL) && _accumulate!(fix, EP[:eCFixEnergy], STOR_ALL)
    !isempty(STOR_ASYMMETRIC) && _accumulate!(fix, EP[:eCFixCharge], STOR_ASYMMETRIC)
    if !isempty(ALLAM_CYCLE_LOX)
        _accumulate!(fix, EP[:eCFix_Allam_Plant], ALLAM_CYCLE_LOX)
    end

    # --- Variable costs ----------------------------------------------------
    _accumulate_over_time!(var, EP[:eCVar_out], 1:G)
    !isempty(STOR_ALL) && _accumulate_over_time!(var, EP[:eCVar_in], STOR_ALL)
    !isempty(FLEX) && _accumulate_over_time!(var, EP[:eCVarFlex_in], FLEX)
    if !isempty(ALLAM_CYCLE_LOX)
        _accumulate!(var, EP[:eCVar_Allam], ALLAM_CYCLE_LOX)
    end

    # --- Fuel --------------------------------------------------------------
    _accumulate_over_time!(fuel, EP[:ePlantCFuelOut], 1:G)

    # --- Start-up ----------------------------------------------------------
    if setup["UCommit"] >= 1
        if !isempty(COMMIT)
            _accumulate_over_time!(start, EP[:eCStart], COMMIT)
            _accumulate_over_time!(start, EP[:ePlantCFuelStart], COMMIT)
        end
        if !isempty(ALLAM_CYCLE_LOX)
            _accumulate_over_time!(start, EP[:eCStart_Allam], ALLAM_CYCLE_LOX)
            _accumulate_over_time!(start, EP[:ePlantCFuelStart], ALLAM_CYCLE_LOX)
        end
    end

    # --- CO2 sequestration -------------------------------------------------
    !isempty(CCS) && _accumulate!(co2, EP[:ePlantCCO2Sequestration], CCS)

    # --- Co-located VRE+storage -------------------------------------------
    # Each component carries its own fixed-cost and (where applicable) variable
    # O&M expression, indexed in the same resource-id space as everything else.
    if !isempty(VRE_STOR)
        fix_components = [
            (:eCFixDC, "VS_DC"),
            (:eCFixSolar, "VS_SOLAR"),
            (:eCFixWind, "VS_WIND"),
            (:eCFixElec, "VS_ELEC"),
            (:eCFixEnergy_VS, "VS_STOR"),
            (:eCFixCharge_DC, "VS_ASYM_DC_CHARGE"),
            (:eCFixDischarge_DC, "VS_ASYM_DC_DISCHARGE"),
            (:eCFixCharge_AC, "VS_ASYM_AC_CHARGE"),
            (:eCFixDischarge_AC, "VS_ASYM_AC_DISCHARGE")
        ]
        for (sym, key) in fix_components
            ids = inputs[key]
            isempty(ids) || _accumulate!(fix, EP[sym], ids)
        end

        # Note the set families differ, and mixing them up silently drops costs.
        # Fixed costs above are declared over VS_ASYM_*, since only asymmetric
        # resources have a separately sized charge or discharge capacity to pay
        # for. Variable O&M below is declared over the broader VS_STOR_* sets,
        # because every storage resource incurs it whether symmetric or not.
        var_components = [
            (:eCVarOutSolar, "VS_SOLAR"),
            (:eCVarOutWind, "VS_WIND"),
            (:eCVar_Charge_DC, "VS_STOR_DC_CHARGE"),
            (:eCVar_Discharge_DC, "VS_STOR_DC_DISCHARGE"),
            (:eCVar_Charge_AC, "VS_STOR_AC_CHARGE"),
            (:eCVar_Discharge_AC, "VS_STOR_AC_DISCHARGE")
        ]
        for (sym, key) in var_components
            ids = inputs[key]
            isempty(ids) || _accumulate_over_time!(var, EP[sym], ids)
        end

        # Grid connection is a memo row: it is the same expression already
        # counted inside cFix for these resources, reported separately.
        _accumulate!(grid, EP[:eCGrid], VRE_STOR)
    end

    # --- Hydrogen revenue (negative cost) ----------------------------------
    VS_ELEC = !isempty(VRE_STOR) ? inputs["VS_ELEC"] : Int[]
    ELECTROLYZER_ALL = !isempty(VS_ELEC) ? union(VS_ELEC, inputs["ELECTROLYZER"]) :
                       inputs["ELECTROLYZER"]
    if !isempty(ELECTROLYZER_ALL)
        for y in inputs["ELECTROLYZER"]
            h2[y] -= sum(value.(EP[:eHydrogenValue][y, :]))
        end
        for y in VS_ELEC
            h2[y] -= sum(value.(EP[:eHydrogenValue_vs][y, :]))
        end
    end

    # --- Non-served energy, by zone ---------------------------------------
    nse = [sum(value.(EP[:eCNSE][:, :, z])) for z in 1:Z]

    # --- System-wide terms with no resource attribution -------------------
    unmet_rsv = setup["OperationalReserves"] == 1 ? value(EP[:eTotalCRsvPen]) : 0.0
    netexp = (setup["NetworkExpansion"] == 1 && Z > 1) ?
             value(EP[:eTotalCNetworkExp]) : 0.0

    policy_penalty = 0.0
    for (key, sym) in [("dfCapRes_slack", :eCTotalCapResSlack),
        ("dfESR_slack", :eCTotalESRSlack),
        ("dfCO2Cap_slack", :eCTotalCO2CapSlack),
        ("MinCapPriceCap", :eTotalCMinCapSlack),
        ("MaxCapPriceCap", :eTotalCMaxCapSlack),
        ("H2DemandPriceCap", :eTotalCH2DemandSlack)]
        haskey(inputs, key) && (policy_penalty += value(EP[sym]))
    end

    return (fix = fix, var = var, fuel = fuel, start = start, co2 = co2, h2 = h2,
        grid = grid, nse = nse, unmet_rsv = unmet_rsv, netexp = netexp,
        policy_penalty = policy_penalty, obj = value(EP[:eObj]),
        electrolyzer_all = ELECTROLYZER_ALL)
end

@doc raw"""
    assemble_costs(bd::NamedTuple, inputs::Dict, setup::Dict)

Turn a [`cost_breakdown`](@ref) into the `costs.csv` table: a `Costs` column of
row names, a `Total` column, and one column per zone.

Rows without a per-resource attribution (`cUnmetRsv`, `cNetworkExp`,
`cUnmetPolicyPenalty`) and the `cGridConnection` memo row are written as `"-"`
in the zone columns, matching the system-wide nature of those terms.

`ParameterScale` is applied once, to every numeric cell, at the end.
"""
function assemble_costs(bd::NamedTuple, inputs::Dict, setup::Dict)
    gen = inputs["RESOURCES"]
    Z = inputs["Z"]
    VRE_STOR = inputs["VRE_STOR"]
    ELECTROLYZER_ALL = bd.electrolyzer_all

    cost_list = ["cTotal", "cFix", "cVar", "cFuel", "cNSE", "cStart",
        "cUnmetRsv", "cNetworkExp", "cUnmetPolicyPenalty", "cCO2"]
    !isempty(VRE_STOR) && push!(cost_list, "cGridConnection")
    !isempty(ELECTROLYZER_ALL) && push!(cost_list, "cHydrogenRevenue")

    # The objective is the authoritative total; it includes terms that have no
    # row of their own (e.g. capacity-reserve virtual charge/discharge costs).
    total = Any[bd.obj,
        sum(bd.fix),
        sum(bd.var),
        sum(bd.fuel),
        sum(bd.nse),
        sum(bd.start),
        bd.unmet_rsv,
        bd.netexp,
        bd.policy_penalty,
        sum(bd.co2)]
    !isempty(VRE_STOR) && push!(total, sum(bd.grid))
    !isempty(ELECTROLYZER_ALL) && push!(total, sum(bd.h2))

    dfCost = DataFrame(Costs = cost_list, Total = total)

    for z in 1:Z
        ids = resources_in_zone_by_rid(gen, z)
        zsum(v) = isempty(ids) ? 0.0 : sum(v[ids])

        zone_fix = zsum(bd.fix)
        zone_var = zsum(bd.var)
        zone_fuel = zsum(bd.fuel)
        zone_start = zsum(bd.start)
        zone_co2 = zsum(bd.co2)
        zone_h2 = zsum(bd.h2)
        zone_nse = bd.nse[z]

        zone_total = zone_fix + zone_var + zone_fuel + zone_start +
                     zone_co2 + zone_h2 + zone_nse

        col = Any[zone_total, zone_fix, zone_var, zone_fuel, zone_nse,
            zone_start, "-", "-", "-", zone_co2]
        !isempty(VRE_STOR) && push!(col, "-")
        !isempty(ELECTROLYZER_ALL) && push!(col, zone_h2)

        dfCost[!, Symbol("Zone$z")] = col
    end

    if setup["ParameterScale"] == 1
        for col in names(dfCost)[2:end]
            dfCost[!, col] = map(dfCost[!, col]) do v
                v isa Real ? v * ModelScalingFactor^2 : v
            end
        end
    end

    return dfCost
end

@doc raw"""
	write_costs(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the costs pertaining to the objective function (fixed, variable O&M etc.).
"""
function write_costs(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    bd = cost_breakdown(EP, inputs, setup)
    dfCost = assemble_costs(bd, inputs, setup)
    CSV.write(joinpath(path, "costs.csv"), dfCost)
end
