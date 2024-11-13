function ccs_solvent_storage_no_commit!(EP::Model, inputs::Dict, setup::Dict)
    # Load generators dataframe, sets, and time periods
    gen = inputs["RESOURCES"]
    T = inputs["T"]                                                 # Number of time steps (hours)
    Z = inputs["Z"]                                                 # Number of zones
    MultiStage = setup["MultiStage"]
    omega = inputs["omega"]

    # Load CCS with SOLVENT STORAGE related inputs 
    CCS_SOLVENT_STORAGE = inputs["CCS_SOLVENT_STORAGE"]             # Set of CCS_Solvent_Storage generators (indices)
    NEW_CAP_CCS_SS = intersect(inputs["NEW_CAP"], CCS_SOLVENT_STORAGE)  # SS stands for solvent storage
    RET_CAP_CCS_SS = intersect(inputs["RET_CAP"], CCS_SOLVENT_STORAGE)
    NO_COMMIT_CCS_SS = setup["UCommit"] == 0 ? CCS_SOLVENT_STORAGE : Int[]

    # time related 
    p = inputs["hours_per_subperiod"]

    # components of ccs generators with solvent storage
    # by default, i = 1 -> gas turbine; i = 2 -> steam turbine;
    #             i = 3 -> absorber; i = 4 -> compressor; i = 5 -> regenerator;
    #             i = 6 -> rich solvent storage; i = 7 -> lean solvent storage
    gasturbine, steamturbine, absorber, compressor, regenerator, solventstorage_rich, solventstorage_lean = 1, 2, 3, 4, 5, 6, 7
    
    # get component-wise parameter data
    solvent_storage_dict = inputs["solvent_storage_dict"]

    ## Decision variables for unit commitment
    # Subcomponents that are turned on and off at the same time are aggregated to simplify the model
    # i = 1 -> combine cycle turbines, including gas and steam turbines
    # i = 4 -> regenerator and compressors
    # i = 3 -> abosorber

    # No unit commitment constraints

    ### Maximum ramp up and down between consecutive hours (Constraints #1-2)
    # rampup constraints
    @constraint(EP,[y in CCS_SOLVENT_STORAGE, i in [1, 3, 4], t in 1:T],
                EP[:vOutput_CCS_SS][y,i,t]-EP[:vOutput_CCS_SS][y,i,t-1] <= solvent_storage_dict[y, "ramp_up"][i]*EP[:eTotalCap_CCS_SS][y,i])

    # rampdown constraints
    @constraint(EP,[y in CCS_SOLVENT_STORAGE, i in [1, 3, 4], t in 1:T],
                EP[:vOutput_CCS_SS][y,i,t-1]-EP[:vOutput_CCS_SS][y,i,t] <= solvent_storage_dict[y, "ramp_dn"][i]*EP[:eTotalCap_CCS_SS][y,i])

    ### Minimum and maximum power output constraints (Constraints #3-4)
    @constraints(EP, begin
        [y in CCS_SOLVENT_STORAGE, i in [1, 3, 4], t=1:T], EP[:vOutput_CCS_SS][y,i,t] >= solvent_storage_dict[y, "min_power"][i]*EP[:eTotalCap_CCS_SS][y,i]
        [y in CCS_SOLVENT_STORAGE, i in [1, 3, 4], t=1:T], EP[:vOutput_CCS_SS][y,i,t] <= EP[:eTotalCap_CCS_SS][y,i]
    end)

    # operational reserve  (Constraints #5)
    # operational reserve is based on the combine cycle turbine instead of the whole system
    if setup["OperationalReserves"] > 0
        @variable(EP, vP_CCS_SS[y in CCS_SOLVENT_STORAGE, t=1:T])
        @constraint(EP, [y in CCS_SOLVENT_STORAGE, t in 1:T], vP_CCS_SS[y,t]==EP[:eP_CCS_SS][y,t])

        CCS_SS_REG = intersect(CCS_SOLVENT_STORAGE, inputs["REG"]) # Set of CCS_SOLVENT_STORAGE resources with regulation reserves
        CCS_SS_RSV = intersect(CCS_SOLVENT_STORAGE, inputs["RSV"]) # Set of CCS_SOLVENT_STORAGE resources with spinning reserves

        max_power(y, t) = inputs["pP_Max"][y, t]
        
        # Maximum regulation and reserve contributions
        @constraint(EP, cREG_CCS_SS_Max[y in CCS_SS_REG, t in 1:T],
                    EP[:vREG][y, t]<=max_power(y, t) * reg_max(gen[y]) * (EP[:eTotalCap_CCS_SS][y, gasturbine] + EP[:eTotalCap_CCS_SS][y, steamturbine]))
        @constraint(EP, cRSV_CCS_SS_Max[y in CCS_SS_RSV, t in 1:T],
                    EP[:vRSV][y, t]<=max_power(y, t) * rsv_max(gen[y]) * (EP[:eTotalCap_CCS_SS][y, gasturbine] + EP[:eTotalCap_CCS_SS][y, steamturbine]))
    
        # Minimum stable power generated per technology "y" at hour "t" and contribution to regulation must be > min power
        expr = extract_time_series_to_expression(EP[:vP_CCS_SS], CCS_SOLVENT_STORAGE)
        add_similar_to_expression!(expr[CCS_SS_REG, :], -EP[:vREG][CCS_SS_REG, :])
        @constraint(EP, cREG_CCS_SS_Min[y in CCS_SOLVENT_STORAGE, t in 1:T],
                    expr[y, t]>=solvent_storage_dict[y, "min_power"][gasturbine] * (EP[:eTotalCap_CCS_SS][y, gasturbine] + EP[:eTotalCap_CCS_SS][y, steamturbine]))
    
        # Maximum power generated per technology "y" at hour "t"  and contribution to regulation and reserves up must be < max power
        expr = extract_time_series_to_expression(EP[:vP_CCS_SS], CCS_SOLVENT_STORAGE)
        add_similar_to_expression!(expr[CCS_SS_REG, :], EP[:vREG][CCS_SS_REG, :])
        add_similar_to_expression!(expr[CCS_SS_RSV, :], EP[:vRSV][CCS_SS_RSV, :])
        @constraint(EP, 
            [y in CCS_SOLVENT_STORAGE, t in 1:T],
            expr[y, t]<=max_power(y, t) * (EP[:eTotalCap_CCS_SS][y, gasturbine] + EP[:eTotalCap_CCS_SS][y, steamturbine]))
    end
end