function capacity_decisions!(EP::Model, inputs::Dict, setup::Dict)

    discharge_capacity_decisions!(EP, inputs, setup)

    if !isempty(inputs["STOR_ALL"])
        storage_capacity_decisions!(EP, inputs, setup)
    end
    
    if !isempty(inputs["VRE_STOR"])
        vre_stor_capacity_decisions!(EP, inputs, setup)
    end

    if inputs["Z"]>1
        transmission_capacity_decisions!(EP, inputs, setup)
    end

end

function discharge_capacity_decisions!(EP::Model, inputs::Dict, setup::Dict)
    println("Investment Discharge Module")
    gen = inputs["RESOURCES"]

    G = inputs["G"] # Number of resources (generators, storage, DR, and DERs)
    ALLAM_CYCLE_LOX = inputs["ALLAM_CYCLE_LOX"]                     # Set of Allam Cycle generators (indices)

    NEW_CAP = inputs["NEW_CAP"] # Set of all resources eligible for new capacity
    RET_CAP = inputs["RET_CAP"] # Set of all resources eligible for capacity retirements
    COMMIT = inputs["COMMIT"] # Set of all resources eligible for unit commitment
    RETROFIT_CAP = inputs["RETROFIT_CAP"]  # Set of all resources being retrofitted

    ### Variables ###

    # Retired capacity of resource "y" from existing capacity
    @variable(EP, vRETCAP[y in RET_CAP]>=0)

    # New installed capacity of resource "y"
    @variable(EP, vCAP[y in NEW_CAP]>=0)

    # Allam cycle specific. By default, i = 1 -> sCO2Turbine; i = 2 -> ASU; i = 3 -> LOX
    # retired capacity of Allam cycle 
    if !isempty(ALLAM_CYCLE_LOX)
        sco2turbine, asu, lox = 1, 2, 3
        allam_dict = inputs["allam_dict"]

        NEW_CAP_Allam = intersect(NEW_CAP, ALLAM_CYCLE_LOX)
        RET_CAP_Allam = intersect(RET_CAP, ALLAM_CYCLE_LOX)
        COMMIT_Allam = setup["UCommit"] > 0 ? ALLAM_CYCLE_LOX : Int[]   # If UCommit is on, then all Allam Cycle resources are subject to unit commitment
        WITH_LOX = inputs["WITH_LOX"]     
        # Allam cycle specific. By default, i = 1 -> sCO2Turbine; i = 2 -> ASU; i = 3 -> LOX
        # Retired capacity of Allam cycle 
        @variable(EP, vRETCAP_AllamCycleLOX[y in ALLAM_CYCLE_LOX, i = 1:3]  >= 0)

        # New capacity of Allam cycle
        @variable(EP, vCAP_AllamCycleLOX[y in ALLAM_CYCLE_LOX, i = 1:3]  >= 0)

        # Expressions and constraints related to Allam Cycle costs
        @expression(EP, eExistingCap_AllamCycleLOX[y in ALLAM_CYCLE_LOX, i = 1:3], allam_dict[y, "existing_cap"][i])

        # Note: Allam Cycle is not compatiable with RETRO for now.
        @expression(EP, eTotalCap_AllamcycleLOX[y in ALLAM_CYCLE_LOX, i in 1:3],
        if y in intersect(NEW_CAP_Allam, RET_CAP_Allam) # Resources eligible for new capacity and retirements 
            if y in COMMIT_Allam
                eExistingCap_AllamCycleLOX[y,i] +
                    allam_dict[y,"cap_size"][i] * (EP[:vCAP_AllamCycleLOX][y,i] - EP[:vRETCAP_AllamCycleLOX][y,i])
            else
                eExistingCap_AllamCycleLOX[y, i] + EP[:vCAP_AllamCycleLOX][y, i] - EP[:vRETCAP_AllamCycleLOX][y,i]
            end
        elseif y in setdiff(RET_CAP_Allam, NEW_CAP_Allam) # Resources eligible for only capacity retirements
            if y in COMMIT_Allam
                eExistingCap_AllamCycleLOX[y,i] - allam_dict[y,"cap_size"][i] * EP[:vRETCAP_AllamCycleLOX][y,i]
            else
                eExistingCap_AllamCycleLOX[y,i] - EP[:vRETCAP_AllamCycleLOX][y,i]
            end
        elseif y in setdiff(NEW_CAP_Allam, RET_CAP_Allam) # Resources eligible for new capacity
            if y in COMMIT_Allam
                eExistingCap_AllamCycleLOX[y,i] + allam_dict[y,"cap_size"][i] * (EP[:vCAP_AllamCycleLOX][y,i] )
            else
                eExistingCap_AllamCycleLOX[y,i] + EP[:vCAP_AllamCycleLOX][y,i] 
            end
        else # Resources not eligible for new capacity or retirement
            eExistingCap_AllamCycleLOX[y,i]
        end)

    end

    # Being retrofitted capacity of resource y
    @variable(EP, vRETROFITCAP[y in RETROFIT_CAP]>=0)

    ### Expressions ###
    @expression(EP, eExistingCap[y in 1:G], existing_cap_mw(gen[y]))

    @expression(EP, eTotalCap[y in 1:G],
        if y in intersect(NEW_CAP, RET_CAP, RETROFIT_CAP) # Resources eligible for new capacity, retirements and being retrofitted
            if y in COMMIT
                eExistingCap[y] +
                cap_size(gen[y]) * (EP[:vCAP][y] - EP[:vRETCAP][y] - EP[:vRETROFITCAP][y])
            else
                eExistingCap[y] + EP[:vCAP][y] - EP[:vRETCAP][y] - EP[:vRETROFITCAP][y]
            end
        elseif y in intersect(setdiff(RET_CAP, NEW_CAP), setdiff(RET_CAP, RETROFIT_CAP)) # Resources eligible for only capacity retirements
            if y in COMMIT
                eExistingCap[y] - cap_size(gen[y]) * EP[:vRETCAP][y]
            else
                eExistingCap[y] - EP[:vRETCAP][y]
            end
        elseif y in setdiff(intersect(RET_CAP, NEW_CAP), RETROFIT_CAP) # Resources eligible for retirement and new capacity
            if y in COMMIT
                eExistingCap[y] + cap_size(gen[y]) * (EP[:vCAP][y] - EP[:vRETCAP][y])
            else
                eExistingCap[y] + EP[:vCAP][y] - EP[:vRETCAP][y]
            end
        elseif y in setdiff(intersect(RET_CAP, RETROFIT_CAP), NEW_CAP) # Resources eligible for retirement and retrofitting
            if y in COMMIT
                eExistingCap[y] -
                cap_size(gen[y]) * (EP[:vRETROFITCAP][y] + EP[:vRETCAP][y])
            else
                eExistingCap[y] - (EP[:vRETROFITCAP][y] + EP[:vRETCAP][y])
            end
        elseif y in intersect(setdiff(NEW_CAP, RET_CAP), setdiff(NEW_CAP, RETROFIT_CAP))  # Resources eligible for only new capacity
            if y in COMMIT
                eExistingCap[y] + cap_size(gen[y]) * EP[:vCAP][y]
            else
                eExistingCap[y] + EP[:vCAP][y]
            end
        else # Resources not eligible for new capacity or retirement
            eExistingCap[y] + EP[:vZERO]
        end)
end

function storage_capacity_decisions!(EP::Model, inputs::Dict, setup::Dict)

    gen = inputs["RESOURCES"]

    STOR_ALL = inputs["STOR_ALL"] # Set of all storage resources
    NEW_CAP_ENERGY = inputs["NEW_CAP_ENERGY"] # Set of all storage resources eligible for new energy capacity
    RET_CAP_ENERGY = inputs["RET_CAP_ENERGY"] # Set of all storage resources eligible for energy capacity retirements

    ### Variables ###

    ## Energy storage reservoir capacity (MWh capacity) built/retired for storage with variable power to energy ratio (STOR=1 or STOR=2)

    # New installed energy capacity of resource "y"
    @variable(EP, vCAPENERGY[y in NEW_CAP_ENERGY]>=0)

    # Retired energy capacity of resource "y" from existing capacity
    @variable(EP, vRETCAPENERGY[y in RET_CAP_ENERGY]>=0)

    ### Expressions ###

    @expression(EP, eExistingCapEnergy[y in STOR_ALL], existing_cap_mwh(gen[y]))
    
    @expression(EP, eTotalCapEnergy[y in STOR_ALL],
        if (y in intersect(NEW_CAP_ENERGY, RET_CAP_ENERGY))
            eExistingCapEnergy[y] + EP[:vCAPENERGY][y] - EP[:vRETCAPENERGY][y]
        elseif (y in setdiff(NEW_CAP_ENERGY, RET_CAP_ENERGY))
            eExistingCapEnergy[y] + EP[:vCAPENERGY][y]
        elseif (y in setdiff(RET_CAP_ENERGY, NEW_CAP_ENERGY))
            eExistingCapEnergy[y] - EP[:vRETCAPENERGY][y]
        else
            eExistingCapEnergy[y] + EP[:vZERO]
        end)

    if !isempty(inputs["STOR_ASYMMETRIC"])

        STOR_ASYMMETRIC = inputs["STOR_ASYMMETRIC"] # Set of storage resources with asymmetric (separte) charge/discharge capacity components

        NEW_CAP_CHARGE = inputs["NEW_CAP_CHARGE"] # Set of asymmetric charge/discharge storage resources eligible for new charge capacity
        RET_CAP_CHARGE = inputs["RET_CAP_CHARGE"] # Set of asymmetric charge/discharge storage resources eligible for charge capacity retirements

        ### Variables ###

        ## Storage capacity built and retired for storage resources with independent charge and discharge power capacities (STOR=2)

        # New installed charge capacity of resource "y"
        @variable(EP, vCAPCHARGE[y in NEW_CAP_CHARGE]>=0)

        # Retired charge capacity of resource "y" from existing capacity
        @variable(EP, vRETCAPCHARGE[y in RET_CAP_CHARGE]>=0)

        ### Expressions ###
    
        @expression(EP,
            eExistingCapCharge[y in STOR_ASYMMETRIC],
            existing_charge_cap_mw(gen[y]))

        @expression(EP, eTotalCapCharge[y in STOR_ASYMMETRIC],
            if (y in intersect(NEW_CAP_CHARGE, RET_CAP_CHARGE))
                eExistingCapCharge[y] + EP[:vCAPCHARGE][y] - EP[:vRETCAPCHARGE][y]
            elseif (y in setdiff(NEW_CAP_CHARGE, RET_CAP_CHARGE))
                eExistingCapCharge[y] + EP[:vCAPCHARGE][y]
            elseif (y in setdiff(RET_CAP_CHARGE, NEW_CAP_CHARGE))
                eExistingCapCharge[y] - EP[:vRETCAPCHARGE][y]
            else
                eExistingCapCharge[y] + EP[:vZERO]
            end)
    end

end

function transmission_capacity_decisions!(EP::Model, inputs::Dict, setup::Dict)
    L = inputs["L"]     # Number of transmission lines
    NetworkExpansion = setup["NetworkExpansion"]

    if NetworkExpansion == 1
        # Network lines and zones that are expandable have non-negative maximum reinforcement inputs
        EXPANSION_LINES = inputs["EXPANSION_LINES"]
    end

    ### Variables ###

    if NetworkExpansion == 1
        # Transmission network capacity reinforcements per line
        @variable(EP, vNEW_TRANS_CAP[l in EXPANSION_LINES]>=0)
    end

    ### Expressions ###
    @expression(EP, eTransMax[l = 1:L], inputs["pTrans_Max"][l])
    
    ## Transmission power flow and loss related expressions:
    # Total availabile maximum transmission capacity is the sum of existing maximum transmission capacity plus new transmission capacity
    if NetworkExpansion == 1
        @expression(EP, eAvail_Trans_Cap[l = 1:L],
            if l in EXPANSION_LINES
                eTransMax[l] + vNEW_TRANS_CAP[l]
            else
                eTransMax[l] + EP[:vZERO]
            end)
    else
        @expression(EP, eAvail_Trans_Cap[l = 1:L], eTransMax[l]+EP[:vZERO])
    end

end

function vre_stor_capacity_decisions!(EP::Model, inputs::Dict, setup::Dict)
    println("VRE-STOR Cpacity Decisions Module")
    gen = inputs["RESOURCES"]
    
    VRE_STOR = inputs["VRE_STOR"] # Set of VRE-STOR resources
    # MultiStage = setup["MultiStage"]

    # Make sure to set total cap vars
    gen = inputs["RESOURCES"]

    gen_VRE_STOR = gen.VreStorage

    # Load VRE-storage inputs
    VRE_STOR = inputs["VRE_STOR"]                                   # Set of VRE-STOR generators (indices)
    SOLAR = inputs["VS_SOLAR"]                                      # Set of VRE-STOR generators with solar-component
    DC = inputs["VS_DC"]                                            # Set of VRE-STOR generators with inverter-component
    WIND = inputs["VS_WIND"]                                        # Set of VRE-STOR generators with wind-component
    STOR = inputs["VS_STOR"]                                        # Set of VRE-STOR generators with storage-component
    ELEC = inputs["VS_ELEC"]                                        # Set of VRE-STOR generators with electrolyzer-component
    NEW_CAP = intersect(VRE_STOR, inputs["NEW_CAP"])                # Set of VRE-STOR generators eligible for new buildout

    by_rid(rid, sym) = by_rid_res(rid, sym, gen_VRE_STOR)

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

    if !isempty(DC)
        ### INVERTER VARIABLES ###
        @variables(EP, begin
            # Inverter capacity 
            vRETDCCAP[y in RET_CAP_DC] >= 0                         # Retired inverter capacity [MW AC]
            vDCCAP[y in NEW_CAP_DC] >= 0                            # New installed inverter capacity [MW AC]
        end)

        # DEV NOTES: Add when Multistage is being supported
        # if MultiStage == 1
            # @variable(EP, vEXISTINGDCCAP[y in DC]>=0)
        # end
        ### EXPRESSIONS ###
        # Multistage existing capacity definition
        # if MultiStage == 1
        #     @expression(EP, eExistingCapDC[y in DC], vEXISTINGDCCAP[y])
        # else

        @expression(EP, eExistingCapDC[y in DC], by_rid(y, :existing_cap_inverter_mw))
        # end
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
    end

    if !isempty(SOLAR)
        ### SOLAR VARIABLES ###
        @variables(EP, begin
            vRETSOLARCAP[y in RET_CAP_SOLAR] >= 0                         # Retired solar capacity [MW DC]
            vSOLARCAP[y in NEW_CAP_SOLAR] >= 0                            # New installed solar capacity [MW DC]
        end)

        # DEV NOTES: Add when Multistage is being supported
        # if MultiStage == 1
        #     @variable(EP, vEXISTINGSOLARCAP[y in SOLAR]>=0)
        # end
        # if MultiStage == 1
        #     @expression(EP, eExistingCapSolar[y in SOLAR], vEXISTINGSOLARCAP[y])
        # else
        @expression(EP, eExistingCapSolar[y in SOLAR], by_rid(y, :existing_cap_solar_mw))
        # end

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
            end
        )
    end

    if !isempty(WIND)
        @variables(EP, begin
            # Wind capacity 
            vRETWINDCAP[y in RET_CAP_WIND] >= 0                         # Retired wind capacity [MW AC]
            vWINDCAP[y in NEW_CAP_WIND] >= 0                            # New installed wind capacity [MW AC]
        end)

        # DEV NOTES: Add when Multistage is being supported
        # if MultiStage == 1
        #     @variable(EP, vEXISTINGWINDCAP[y in WIND]>=0)
        # end
        # if MultiStage == 1
        #     @expression(EP, eExistingCapWind[y in WIND], vEXISTINGWINDCAP[y])
        # else
        @expression(EP, eExistingCapWind[y in WIND], by_rid(y, :existing_cap_wind_mw))
        # end

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
            end
        )
    end

    if !isempty(STOR)
        ### Variables ###
        @variables(EP, begin
            # Storage energy capacity
            vCAPENERGY_VS[y in NEW_CAP_STOR] >= 0              # Energy storage reservoir capacity (MWh capacity) built for VRE storage [MWh]
            vRETCAPENERGY_VS[y in RET_CAP_STOR] >= 0           # Energy storage reservoir capacity retired for VRE storage [MWh]
        end)

        # DEV NOTES: Add when Multistage is being supported
        # if MultiStage == 1
        #     @variable(EP, vEXISTINGCAPENERGY_VS[y in STOR]>=0)
        # end
        # if MultiStage == 1
        #     @expression(EP, eExistingCapEnergy_VS[y in STOR], vEXISTINGCAPENERGY_VS[y])
        # else
        @expression(EP, eExistingCapEnergy_VS[y in STOR], existing_cap_mwh(gen[y]))
        # end

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

        ### ASYMMETRIC RESOURCE MODULE ###
        if !isempty(inputs["VS_ASYM"])
            charge_vre_stor_capacity_decisions!(EP, inputs, setup)
        end
    end

    if !isempty(ELEC)
        ### ELEC VARIABLES ###
        @variables(EP, begin
            # Electrolyzer capacity 
            vRETELECCAP[y in RET_CAP_ELEC] >= 0                         # Retired electrolyzer capacity [MW AC]
            vELECCAP[y in NEW_CAP_ELEC] >= 0                            # New installed electrolyzer capacity [MW AC]
        end)

        # DEV NOTES: Add when Multistage is being supported
        # if MultiStage == 1
        #     @variable(EP, vEXISTINGELECCAP[y in ELEC]>=0)
        # end
        # if MultiStage == 1
        #     @expression(EP, eExistingCapElec[y in ELEC], vEXISTINGELECCAP[y])
        # else
        @expression(EP, eExistingCapElec[y in ELEC], by_rid(y, :existing_cap_elec_mw))
        # end

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
            end
        )
    end
end

function charge_vre_stor_capacity_decisions!(EP::Model, inputs::Dict, setup::Dict)
    println("VRE-STOR Charge Capacity Decisions Module")

    ### LOAD INPUTS ###
    gen = inputs["RESOURCES"]
    gen_VRE_STOR = gen.VreStorage

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

        # DEV NOTES: Uncomment when adding Multistage support
        # if MultiStage == 1
        #     @variable(EP, vEXISTINGCAPDISCHARGEDC[y in VS_ASYM_DC_DISCHARGE]>=0)
        # end

        ### EXPRESSIONS ###
        # DEV NOTES: Uncomment when adding Multistage support
        # if MultiStage == 1
        #     @expression(EP,
        #         eExistingCapDischargeDC[y in VS_ASYM_DC_DISCHARGE],
        #         vEXISTINGCAPDISCHARGEDC[y])
        # else
        @expression(EP,
            eExistingCapDischargeDC[y in VS_ASYM_DC_DISCHARGE],
            by_rid(y, :existing_cap_discharge_dc_mw))
        # end

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
            end
        )
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

        # DEV NOTES: Uncomment when adding Multistage support
        # if MultiStage == 1
        #     @variable(EP, vEXISTINGCAPCHARGEDC[y in VS_ASYM_DC_CHARGE]>=0)
        # end

        ### EXPRESSIONS ###
        # DEV NOTES: Uncomment when adding Multistage support
        # if MultiStage == 1
        #     @expression(EP,
        #         eExistingCapChargeDC[y in VS_ASYM_DC_CHARGE],
        #         vEXISTINGCAPCHARGEDC[y])
        # else
        @expression(EP,
            eExistingCapChargeDC[y in VS_ASYM_DC_CHARGE],
            by_rid(y, :existing_cap_charge_dc_mw))
        # end

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
            end
        )
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
        
        # DEV NOTES: Uncomment when adding Multistage support
        # if MultiStage == 1
        #     @variable(EP, vEXISTINGCAPDISCHARGEAC[y in VS_ASYM_AC_DISCHARGE]>=0)
        # end

        ### EXPRESSIONS ###
        # DEV NOTES: Uncomment when adding Multistage support
        # if MultiStage == 1
        #     @expression(EP,
        #         eExistingCapDischargeAC[y in VS_ASYM_AC_DISCHARGE],
        #         vEXISTINGCAPDISCHARGEAC[y])
        # else
        @expression(EP,
            eExistingCapDischargeAC[y in VS_ASYM_AC_DISCHARGE],
            by_rid(y, :existing_cap_discharge_ac_mw))
        # end

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
            end
        )
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

        # DEV NOTES: Uncomment when adding Multistage support
        # if MultiStage == 1
        #     @variable(EP, vEXISTINGCAPCHARGEAC[y in VS_ASYM_AC_CHARGE]>=0)
        # end

        ### EXPRESSIONS ###
        # DEV NOTES: Uncomment when adding Multistage support
        # if MultiStage == 1
        #     @expression(EP,
        #         eExistingCapChargeAC[y in VS_ASYM_AC_CHARGE],
        #         vEXISTINGCAPCHARGEAC[y])
        # else
        @expression(EP,
            eExistingCapChargeAC[y in VS_ASYM_AC_CHARGE],
            by_rid(y, :existing_cap_charge_ac_mw))
        # end

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
            end
        )
    end
end