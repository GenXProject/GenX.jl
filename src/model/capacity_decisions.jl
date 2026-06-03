function capacity_decisions!(EP, inputs::Dict, setup::Dict)

    discharge_capacity_decisions!(EP, inputs, setup)

    if !isempty(inputs["STOR_ALL"])
        storage_capacity_decisions!(EP, inputs, setup)
    end

    if !isempty(inputs["VRE_STOR"])
        error("Benders not yet supported with VRE-STOR")
    end

    if inputs["Z"]>1
        transmission_capacity_decisions!(EP, inputs, setup)
    end

end

function discharge_capacity_decisions!(EP, inputs::Dict, setup::Dict)

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
    println("ENTERING ALLAM CYCLE CAP DECISIONS")
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
    println("FINISHED ALLAM CYCLE CAP DECISIONS")

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

function storage_capacity_decisions!(EP, inputs::Dict, setup::Dict)

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

function transmission_capacity_decisions!(EP, inputs::Dict, setup::Dict)
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