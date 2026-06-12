@doc raw"""
    investment_discharge_vre_stor!(EP::Model, inputs::Dict, setup::Dict)

Planning-stage VRE-STOR capacity formulation.

This function creates investment/retirement variables, total-capacity expressions, fixed and
investment cost terms, and planning-side bounds for the VRE-STOR module components:
grid connection, inverter, solar, wind, storage energy, and electrolyzer.

For each component $k \in \{\text{grid},\text{dc},\text{solar},\text{wind},\text{stor},\text{elec}\}$,
the total installed capacity is represented with the same pattern:

```math
\Delta^{\text{tot},k}_{y} = \overline{\Delta}^{k}_{y} + \Omega^{k}_{y} - \Delta^{\text{ret},k}_{y}
```

with the appropriate subset logic when a resource is only eligible for build or retirement.

The objective includes component-level investment and fixed O&M terms, e.g.

```math
\sum_y \left(\pi^{\text{INV},k}_{y}\,\Omega^{k}_{y} + \pi^{\text{FOM},k}_{y}\,\Delta^{\text{tot},k}_{y}\right)
```

(scaled by `1/OPEXMULT` in multi-stage mode for O&M terms as implemented).

The function also enforces:

```math
\Delta^{\text{ret},k}_{y} \le \overline{\Delta}^{k}_{y},
\qquad
\underline{\Delta}^{k}_{y} \le \Delta^{\text{tot},k}_{y} \le \overline{\Delta}^{k}_{y}
```

whenever min/max bounds are provided in inputs, plus inverter-ratio constraints for solar and wind.

Finally, it adds VRE-STOR contributions to minimum/maximum capacity requirement policy
expressions and, when Benders planning is enabled with representative periods and LDS resources,
activates `lds_vre_stor_planning!()`.
"""
function investment_discharge_vre_stor!(EP::Model, inputs::Dict, setup::Dict)
    println("Investment VRE Storage Module")
    MultiStage = setup["MultiStage"]

    gen = inputs["RESOURCES"]

    G = inputs["G"] # Number of resources (generators, storage, DR, and DERs)

    T = inputs["T"]                                                 # Number of time steps (hours)
    Z = inputs["Z"]                                                 # Number of zones

    gen_VRE_STOR = gen.VreStorage

    # Load VRE-storage inputs
    VRE_STOR = inputs["VRE_STOR"]                                   # Set of VRE-STOR generators (indices)
    SOLAR = inputs["VS_SOLAR"]                                      # Set of VRE-STOR generators with solar-component
    DC = inputs["VS_DC"]                                            # Set of VRE-STOR generators with inverter-component
    WIND = inputs["VS_WIND"]                                        # Set of VRE-STOR generators with wind-component
    STOR = inputs["VS_STOR"]                                        # Set of VRE-STOR generators with storage-component
    ELEC = inputs["VS_ELEC"]                                        # Set of VRE-STOR generators with electrolyzer-component
    NEW_CAP = intersect(VRE_STOR, inputs["NEW_CAP"])                # Set of VRE-STOR generators eligible for new buildout

    # NEW CAP for DC, SOLAR, WIND, STOR, and ELEC components
    NEW_CAP_DC = inputs["NEW_CAP_DC"]
    RET_CAP_DC = inputs["RET_CAP_DC"]
    NEW_CAP_SOLAR = inputs["NEW_CAP_SOLAR"]
    RET_CAP_SOLAR = inputs["RET_CAP_SOLAR"]
    NEW_CAP_WIND = inputs["NEW_CAP_WIND"]
    RET_CAP_WIND = inputs["RET_CAP_WIND"]
    NEW_CAP_STOR = inputs["NEW_CAP_STOR"]
    RET_CAP_STOR = inputs["RET_CAP_STOR"]
    NEW_CAP_ELEC = inputs["NEW_CAP_ELEC"]
    RET_CAP_ELEC = inputs["RET_CAP_ELEC"]

    # Policy flags
    EnergyShareRequirement = setup["EnergyShareRequirement"]
    CapacityReserveMargin = setup["CapacityReserveMargin"]
    MinCapReq = setup["MinCapReq"]
    MaxCapReq = setup["MaxCapReq"]
    IncludeLossesInESR = setup["IncludeLossesInESR"]
    OperationalReserves = setup["OperationalReserves"]

    DC_DISCHARGE = inputs["VS_STOR_DC_DISCHARGE"]
    DC_CHARGE = inputs["VS_STOR_DC_CHARGE"]
    AC_DISCHARGE = inputs["VS_STOR_AC_DISCHARGE"]
    AC_CHARGE = inputs["VS_STOR_AC_CHARGE"]
    VS_SYM_DC = inputs["VS_SYM_DC"]
    VS_SYM_AC = inputs["VS_SYM_AC"]
    VS_LDS = inputs["VS_LDS"]


    START_SUBPERIODS = inputs["START_SUBPERIODS"]
    INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]
    hours_per_subperiod = inputs["hours_per_subperiod"]     # total number of hours per subperiod
    rep_periods = inputs["REP_PERIOD"]

    MultiStage = setup["MultiStage"]

    ## 1. Objective Function Expressions ##

    # Separate grid costs
    @expression(EP, eCGrid[y in VRE_STOR],
        if y in NEW_CAP # Resources eligible for new capacity
            inv_cost_per_mwyr(gen[y]) * EP[:vCAP][y] +
            fixed_om_cost_per_mwyr(gen[y]) * EP[:eTotalCap][y]
        else
            fixed_om_cost_per_mwyr(gen[y]) * EP[:eTotalCap][y]
        end)
    @expression(EP, eTotalCGrid, sum(eCGrid[y] for y in VRE_STOR))


    by_rid(rid, sym) = by_rid_res(rid, sym, gen_VRE_STOR)

    #########################################################################
    ### ADD INVERTER NEW CAP AND CONSTRAINTS/EXPRESSIONS ###
    #########################################################################
    if !isempty(DC)
        ### INVERTER VARIABLES ###
        @variables(EP, begin
            # Inverter capacity 
            vRETDCCAP[y in RET_CAP_DC] >= 0                         # Retired inverter capacity [MW AC]
            vDCCAP[y in NEW_CAP_DC] >= 0                            # New installed inverter capacity [MW AC]
        end)

        if MultiStage == 1
            @variable(EP, vEXISTINGDCCAP[y in DC]>=0)
        end

        ### EXPRESSIONS ###
        # Multistage existing capacity definition
        if MultiStage == 1
            @expression(EP, eExistingCapDC[y in DC], vEXISTINGDCCAP[y])
        else
            @expression(EP, eExistingCapDC[y in DC], by_rid(y, :existing_cap_inverter_mw))
        end

        # Total inverter capacity
        NEW_AND_RET_CAP_DC = intersect(NEW_CAP_DC, RET_CAP_DC)
        NEW_NOT_RET_CAP_DC = setdiff(NEW_CAP_DC, RET_CAP_DC)
        RET_NOT_NEW_CAP_DC = setdiff(RET_CAP_DC, NEW_CAP_DC)
        @expression(EP, eTotalCap_DC[y in DC],
            if (y in NEW_AND_RET_CAP_DC) # Resources eligible for new capacity and retirements
                eExistingCapDC[y] + EP[:vDCCAP][y] - EP[:vRETDCCAP][y]
            elseif (y in NEW_NOT_RET_CAP_DC) # Resources eligible for only new capacity
                eExistingCapDC[y] + EP[:vDCCAP][y]
            elseif (y in RET_NOT_NEW_CAP_DC) # Resources eligible for only capacity retirements
                eExistingCapDC[y] - EP[:vRETDCCAP][y]
            else
                eExistingCapDC[y]
            end
        )

        # Objective function additions
        # Fixed costs for inverter component (if resource is not eligible for new inverter capacity, fixed costs are only O&M costs)
        @expression(EP, eCFixDC[y in DC],
            if y in NEW_CAP_DC # Resources eligible for new capacity
                by_rid(y, :inv_cost_inverter_per_mwyr) * vDCCAP[y] +
                by_rid(y, :fixed_om_inverter_cost_per_mwyr) * eTotalCap_DC[y]
            else
                by_rid(y, :fixed_om_inverter_cost_per_mwyr) * eTotalCap_DC[y]
            end)

        # Sum individual resource contributions
        @expression(EP, eTotalCFixDC, sum(eCFixDC[y] for y in DC))

        if MultiStage == 1
            add_to_expression!(EP[:eObj], 1 / inputs["OPEXMULT"], eTotalCFixDC)
        else
            add_to_expression!(EP[:eObj], eTotalCFixDC)
        end

        # Constraints: Retirements and capacity additions
        # Cannot retire more capacity than existing capacity for VRE-STOR technologies
        @constraint(EP, cMaxRet_DC[y = RET_CAP_DC], vRETDCCAP[y]<=eExistingCapDC[y])

        # Constraint on maximum capacity (if applicable) [set input to -1 if no constraint on maximum capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is >= Max_Cap_MW and lead to infeasabilty
        @constraint(EP, cMaxCap_DC[y in ids_with_nonneg(gen_VRE_STOR, max_cap_inverter_mw)],
            EP[:eTotalCap_DC][y]<=by_rid(y, :max_cap_inverter_mw))
        # Constraint on Minimum capacity (if applicable) [set input to -1 if no constraint on minimum capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is <= Min_Cap_MW and lead to infeasabilty
        @constraint(EP, cMinCap_DC[y in ids_with_positive(gen_VRE_STOR, min_cap_inverter_mw)],
            eTotalCap_DC[y]>=by_rid(y, :min_cap_inverter_mw))
    end


    #########################################################################
    ### ADD SOLAR NEW CAP AND CONSTRAINTS/EXPRESSIONS ###
    #########################################################################
    if !isempty(SOLAR)
        ### SOLAR VARIABLES ###
        @variables(EP, begin
            vRETSOLARCAP[y in RET_CAP_SOLAR] >= 0                         # Retired solar capacity [MW DC]
            vSOLARCAP[y in NEW_CAP_SOLAR] >= 0                            # New installed solar capacity [MW DC]
        end)

        if MultiStage == 1
            @variable(EP, vEXISTINGSOLARCAP[y in SOLAR]>=0)
        end

        ### EXPRESSIONS ###

        # 0. Multistage existing capacity definition
        if MultiStage == 1
            @expression(EP, eExistingCapSolar[y in SOLAR], vEXISTINGSOLARCAP[y])
        else
            @expression(EP, eExistingCapSolar[y in SOLAR], by_rid(y, :existing_cap_solar_mw))
        end

        # Total solar capacity
        NEW_AND_RET_CAP_SOLAR = intersect(NEW_CAP_SOLAR, RET_CAP_SOLAR)
        NEW_NOT_RET_CAP_SOLAR = setdiff(NEW_CAP_SOLAR, RET_CAP_SOLAR)
        RET_NOT_NEW_CAP_SOLAR = setdiff(RET_CAP_SOLAR, NEW_CAP_SOLAR)
        @expression(EP, eTotalCap_SOLAR[y in SOLAR],
            if (y in NEW_AND_RET_CAP_SOLAR) # Resources eligible for new capacity and retirements
                eExistingCapSolar[y] + EP[:vSOLARCAP][y] - EP[:vRETSOLARCAP][y]
            elseif (y in NEW_NOT_RET_CAP_SOLAR) # Resources eligible for only new capacity
                eExistingCapSolar[y] + EP[:vSOLARCAP][y]
            elseif (y in RET_NOT_NEW_CAP_SOLAR) # Resources eligible for only capacity retirements
                eExistingCapSolar[y] - EP[:vRETSOLARCAP][y]
            else
                eExistingCapSolar[y]
            end)

        # Objective function additions

        # Fixed costs for solar resources (if resource is not eligible for new solar capacity, fixed costs are only O&M costs)
        @expression(EP, eCFixSolar[y in SOLAR],
            if y in NEW_CAP_SOLAR # Resources eligible for new capacity
                by_rid(y, :inv_cost_solar_per_mwyr) * vSOLARCAP[y] +
                by_rid(y, :fixed_om_solar_cost_per_mwyr) * eTotalCap_SOLAR[y]
            else
                by_rid(y, :fixed_om_solar_cost_per_mwyr) * eTotalCap_SOLAR[y]
            end)
        @expression(EP, eTotalCFixSolar, sum(eCFixSolar[y] for y in SOLAR))

        if MultiStage == 1
            add_to_expression!(EP[:eObj], 1 / inputs["OPEXMULT"], eTotalCFixSolar)
        else
            add_to_expression!(EP[:eObj], eTotalCFixSolar)
        end

        # Constraint: Existing capacity variable is equal to existing capacity specified in the input file
        if MultiStage == 1
            @constraint(EP,
                cExistingCapSolar[y in SOLAR],
                EP[:vEXISTINGSOLARCAP][y]==by_rid(y, :existing_cap_solar_mw))
        end

        # Constraint: Retirements and capacity additions
        # Cannot retire more capacity than existing capacity for VRE-STOR technologies
        @constraint(EP, cMaxRet_Solar[y = RET_CAP_SOLAR], vRETSOLARCAP[y]<=eExistingCapSolar[y])
        # Constraint on maximum capacity (if applicable) [set input to -1 if no constraint on maximum capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is >= Max_Cap_MW and lead to infeasabilty
        @constraint(EP, cMaxCap_Solar[y in ids_with_nonneg(gen_VRE_STOR, max_cap_solar_mw)],
            eTotalCap_SOLAR[y]<=by_rid(y, :max_cap_solar_mw))
        # Constraint on Minimum capacity (if applicable) [set input to -1 if no constraint on minimum capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is <= Min_Cap_MW and lead to infeasabilty
        @constraint(EP, cMinCap_Solar[y in ids_with_positive(gen_VRE_STOR, min_cap_solar_mw)],
            eTotalCap_SOLAR[y]>=by_rid(y, :min_cap_solar_mw))

        # Constraint: Inverter Ratio between solar capacity and grid
        @constraint(EP,
        cInverterRatio_Solar[y in ids_with_positive(gen_VRE_STOR, inverter_ratio_solar)],
        EP[:eTotalCap_SOLAR][y]==by_rid(y, :inverter_ratio_solar) * EP[:eTotalCap_DC][y])
    end

    #########################################################################
    ### ADD WIND NEW CAP AND CONSTRAINTS/EXPRESSIONS ###
    #########################################################################
    if !isempty(WIND)
        @variables(EP, begin
            # Wind capacity 
            vRETWINDCAP[y in RET_CAP_WIND] >= 0                         # Retired wind capacity [MW AC]
            vWINDCAP[y in NEW_CAP_WIND] >= 0                            # New installed wind capacity [MW AC]
        end)

        if MultiStage == 1
            @variable(EP, vEXISTINGWINDCAP[y in WIND]>=0)
        end

        ### EXPRESSIONS ###

        # 0. Multistage existing capacity definition
        if MultiStage == 1
            @expression(EP, eExistingCapWind[y in WIND], vEXISTINGWINDCAP[y])
        else
            @expression(EP, eExistingCapWind[y in WIND], by_rid(y, :existing_cap_wind_mw))
        end

        # Total wind capacity
        NEW_AND_RET_CAP_WIND = intersect(NEW_CAP_WIND, RET_CAP_WIND)
        NEW_NOT_RET_CAP_WIND = setdiff(NEW_CAP_WIND, RET_CAP_WIND)
        RET_NOT_NEW_CAP_WIND = setdiff(RET_CAP_WIND, NEW_CAP_WIND)
        @expression(EP, eTotalCap_WIND[y in WIND],
            if (y in NEW_AND_RET_CAP_WIND) # Resources eligible for new capacity and retirements
                eExistingCapWind[y] + EP[:vWINDCAP][y] - EP[:vRETWINDCAP][y]
            elseif (y in NEW_NOT_RET_CAP_WIND) # Resources eligible for only new capacity
                eExistingCapWind[y] + EP[:vWINDCAP][y]
            elseif (y in RET_NOT_NEW_CAP_WIND) # Resources eligible for only capacity retirements
                eExistingCapWind[y] - EP[:vRETWINDCAP][y]
            else
                eExistingCapWind[y]
            end)

        # Objective function additions

        # Fixed costs for wind resources (if resource is not eligible for new wind capacity, fixed costs are only O&M costs)
        @expression(EP, eCFixWind[y in WIND],
            if y in NEW_CAP_WIND # Resources eligible for new capacity
                by_rid(y, :inv_cost_wind_per_mwyr) * vWINDCAP[y] +
                by_rid(y, :fixed_om_wind_cost_per_mwyr) * eTotalCap_WIND[y]
            else
                by_rid(y, :fixed_om_wind_cost_per_mwyr) * eTotalCap_WIND[y]
            end)
        @expression(EP, eTotalCFixWind, sum(eCFixWind[y] for y in WIND))

        if MultiStage == 1
            add_to_expression!(EP[:eObj], 1 / inputs["OPEXMULT"], eTotalCFixWind)
        else
            add_to_expression!(EP[:eObj], eTotalCFixWind)
        end

        ### CONSTRAINTS ###
        # Constraint: Existing capacity variable is equal to existing capacity specified in the input file
        if MultiStage == 1
            @constraint(EP,
                cExistingCapWind[y in WIND],
                EP[:vEXISTINGWINDCAP][y]==by_rid(y, :existing_cap_wind_mw))
        end

        # Constraints: Retirements and capacity additions
        # Cannot retire more capacity than existing capacity for VRE-STOR technologies
        @constraint(EP, cMaxRet_Wind[y = RET_CAP_WIND], vRETWINDCAP[y]<=eExistingCapWind[y])
        # Constraint on maximum capacity (if applicable) [set input to -1 if no constraint on maximum capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is >= Max_Cap_MW and lead to infeasabilty
        @constraint(EP, cMaxCap_Wind[y in ids_with_nonneg(gen_VRE_STOR, max_cap_wind_mw)],
            eTotalCap_WIND[y]<=by_rid(y, :max_cap_wind_mw))
        # Constraint on Minimum capacity (if applicable) [set input to -1 if no constraint on minimum capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is <= Min_Cap_MW and lead to infeasabilty
        @constraint(EP, cMinCap_Wind[y in ids_with_positive(gen_VRE_STOR, min_cap_wind_mw)],
            eTotalCap_WIND[y]>=by_rid(y, :min_cap_wind_mw))

        # Constraint: Wind Generation: see main module because capacity reserve margin/operating reserves may alter constraint

        # Constraint: Inverter Ratio between wind capacity and grid
        @constraint(EP,
            cInverterRatio_Wind[y in ids_with_positive(gen_VRE_STOR, inverter_ratio_wind)],
            EP[:eTotalCap_WIND][y]==by_rid(y, :inverter_ratio_wind) * EP[:eTotalCap][y])
    end

    #########################################################################
    ### ADD STOR NEW CAP AND CONSTRAINTS/EXPRESSIONS ###
    #########################################################################
    if !isempty(STOR)
        ### Variables ###
        @variables(EP, begin
            # Storage energy capacity
            vCAPENERGY_VS[y in NEW_CAP_STOR] >= 0              # Energy storage reservoir capacity (MWh capacity) built for VRE storage [MWh]
            vRETCAPENERGY_VS[y in RET_CAP_STOR] >= 0           # Energy storage reservoir capacity retired for VRE storage [MWh]
        end)

        if MultiStage == 1
            @variable(EP, vEXISTINGCAPENERGY_VS[y in STOR]>=0)
        end
        
        # 0. Multistage existing capacity definition
        if MultiStage == 1
            @expression(EP, eExistingCapEnergy_VS[y in STOR], vEXISTINGCAPENERGY_VS[y])
        else
            @expression(EP, eExistingCapEnergy_VS[y in STOR], existing_cap_mwh(gen[y]))
        end

        # 1. Total storage energy capacity
        NEW_AND_RET_CAP_STOR = intersect(NEW_CAP_STOR, RET_CAP_STOR)
        NEW_NOT_RET_CAP_STOR = setdiff(NEW_CAP_STOR, RET_CAP_STOR)
        RET_NOT_NEW_CAP_STOR = setdiff(RET_CAP_STOR, NEW_CAP_STOR)
        @expression(EP, eTotalCap_STOR[y in STOR],
            if (y in NEW_AND_RET_CAP_STOR) # Resources eligible for new capacity and retirements
                eExistingCapEnergy_VS[y] + EP[:vCAPENERGY_VS][y] - EP[:vRETCAPENERGY_VS][y]
            elseif (y in NEW_NOT_RET_CAP_STOR) # Resources eligible for only new capacity
                eExistingCapEnergy_VS[y] + EP[:vCAPENERGY_VS][y]
            elseif (y in RET_NOT_NEW_CAP_STOR) # Resources eligible for only capacity retirements
                eExistingCapEnergy_VS[y] - EP[:vRETCAPENERGY_VS][y]
            else
                eExistingCapEnergy_VS[y]
            end
        )

        # 2. Objective function additions
        # Fixed costs for storage resources (if resource is not eligible for new energy capacity, fixed costs are only O&M costs)
        @expression(EP, eCFixEnergy_VS[y in STOR],
            if y in NEW_CAP_STOR # Resources eligible for new capacity
                inv_cost_per_mwhyr(gen[y]) * vCAPENERGY_VS[y] +
                fixed_om_cost_per_mwhyr(gen[y]) * eTotalCap_STOR[y]
            else
                fixed_om_cost_per_mwhyr(gen[y]) * eTotalCap_STOR[y]
            end)
        @expression(EP, eTotalCFixStor, sum(eCFixEnergy_VS[y] for y in STOR))

        if MultiStage == 1
            add_to_expression!(EP[:eObj], 1 / inputs["OPEXMULT"], eTotalCFixStor)
        else
            add_to_expression!(EP[:eObj], eTotalCFixStor)
        end

        # Constraint: Existing capacity variable is equal to existing capacity specified in the input file
        if MultiStage == 1
            @constraint(EP,
                cExistingCapEnergy_VS[y in STOR],
                EP[:vEXISTINGCAPENERGY_VS][y]==existing_cap_mwh(gen[y]))
        end

        # Constraints: Retirements and capacity additions
        # Cannot retire more capacity than existing capacity for VRE-STOR technologies
        @constraint(EP,
            cMaxRet_Stor[y = RET_CAP_STOR],
            vRETCAPENERGY_VS[y]<=eExistingCapEnergy_VS[y])
        # Constraint on maximum capacity (if applicable) [set input to -1 if no constraint on maximum capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is >= Max_Cap_MW and lead to infeasabilty
        @constraint(EP, cMaxCap_Stor[y in intersect(ids_with_nonneg(gen, max_cap_mwh), STOR)],
            eTotalCap_STOR[y]<=max_cap_mwh(gen[y]))
        # Constraint on minimum capacity (if applicable) [set input to -1 if no constraint on minimum capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is <= Min_Cap_MW and lead to infeasabilty
        @constraint(EP, cMinCap_Stor[y in intersect(ids_with_positive(gen, min_cap_mwh), STOR)],
            eTotalCap_STOR[y]>=min_cap_mwh(gen[y]))

        ### ASYMMETRIC RESOURCE MODULE ###
        if !isempty(inputs["VS_ASYM"])
            investment_charge_vre_stor!(EP, inputs, setup)
        end

        if rep_periods > 1 && !isempty(VS_LDS) && setup["Benders"] == 1
            lds_vre_stor_planning!(EP, inputs)
            if setup["CapacityReserveMargin"] > 0
                lds_vre_stor_capres_planning!(EP, inputs)
            end
        end
    end

    #########################################################################
    ### ADD ELECTROLYZER NEW CAP AND CONSTRAINTS/EXPRESSIONS ###
    #########################################################################
    if !isempty(ELEC)
        ### ELEC VARIABLES ###
        @variables(EP, begin
            # Electrolyzer capacity 
            vRETELECCAP[y in RET_CAP_ELEC] >= 0                         # Retired electrolyzer capacity [MW AC]
            vELECCAP[y in NEW_CAP_ELEC] >= 0                            # New installed electrolyzer capacity [MW AC]
        end)

        if MultiStage == 1
            @variable(EP, vEXISTINGELECCAP[y in ELEC]>=0)
        end

        ### EXPRESSIONS ###
        # Multistage existing capacity definition
        if MultiStage == 1
            @expression(EP, eExistingCapElec[y in ELEC], vEXISTINGELECCAP[y])
        else
            @expression(EP, eExistingCapElec[y in ELEC], by_rid(y, :existing_cap_elec_mw))
        end

        # Total electrolyzer capacity
        NEW_AND_RET_CAP_ELEC = intersect(NEW_CAP_ELEC, RET_CAP_ELEC)
        NEW_NOT_RET_CAP_ELEC = setdiff(NEW_CAP_ELEC, RET_CAP_ELEC)
        RET_NOT_NEW_CAP_ELEC = setdiff(RET_CAP_ELEC, NEW_CAP_ELEC)
        @expression(EP, eTotalCap_ELEC[y in ELEC],
            if (y in NEW_AND_RET_CAP_ELEC) # Resources eligible for new capacity and retirements
                eExistingCapElec[y] + EP[:vELECCAP][y] - EP[:vRETELECCAP][y]
            elseif (y in NEW_NOT_RET_CAP_ELEC) # Resources eligible for only new capacity
                eExistingCapElec[y] + EP[:vELECCAP][y]
            elseif (y in RET_NOT_NEW_CAP_ELEC) # Resources eligible for only capacity retirements
                eExistingCapElec[y] - EP[:vRETELECCAP][y]
            else
                eExistingCapElec[y]
            end)

        # Objective function additions
        # Fixed costs for electrolyzer resources (if resource is not eligible for new electrolyzer capacity, fixed costs are only O&M costs)
        @expression(EP, eCFixElec[y in ELEC],
            if y in NEW_CAP_ELEC # Resources eligible for new capacity
                by_rid(y, :inv_cost_elec_per_mwyr) * vELECCAP[y] +
                by_rid(y, :fixed_om_elec_cost_per_mwyr) * eTotalCap_ELEC[y]
            else
                by_rid(y, :fixed_om_elec_cost_per_mwyr) * eTotalCap_ELEC[y]
            end)
        @expression(EP, eTotalCFixElec, sum(eCFixElec[y] for y in ELEC))

        if MultiStage == 1
            add_to_expression!(EP[:eObj], 1 / inputs["OPEXMULT"], eTotalCFixElec)
        else
            add_to_expression!(EP[:eObj], eTotalCFixElec)
        end

        # Constraint 0: Existing capacity variable is equal to existing capacity specified in the input file
        if MultiStage == 1
            @constraint(EP, cExistingCapElec[y in ELEC],
                EP[:vEXISTINGELECCAP][y]==by_rid(y, :existing_cap_elec_mw))
        end

        ### CONSTRAINTS ###
        # Constraints: Retirements and capacity additions
        # Cannot retire more capacity than existing capacity for VRE-STOR technologies
        @constraint(EP, cMaxRet_Elec[y = RET_CAP_ELEC], vRETELECCAP[y]<=eExistingCapElec[y])
        # Constraint on maximum capacity (if applicable) [set input to -1 if no constraint on maximum capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is >= Max_Cap_MW and lead to infeasabilty
        @constraint(EP, cMaxCap_Elec[y in ids_with_nonneg(gen_VRE_STOR, max_cap_elec_mw)],
            eTotalCap_ELEC[y]<=by_rid(y, :max_cap_elec_mw))
        # Constraint on Minimum capacity (if applicable) [set input to -1 if no constraint on minimum capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is <= Min_Cap_MW and lead to infeasabilty
        @constraint(EP, cMinCap_Elec[y in ids_with_positive(gen_VRE_STOR, min_cap_elec_mw)],
            eTotalCap_ELEC[y]>=by_rid(y, :min_cap_elec_mw))
    end

    # Minimum Capacity Requirement
    if MinCapReq == 1
        @expression(EP, eMinCapResSolar[mincap = 1:inputs["NumberOfMinCapReqs"]],
            sum(by_rid(y, :etainverter) * EP[:eTotalCap_SOLAR][y]
            for y in intersect(SOLAR,
                ids_with_policy(gen_VRE_STOR, min_cap_solar, tag = mincap))))
        add_similar_to_expression!(EP[:eMinCapRes], eMinCapResSolar)

        @expression(EP, eMinCapResWind[mincap = 1:inputs["NumberOfMinCapReqs"]],
            sum(EP[:eTotalCap_WIND][y]
            for y in intersect(WIND,
                ids_with_policy(gen_VRE_STOR, min_cap_wind, tag = mincap))))
        add_similar_to_expression!(EP[:eMinCapRes], eMinCapResWind)


        if !isempty(inputs["VS_ASYM_AC_DISCHARGE"])
            @expression(EP, eMinCapResACDis[mincap = 1:inputs["NumberOfMinCapReqs"]],
                sum(EP[:eTotalCapDischarge_AC][y]
                for y in intersect(inputs["VS_ASYM_AC_DISCHARGE"],
                    ids_with_policy(gen_VRE_STOR, min_cap_stor, tag = mincap))))
            add_similar_to_expression!(EP[:eMinCapRes], eMinCapResACDis)
        end

        if !isempty(inputs["VS_ASYM_DC_DISCHARGE"])
            @expression(EP, eMinCapResDCDis[mincap = 1:inputs["NumberOfMinCapReqs"]],
                sum(EP[:eTotalCapDischarge_DC][y]
                for y in intersect(inputs["VS_ASYM_DC_DISCHARGE"],
                    ids_with_policy(gen_VRE_STOR, min_cap_stor, tag = mincap))))
            add_similar_to_expression!(EP[:eMinCapRes], eMinCapResDCDis)
        end

        if !isempty(inputs["VS_SYM_AC"])
            @expression(EP, eMinCapResACStor[mincap = 1:inputs["NumberOfMinCapReqs"]],
                sum(by_rid(y, :power_to_energy_ac) * EP[:eTotalCap_STOR][y]
                for y in intersect(inputs["VS_SYM_AC"],
                    ids_with_policy(gen_VRE_STOR, min_cap_stor, tag = mincap))))
            add_similar_to_expression!(EP[:eMinCapRes], eMinCapResACStor)
        end

        if !isempty(inputs["VS_SYM_DC"])
            @expression(EP, eMinCapResDCStor[mincap = 1:inputs["NumberOfMinCapReqs"]],
                sum(by_rid(y, :power_to_energy_dc) * EP[:eTotalCap_STOR][y]
                for y in intersect(inputs["VS_SYM_DC"],
                    ids_with_policy(gen_VRE_STOR, min_cap_stor, tag = mincap))))
            add_similar_to_expression!(EP[:eMinCapRes], eMinCapResDCStor)
        end
    end

    # Maximum Capacity Requirement
    if MaxCapReq == 1
        @expression(EP, eMaxCapResSolar[maxcap = 1:inputs["NumberOfMaxCapReqs"]],
            sum(by_rid(y, :etainverter) * EP[:eTotalCap_SOLAR][y]
            for y in intersect(SOLAR,
                ids_with_policy(gen_VRE_STOR, max_cap_solar, tag = maxcap))))
        add_similar_to_expression!(EP[:eMaxCapRes], eMaxCapResSolar)

        @expression(EP, eMaxCapResWind[maxcap = 1:inputs["NumberOfMaxCapReqs"]],
            sum(EP[:eTotalCap_WIND][y]
            for y in intersect(WIND,
                ids_with_policy(gen_VRE_STOR, max_cap_wind, tag = maxcap))))
        add_similar_to_expression!(EP[:eMaxCapRes], eMaxCapResWind)

        if !isempty(inputs["VS_ASYM_AC_DISCHARGE"])
            @expression(EP, eMaxCapResACDis[maxcap = 1:inputs["NumberOfMaxCapReqs"]],
                sum(EP[:eTotalCapDischarge_AC][y]
                for y in intersect(inputs["VS_ASYM_AC_DISCHARGE"],
                    ids_with_policy(gen_VRE_STOR, max_cap_stor, tag = maxcap))))
            add_similar_to_expression!(EP[:eMaxCapRes], eMaxCapResACDis)
        end

        if !isempty(inputs["VS_ASYM_DC_DISCHARGE"])
            @expression(EP, eMaxCapResDCDis[maxcap = 1:inputs["NumberOfMaxCapReqs"]],
                sum(EP[:eTotalCapDischarge_DC][y]
                for y in intersect(inputs["VS_ASYM_DC_DISCHARGE"],
                    ids_with_policy(gen_VRE_STOR, max_cap_stor, tag = maxcap))))
            add_similar_to_expression!(EP[:eMaxCapRes], eMaxCapResDCDis)
        end

        if !isempty(inputs["VS_SYM_AC"])
            @expression(EP, eMaxCapResACStor[maxcap = 1:inputs["NumberOfMaxCapReqs"]],
                sum(by_rid(y, :power_to_energy_ac) * EP[:eTotalCap_STOR][y]
                for y in intersect(inputs["VS_SYM_AC"],
                    ids_with_policy(gen_VRE_STOR, max_cap_stor, tag = maxcap))))
            add_similar_to_expression!(EP[:eMaxCapRes], eMaxCapResACStor)
        end

        if !isempty(inputs["VS_SYM_DC"])
            @expression(EP, eMaxCapResDCStor[maxcap = 1:inputs["NumberOfMaxCapReqs"]],
                sum(by_rid(y, :power_to_energy_dc) * EP[:eTotalCap_STOR][y]
                for y in intersect(inputs["VS_SYM_DC"],
                    ids_with_policy(gen_VRE_STOR, max_cap_stor, tag = maxcap))))
            add_similar_to_expression!(EP[:eMaxCapRes], eMaxCapResDCStor)
        end
    end

end


@doc raw"""
    investment_charge_vre_stor!(EP::Model, inputs::Dict, setup::Dict)

This planning-stage helper creates asymmetric storage charge/discharge capacity build and
retirement variables and associated total-capacity expressions for:

- DC discharge (`eTotalCapDischarge_DC`)
- DC charge (`eTotalCapCharge_DC`)
- AC discharge (`eTotalCapDischarge_AC`)
- AC charge (`eTotalCapCharge_AC`)

For each direction $k$ in this set, the model uses:

```math
\Delta^{\text{tot},k}_{y} = \overline{\Delta}^{k}_{y} + \Omega^{k}_{y} - \Delta^{\text{ret},k}_{y}
```

with subset-specific logic when a resource is only eligible for new build or only retirement.

The objective contribution for each direction follows:

```math
\sum_y \left(\pi^{\text{INV},k}_{y}\,\Omega^{k}_{y} + \pi^{\text{FOM},k}_{y}\,\Delta^{\text{tot},k}_{y}\right)
```

with O&M scaling by `1/OPEXMULT` in multi-stage mode, matching the implementation.

Capacity bounds enforced when provided:

```math
\Delta^{\text{ret},k}_{y} \le \overline{\Delta}^{k}_{y},
\qquad
\underline{\Delta}^{k}_{y} \le \Delta^{\text{tot},k}_{y} \le \overline{\Delta}^{k}_{y}
```

where existing-capacity equalities are also added for multi-stage mode.
"""
function investment_charge_vre_stor!(EP::Model, inputs::Dict, setup::Dict)
    println("VRE-STOR Charge Investment Module")

    ### LOAD INPUTS ###
    gen = inputs["RESOURCES"]
    gen_VRE_STOR = gen.VreStorage

    T = inputs["T"]
    VS_ASYM_DC_CHARGE = inputs["VS_ASYM_DC_CHARGE"]
    VS_ASYM_AC_CHARGE = inputs["VS_ASYM_AC_CHARGE"]
    VS_ASYM_DC_DISCHARGE = inputs["VS_ASYM_DC_DISCHARGE"]
    VS_ASYM_AC_DISCHARGE = inputs["VS_ASYM_AC_DISCHARGE"]

    NEW_CAP_CHARGE_DC = inputs["NEW_CAP_CHARGE_DC"]
    RET_CAP_CHARGE_DC = inputs["RET_CAP_CHARGE_DC"]
    NEW_CAP_CHARGE_AC = inputs["NEW_CAP_CHARGE_AC"]
    RET_CAP_CHARGE_AC = inputs["RET_CAP_CHARGE_AC"]
    NEW_CAP_DISCHARGE_DC = inputs["NEW_CAP_DISCHARGE_DC"]
    RET_CAP_DISCHARGE_DC = inputs["RET_CAP_DISCHARGE_DC"]
    NEW_CAP_DISCHARGE_AC = inputs["NEW_CAP_DISCHARGE_AC"]
    RET_CAP_DISCHARGE_AC = inputs["RET_CAP_DISCHARGE_AC"]

    MultiStage = setup["MultiStage"]

    by_rid(rid, sym) = by_rid_res(rid, sym, gen_VRE_STOR)

    if !isempty(VS_ASYM_DC_DISCHARGE)
        MAX_DC_DISCHARGE = intersect(
            ids_with_nonneg(gen_VRE_STOR, max_cap_discharge_dc_mw),
            VS_ASYM_DC_DISCHARGE)
        MIN_DC_DISCHARGE = intersect(
            ids_with_positive(gen_VRE_STOR,
                min_cap_discharge_dc_mw),
            VS_ASYM_DC_DISCHARGE)

        ### VARIABLES ###
        @variables(EP, begin
            vCAPDISCHARGE_DC[y in NEW_CAP_DISCHARGE_DC] >= 0            # Discharge capacity DC component built for VRE storage [MW]
            vRETCAPDISCHARGE_DC[y in RET_CAP_DISCHARGE_DC] >= 0         # Discharge capacity DC component retired for VRE storage [MW]
        end)

        if MultiStage == 1
            @variable(EP, vEXISTINGCAPDISCHARGEDC[y in VS_ASYM_DC_DISCHARGE]>=0)
        end

        ### EXPRESSIONS ###

        # 0. Multistage existing capacity definition
        if MultiStage == 1
            @expression(EP,
                eExistingCapDischargeDC[y in VS_ASYM_DC_DISCHARGE],
                vEXISTINGCAPDISCHARGEDC[y])
        else
            @expression(EP,
                eExistingCapDischargeDC[y in VS_ASYM_DC_DISCHARGE],
                by_rid(y, :existing_cap_discharge_dc_mw))
        end

        # 1. Total storage discharge DC capacity
        NEW_AND_RET_CAP_DISCHARGE_DC = intersect(NEW_CAP_DISCHARGE_DC, RET_CAP_DISCHARGE_DC)
        NEW_NOT_RET_CAP_DISCHARGE_DC = setdiff(NEW_CAP_DISCHARGE_DC, RET_CAP_DISCHARGE_DC)
        RET_NOT_NEW_CAP_DISCHARGE_DC = setdiff(RET_CAP_DISCHARGE_DC, NEW_CAP_DISCHARGE_DC)
        @expression(EP, eTotalCapDischarge_DC[y in VS_ASYM_DC_DISCHARGE],
            if (y in NEW_AND_RET_CAP_DISCHARGE_DC)
                eExistingCapDischargeDC[y] + EP[:vCAPDISCHARGE_DC][y] -
                EP[:vRETCAPDISCHARGE_DC][y]
            elseif (y in NEW_NOT_RET_CAP_DISCHARGE_DC)
                eExistingCapDischargeDC[y] + EP[:vCAPDISCHARGE_DC][y]
            elseif (y in RET_NOT_NEW_CAP_DISCHARGE_DC)
                eExistingCapDischargeDC[y] - EP[:vRETCAPDISCHARGE_DC][y]
            else
                eExistingCapDischargeDC[y]
            end)

        # 2. Objective Function Additions

        # If resource is not eligible for new discharge DC capacity, fixed costs are only O&M costs
        @expression(EP, eCFixDischarge_DC[y in VS_ASYM_DC_DISCHARGE],
            if y in NEW_CAP_DISCHARGE_DC # Resources eligible for new discharge DC capacity
                by_rid(y, :inv_cost_discharge_dc_per_mwyr) * vCAPDISCHARGE_DC[y] +
                by_rid(y, :fixed_om_cost_discharge_dc_per_mwyr) * eTotalCapDischarge_DC[y]
            else
                by_rid(y, :fixed_om_cost_discharge_dc_per_mwyr) * eTotalCapDischarge_DC[y]
            end)

        # Sum individual resource contributions to fixed costs to get total fixed costs
        @expression(EP,
            eTotalCFixDischarge_DC,
            sum(EP[:eCFixDischarge_DC][y] for y in VS_ASYM_DC_DISCHARGE))

        if MultiStage == 1
            add_to_expression!(EP[:eObj], 1 / inputs["OPEXMULT"], eTotalCFixDischarge_DC)
        else
            add_to_expression!(EP[:eObj], eTotalCFixDischarge_DC)
        end

        ### CONSTRAINTS ###

        # Constraint 0: Existing capacity variable is equal to existing capacity specified in the input file
        if MultiStage == 1
            @constraint(EP,
                cExistingCapDischargeDC[y in VS_ASYM_DC_DISCHARGE],
                EP[:vEXISTINGCAPDISCHARGEDC][y]==by_rid(y, :existing_cap_discharge_dc_mw))
        end

        # Constraints 1: Retirements and capacity additions
        # Cannot retire more discharge DC capacity than existing discharge capacity
        @constraint(EP,
            cVreStorMaxRetDischargeDC[y in RET_CAP_DISCHARGE_DC],
            vRETCAPDISCHARGE_DC[y]<=eExistingCapDischargeDC[y])
        # Constraint on maximum discharge DC capacity (if applicable) [set input to -1 if no constraint on maximum discharge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is >= Max_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP,
            cVreStorMaxCapDischargeDC[y in MAX_DC_DISCHARGE],
            eTotalCapDischarge_DC[y]<=by_rid(y, :Max_Cap_Discharge_DC_MW))
        # Constraint on minimum discharge DC capacity (if applicable) [set input to -1 if no constraint on minimum discharge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is <= Min_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP,
            cVreStorMinCapDischargeDC[y in MIN_DC_DISCHARGE],
            eTotalCapDischarge_DC[y]>=by_rid(y, :Min_Cap_Discharge_DC_MW))        
    end

    if !isempty(VS_ASYM_DC_CHARGE)
        MAX_DC_CHARGE = intersect(ids_with_nonneg(gen_VRE_STOR, max_cap_charge_dc_mw),
            VS_ASYM_DC_CHARGE)
        MIN_DC_CHARGE = intersect(ids_with_positive(gen_VRE_STOR, min_cap_charge_dc_mw),
            VS_ASYM_DC_CHARGE)

        ### VARIABLES ###
        @variables(EP, begin
            vCAPCHARGE_DC[y in NEW_CAP_CHARGE_DC] >= 0               # Charge capacity DC component built for VRE storage [MW]
            vRETCAPCHARGE_DC[y in RET_CAP_CHARGE_DC] >= 0            # Charge capacity DC component retired for VRE storage [MW]
        end)

        if MultiStage == 1
            @variable(EP, vEXISTINGCAPCHARGEDC[y in VS_ASYM_DC_CHARGE]>=0)
        end

        ### EXPRESSIONS ###

        # 0. Multistage existing capacity definition
        if MultiStage == 1
            @expression(EP,
                eExistingCapChargeDC[y in VS_ASYM_DC_CHARGE],
                vEXISTINGCAPCHARGEDC[y])
        else
            @expression(EP,
                eExistingCapChargeDC[y in VS_ASYM_DC_CHARGE],
                by_rid(y, :existing_cap_charge_dc_mw))
        end

        # 1. Total storage charge DC capacity
        NEW_AND_RET_CAP_CHARGE_DC = intersect(NEW_CAP_CHARGE_DC, RET_CAP_CHARGE_DC)
        NEW_NOT_RET_CAP_CHARGE_DC = setdiff(NEW_CAP_CHARGE_DC, RET_CAP_CHARGE_DC)
        RET_NOT_NEW_CAP_CHARGE_DC = setdiff(RET_CAP_CHARGE_DC, NEW_CAP_CHARGE_DC)
        @expression(EP, eTotalCapCharge_DC[y in VS_ASYM_DC_CHARGE],
            if (y in NEW_AND_RET_CAP_CHARGE_DC)
                eExistingCapChargeDC[y] + EP[:vCAPCHARGE_DC][y] - EP[:vRETCAPCHARGE_DC][y]
            elseif (y in NEW_NOT_RET_CAP_CHARGE_DC)
                eExistingCapChargeDC[y] + EP[:vCAPCHARGE_DC][y]
            elseif (y in RET_NOT_NEW_CAP_CHARGE_DC)
                eExistingCapChargeDC[y] - EP[:vRETCAPCHARGE_DC][y]
            else
                eExistingCapChargeDC[y]
            end)

        # 2. Objective Function Additions

        # If resource is not eligible for new charge DC capacity, fixed costs are only O&M costs
        @expression(EP, eCFixCharge_DC[y in VS_ASYM_DC_CHARGE],
            if y in NEW_CAP_CHARGE_DC # Resources eligible for new charge DC capacity
                by_rid(y, :inv_cost_charge_dc_per_mwyr) * vCAPCHARGE_DC[y] +
                by_rid(y, :fixed_om_cost_charge_dc_per_mwyr) * eTotalCapCharge_DC[y]
            else
                by_rid(y, :fixed_om_cost_charge_dc_per_mwyr) * eTotalCapCharge_DC[y]
            end)

        # Sum individual resource contributions to fixed costs to get total fixed costs
        @expression(EP,
            eTotalCFixCharge_DC,
            sum(EP[:eCFixCharge_DC][y] for y in VS_ASYM_DC_CHARGE))

        if MultiStage == 1
            add_to_expression!(EP[:eObj], 1 / inputs["OPEXMULT"], eTotalCFixCharge_DC)
        else
            add_to_expression!(EP[:eObj], eTotalCFixCharge_DC)
        end

        ### CONSTRAINTS ###

        # Constraint 0: Existing capacity variable is equal to existing capacity specified in the input file
        if MultiStage == 1
            @constraint(EP,
                cExistingCapChargeDC[y in VS_ASYM_DC_CHARGE],
                EP[:vEXISTINGCAPCHARGEDC][y]==by_rid(y, :Existing_Cap_Charge_DC_MW))
        end

        # Constraints 1: Retirements and capacity additions
        # Cannot retire more charge DC capacity than existing charge capacity
        @constraint(EP,
            cVreStorMaxRetChargeDC[y in RET_CAP_CHARGE_DC],
            vRETCAPCHARGE_DC[y]<=eExistingCapChargeDC[y])
        # Constraint on maximum charge DC capacity (if applicable) [set input to -1 if no constraint on maximum charge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is >= Max_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP,
            cVreStorMaxCapChargeDC[y in MAX_DC_CHARGE],
            eTotalCapCharge_DC[y]<=by_rid(y, :max_cap_charge_dc_mw))
        # Constraint on minimum charge DC capacity (if applicable) [set input to -1 if no constraint on minimum charge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is <= Min_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP,
            cVreStorMinCapChargeDC[y in MIN_DC_CHARGE],
            eTotalCapCharge_DC[y]>=by_rid(y, :min_cap_charge_dc_mw))
    end

    if !isempty(VS_ASYM_AC_DISCHARGE)
        MAX_AC_DISCHARGE = intersect(
            ids_with_nonneg(gen_VRE_STOR, max_cap_discharge_ac_mw),
            VS_ASYM_AC_DISCHARGE)
        MIN_AC_DISCHARGE = intersect(
            ids_with_positive(gen_VRE_STOR,
                min_cap_discharge_ac_mw),
            VS_ASYM_AC_DISCHARGE)

        ### VARIABLES ###
        @variables(EP, begin
            vCAPDISCHARGE_AC[y in NEW_CAP_DISCHARGE_AC] >= 0            # Discharge capacity AC component built for VRE storage [MW]
            vRETCAPDISCHARGE_AC[y in RET_CAP_DISCHARGE_AC] >= 0         # Discharge capacity AC component retired for VRE storage [MW]
        end)

        if MultiStage == 1
            @variable(EP, vEXISTINGCAPDISCHARGEAC[y in VS_ASYM_AC_DISCHARGE]>=0)
        end

        ### EXPRESSIONS ###

        # 0. Multistage existing capacity definition
        if MultiStage == 1
            @expression(EP,
                eExistingCapDischargeAC[y in VS_ASYM_AC_DISCHARGE],
                vEXISTINGCAPDISCHARGEAC[y])
        else
            @expression(EP,
                eExistingCapDischargeAC[y in VS_ASYM_AC_DISCHARGE],
                by_rid(y, :existing_cap_discharge_ac_mw))
        end

        # 1. Total storage discharge AC capacity
        NEW_AND_RET_CAP_DISCHARGE_AC = intersect(NEW_CAP_DISCHARGE_AC, RET_CAP_DISCHARGE_AC)
        NEW_NOT_RET_CAP_DISCHARGE_AC = setdiff(NEW_CAP_DISCHARGE_AC, RET_CAP_DISCHARGE_AC)
        RET_NOT_NEW_CAP_DISCHARGE_AC = setdiff(RET_CAP_DISCHARGE_AC, NEW_CAP_DISCHARGE_AC)
        @expression(EP, eTotalCapDischarge_AC[y in VS_ASYM_AC_DISCHARGE],
            if (y in NEW_AND_RET_CAP_DISCHARGE_AC)
                eExistingCapDischargeAC[y] + EP[:vCAPDISCHARGE_AC][y] -
                EP[:vRETCAPDISCHARGE_AC][y]
            elseif (y in NEW_NOT_RET_CAP_DISCHARGE_AC)
                eExistingCapDischargeAC[y] + EP[:vCAPDISCHARGE_AC][y]
            elseif (y in RET_NOT_NEW_CAP_DISCHARGE_AC)
                eExistingCapDischargeAC[y] - EP[:vRETCAPDISCHARGE_AC][y]
            else
                eExistingCapDischargeAC[y]
            end)

        # 2. Objective Function Additions

        # If resource is not eligible for new discharge AC capacity, fixed costs are only O&M costs
        @expression(EP, eCFixDischarge_AC[y in VS_ASYM_AC_DISCHARGE],
            if y in NEW_CAP_DISCHARGE_AC # Resources eligible for new discharge AC capacity
                by_rid(y, :inv_cost_discharge_ac_per_mwyr) * vCAPDISCHARGE_AC[y] +
                by_rid(y, :fixed_om_cost_discharge_ac_per_mwyr) * eTotalCapDischarge_AC[y]
            else
                by_rid(y, :fixed_om_cost_discharge_ac_per_mwyr) * eTotalCapDischarge_AC[y]
            end)

        # Sum individual resource contributions to fixed costs to get total fixed costs
        @expression(EP,
            eTotalCFixDischarge_AC,
            sum(EP[:eCFixDischarge_AC][y] for y in VS_ASYM_AC_DISCHARGE))

        if MultiStage == 1
            add_to_expression!(EP[:eObj], 1 / inputs["OPEXMULT"], eTotalCFixDischarge_AC)
        else
            add_to_expression!(EP[:eObj], eTotalCFixDischarge_AC)
        end

        ### CONSTRAINTS ###

        # Constraint 0: Existing capacity variable is equal to existing capacity specified in the input file
        if MultiStage == 1
            @constraint(EP,
                cExistingCapDischargeAC[y in VS_ASYM_AC_DISCHARGE],
                EP[:vEXISTINGCAPDISCHARGEAC][y]==by_rid(y, :existing_cap_discharge_ac_mw))
        end

        # Constraints 1: Retirements and capacity additions
        # Cannot retire more discharge AC capacity than existing charge capacity
        @constraint(EP,
            cVreStorMaxRetDischargeAC[y in RET_CAP_DISCHARGE_AC],
            vRETCAPDISCHARGE_AC[y]<=eExistingCapDischargeAC[y])
        # Constraint on maximum discharge AC capacity (if applicable) [set input to -1 if no constraint on maximum charge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is >= Max_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP,
            cVreStorMaxCapDischargeAC[y in MAX_AC_DISCHARGE],
            eTotalCapDischarge_AC[y]<=by_rid(y, :max_cap_discharge_ac_mw))
        # Constraint on minimum discharge AC capacity (if applicable) [set input to -1 if no constraint on minimum charge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is <= Min_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP,
            cVreStorMinCapDischargeAC[y in MIN_AC_DISCHARGE],
            eTotalCapDischarge_AC[y]>=by_rid(y, :min_cap_discharge_ac_mw))
    end

    if !isempty(VS_ASYM_AC_CHARGE)
        MAX_AC_CHARGE = intersect(ids_with_nonneg(gen_VRE_STOR, max_cap_charge_ac_mw),
            VS_ASYM_AC_CHARGE)
        MIN_AC_CHARGE = intersect(ids_with_positive(gen_VRE_STOR, min_cap_charge_ac_mw),
            VS_ASYM_AC_CHARGE)

        ### VARIABLES ###
        @variables(EP, begin
            vCAPCHARGE_AC[y in NEW_CAP_CHARGE_AC] >= 0               # Charge capacity AC component built for VRE storage [MW]
            vRETCAPCHARGE_AC[y in RET_CAP_CHARGE_AC] >= 0            # Charge capacity AC component retired for VRE storage [MW]
        end)

        if MultiStage == 1
            @variable(EP, vEXISTINGCAPCHARGEAC[y in VS_ASYM_AC_CHARGE]>=0)
        end

        ### EXPRESSIONS ###

        # 0. Multistage existing capacity definition
        if MultiStage == 1
            @expression(EP,
                eExistingCapChargeAC[y in VS_ASYM_AC_CHARGE],
                vEXISTINGCAPCHARGEAC[y])
        else
            @expression(EP,
                eExistingCapChargeAC[y in VS_ASYM_AC_CHARGE],
                by_rid(y, :existing_cap_charge_ac_mw))
        end

        # 1. Total storage charge AC capacity
        NEW_AND_RET_CAP_CHARGE_AC = intersect(NEW_CAP_CHARGE_AC, RET_CAP_CHARGE_AC)
        NEW_NOT_RET_CAP_CHARGE_AC = setdiff(NEW_CAP_CHARGE_AC, RET_CAP_CHARGE_AC)
        RET_NOT_NEW_CAP_CHARGE_AC = setdiff(RET_CAP_CHARGE_AC, NEW_CAP_CHARGE_AC)
        @expression(EP, eTotalCapCharge_AC[y in VS_ASYM_AC_CHARGE],
            if (y in NEW_AND_RET_CAP_CHARGE_AC)
                eExistingCapChargeAC[y] + EP[:vCAPCHARGE_AC][y] - EP[:vRETCAPCHARGE_AC][y]
            elseif (y in NEW_NOT_RET_CAP_CHARGE_AC)
                eExistingCapChargeAC[y] + EP[:vCAPCHARGE_AC][y]
            elseif (y in RET_NOT_NEW_CAP_CHARGE_AC)
                eExistingCapChargeAC[y] - EP[:vRETCAPCHARGE_AC][y]
            else
                eExistingCapChargeAC[y]
            end)

        # 2. Objective Function Additions

        # If resource is not eligible for new charge AC capacity, fixed costs are only O&M costs
        @expression(EP, eCFixCharge_AC[y in VS_ASYM_AC_CHARGE],
            if y in NEW_CAP_CHARGE_AC # Resources eligible for new charge AC capacity
                by_rid(y, :inv_cost_charge_ac_per_mwyr) * vCAPCHARGE_AC[y] +
                by_rid(y, :fixed_om_cost_charge_ac_per_mwyr) * eTotalCapCharge_AC[y]
            else
                by_rid(y, :fixed_om_cost_charge_ac_per_mwyr) * eTotalCapCharge_AC[y]
            end)

        # Sum individual resource contributions to fixed costs to get total fixed costs
        @expression(EP,
            eTotalCFixCharge_AC,
            sum(EP[:eCFixCharge_AC][y] for y in VS_ASYM_AC_CHARGE))

        if MultiStage == 1
            add_to_expression!(EP[:eObj], 1 / inputs["OPEXMULT"], eTotalCFixCharge_AC)
        else
            add_to_expression!(EP[:eObj], eTotalCFixCharge_AC)
        end

        ### CONSTRAINTS ###

        # Constraint 0: Existing capacity variable is equal to existing capacity specified in the input file
        if MultiStage == 1
            @constraint(EP,
                cExistingCapChargeAC[y in VS_ASYM_AC_CHARGE],
                EP[:vEXISTINGCAPCHARGEAC][y]==by_rid(y, :existing_cap_charge_ac_mw))
        end

        # Constraints 1: Retirements and capacity additions
        # Cannot retire more charge AC capacity than existing charge capacity
        @constraint(EP,
            cVreStorMaxRetChargeAC[y in RET_CAP_CHARGE_AC],
            vRETCAPCHARGE_AC[y]<=eExistingCapChargeAC[y])
        # Constraint on maximum charge AC capacity (if applicable) [set input to -1 if no constraint on maximum charge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is >= Max_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP,
            cVreStorMaxCapChargeAC[y in MAX_AC_CHARGE],
            eTotalCapCharge_AC[y]<=by_rid(y, :max_cap_charge_ac_mw))
        # Constraint on minimum charge AC capacity (if applicable) [set input to -1 if no constraint on minimum charge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is <= Min_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP,
            cVreStorMinCapChargeAC[y in MIN_AC_CHARGE],
            eTotalCapCharge_AC[y]>=by_rid(y, :min_cap_charge_ac_mw))

        
    end
end
