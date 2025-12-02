@doc raw"""
	ates_inter_period_linkage!(EP::Model, inputs::Dict, setup::Dict)
This function creates variables and constraints enabling modeling of long duration storage resources when modeling representative time periods.
"""
function ates_inter_period_linkage!(EP::Model, inputs::Dict, setup::Dict)
    println("Long Duration Storage Module for Underground Thermal Energy Storage")

    gen = inputs["RESOURCES"]
    T = inputs["T"]

    REP_PERIOD = inputs["REP_PERIOD"]     # Number of representative periods

    STOR_UTES_LONG_DURATION = inputs["STOR_UTES_LONG_DURATION"]

    hours_per_subperiod = inputs["hours_per_subperiod"] #total number of hours per subperiod

    dfPeriodMap = inputs["Period_Map"] # Dataframe that maps modeled periods to representative periods
    NPeriods = size(inputs["Period_Map"])[1] # Number of modeled periods

    MODELED_PERIODS_INDEX = 1:NPeriods
    REP_PERIODS_INDEX = MODELED_PERIODS_INDEX[dfPeriodMap[!, :Rep_Period] .== MODELED_PERIODS_INDEX]
    NON_REP_PERIODS_INDEX = setdiff(MODELED_PERIODS_INDEX, REP_PERIODS_INDEX)

    # UTES components
    # by default, i = 1 -> dry cooler; i = 2 -> chiller; i = 3 -> pump in the tertiary loop; i = 4 -> thermal storage; 
    dry_cooler, chiller, pump, storage = 1, 2, 3, 4

    ### Variables ###

    # Variables to define inter-period energy transferred between modeled periods

    # State of charge of storage at beginning of each modeled period n
    @variable(EP, vSOC_UTESw_cold[y in STOR_UTES_LONG_DURATION, n in MODELED_PERIODS_INDEX])
    @variable(EP, vSOC_UTESw_hot[y in STOR_UTES_LONG_DURATION, n in MODELED_PERIODS_INDEX])

    @variable(EP, vSOC_UTES_cold[y in STOR_UTES_LONG_DURATION, t = 1:T])
    @variable(EP, vSOC_UTES_hot[y in STOR_UTES_LONG_DURATION, t = 1:T])

    # Build up in storage inventory over each representative period w
    # Build up inventory can be positive or negative
    @variable(EP, vdSOC_UTES_cold[y in STOR_UTES_LONG_DURATION, w = 1:REP_PERIOD])
    @variable(EP, vdSOC_UTES_hot[y in STOR_UTES_LONG_DURATION, w = 1:REP_PERIOD])

    # Additional constraints to prevent violation of SoC limits in non-representative periods
    if setup["LDSAdditionalConstraints"] == 1 && !isempty(NON_REP_PERIODS_INDEX)
        # Maximum positive storage inventory change within subperiod
	    @variable(EP, vdSOC_maxPos_UTES_cold[y in STOR_UTES_LONG_DURATION, w=1:REP_PERIOD] >= 0)
        @variable(EP, vdSOC_maxPos_UTES_hot[y in STOR_UTES_LONG_DURATION, w=1:REP_PERIOD] >= 0)

        # Maximum negative storage inventory change within subperiod
        @variable(EP, vdSOC_maxNeg_UTES_cold[y in STOR_UTES_LONG_DURATION, w=1:REP_PERIOD] <= 0)
        @variable(EP, vdSOC_maxNeg_UTES_hot[y in STOR_UTES_LONG_DURATION, w=1:REP_PERIOD] <= 0)
    end

    # ### Constraints ###

    # @constraint(EP, cSOC_ATES_cold[y in STOR_UTES_LONG_DURATION, t = 1:T],
    #             vSOC_UTES_cold[y, t] == gen[y].c_eff_c * EP[:vTemp_Cold][y, t])
    # @constraint(EP, cSOC_ATES_hot[y in STOR_UTES_LONG_DURATION, t = 1:T],
    #             vSOC_UTES_hot[y, t] == - gen[y].c_eff_h * EP[:vTemp_Hot][y, t])

    # # Links last time step with first time step, ensuring position in hour 1 is within eligible change from final hour position
    # # Modified initial state of storage for long-duration storage - initialize wth value carried over from last period
    # # Alternative to cSoCBalStart constraint which is included when not modeling operations wrapping and long duration storage
    # # Note: tw_min = hours_per_subperiod*(w-1)+1; tw_max = hours_per_subperiod*w

    # @constraint(EP,
    #     cUTESLongDurationStorageStart_cold[w = 1:REP_PERIOD, y in STOR_UTES_LONG_DURATION],
    #     vSOC_UTES_cold[y, hours_per_subperiod * (w - 1) + 1] == 
    #         (1 - gen[y].alpha_loss_cold) * (vSOC_UTES_cold[y, hours_per_subperiod * w] - vdSOC_UTES_cold[y, w]) + 
    #         EP[:vQ_Cold][y, hours_per_subperiod * (w - 1) + 1] + 
    #         gen[y].alpha_loss_cold * gen[y].c_eff_c * (gen[y].max_temp_cold_well_c - gen[y].min_temp_cold_well_c)
    #         )
    # @constraint(EP,
    #     cUTESLongDurationStorageStart_hot[w = 1:REP_PERIOD, y in STOR_UTES_LONG_DURATION],
    #     vSOC_UTES_hot[y, hours_per_subperiod * (w - 1) + 1] == 
    #         (1 - gen[y].alpha_loss_hot) * (vSOC_UTES_hot[y, hours_per_subperiod * w] - vdSOC_UTES_hot[y, w]) - 
    #         EP[:vQ_Hot][y, hours_per_subperiod * (w - 1) + 1] + 
    #         gen[y].alpha_loss_hot * gen[y].c_eff_h * (gen[y].max_temp_hot_well_c - gen[y].min_temp_hot_well_c)
    #         )

    ### Constraints ###

    @constraint(EP, cSOC_ATES_cold[y in STOR_UTES_LONG_DURATION, t = 1:T],
                vSOC_UTES_cold[y, t] == - gen[y].c_eff_c * EP[:vTemp_Cold][y, t])
    @constraint(EP, cSOC_ATES_hot[y in STOR_UTES_LONG_DURATION, t = 1:T],
                vSOC_UTES_hot[y, t] == gen[y].c_eff_h * EP[:vTemp_Hot][y, t])

    # Links last time step with first time step, ensuring position in hour 1 is within eligible change from final hour position
    # Modified initial state of storage for long-duration storage - initialize wth value carried over from last period
    # Alternative to cSoCBalStart constraint which is included when not modeling operations wrapping and long duration storage
    # Note: tw_min = hours_per_subperiod*(w-1)+1; tw_max = hours_per_subperiod*w

    @constraint(EP,
        cUTESLongDurationStorageStart_cold[w = 1:REP_PERIOD, y in STOR_UTES_LONG_DURATION],
        vSOC_UTES_cold[y, hours_per_subperiod * (w - 1) + 1] == 
            (1 - gen[y].alpha_loss_cold) * (vSOC_UTES_cold[y, hours_per_subperiod * w] - vdSOC_UTES_cold[y, w]) -
            EP[:vQ_Cold][y, hours_per_subperiod * (w - 1) + 1]
             )
    @constraint(EP,
        cUTESLongDurationStorageStart_hot[w = 1:REP_PERIOD, y in STOR_UTES_LONG_DURATION],
        vSOC_UTES_hot[y, hours_per_subperiod * (w - 1) + 1] == 
            (1 - gen[y].alpha_loss_hot) * (vSOC_UTES_hot[y, hours_per_subperiod * w] - vdSOC_UTES_hot[y, w]) + 
            EP[:vQ_Hot][y, hours_per_subperiod * (w - 1) + 1]
             )

    # Storage at beginning of period w = storage at beginning of period w-1 + storage built up in period w (after n representative periods)
    ## Multiply storage build up term from prior period with corresponding weight
    # add self discharge??????
    @constraint(EP,
        cUTESLongDurationStorage_cold[y in STOR_UTES_LONG_DURATION,
            r in MODELED_PERIODS_INDEX],
        vSOC_UTESw_cold[y,
            mod1(r + 1, NPeriods)]==vSOC_UTESw_cold[y, r] +
                                    vdSOC_UTES_cold[y, dfPeriodMap[r, :Rep_Period_Index]])
    @constraint(EP,
        cUTESLongDurationStorage_hot[y in STOR_UTES_LONG_DURATION,
            r in MODELED_PERIODS_INDEX],
        vSOC_UTESw_hot[y,
            mod1(r + 1, NPeriods)]==vSOC_UTESw_hot[y, r] +
                                    vdSOC_UTES_hot[y, dfPeriodMap[r, :Rep_Period_Index]])

    # Storage at beginning of each modeled period cannot exceed installed energy capacity
    @constraint(EP,
        cUTESLongDurationStorageUpper_cold[y in STOR_UTES_LONG_DURATION,
            r in MODELED_PERIODS_INDEX],
        vSOC_UTESw_cold[y, r]<= gen[y].c_eff_c * gen[y].max_temp_cold_well_c)
    @constraint(EP,
        cUTESLongDurationStorageUpper_hot[y in STOR_UTES_LONG_DURATION,
            r in MODELED_PERIODS_INDEX],
        vSOC_UTESw_hot[y, r]<= gen[y].c_eff_h * gen[y].max_temp_hot_well_c)

    # Initial storage level for representative periods must also adhere to sub-period storage inventory balance
    # Initial storage = Final storage - change in storage inventory across representative period
    @constraint(EP,
        cUTESLongDurationStorageSub_cold[y in STOR_UTES_LONG_DURATION,
            r in REP_PERIODS_INDEX],
        vSOC_UTESw_cold[y,r]==EP[:vSOC_UTES_cold][y, hours_per_subperiod * dfPeriodMap[r, :Rep_Period_Index]] -
                vdSOC_UTES_cold[y, dfPeriodMap[r, :Rep_Period_Index]])
    @constraint(EP,
        cUTESLongDurationStorageSub_hot[y in STOR_UTES_LONG_DURATION,
            r in REP_PERIODS_INDEX],
        vSOC_UTESw_hot[y,r]==EP[:vSOC_UTES_hot][y, hours_per_subperiod * dfPeriodMap[r, :Rep_Period_Index]] -
                vdSOC_UTES_cold[y, dfPeriodMap[r, :Rep_Period_Index]])

    if setup["LDSAdditionalConstraints"] == 1 && !isempty(NON_REP_PERIODS_INDEX)
        # Extract maximum storage level variation (positive) within subperiod
        @constraint(EP, cMaxSoCVarPos_UTES_cold[y in STOR_UTES_LONG_DURATION, w=1:REP_PERIOD, t=2:hours_per_subperiod],
                    vdSOC_maxPos_UTES_cold[y,w] >= EP[:vSOC_UTES_cold][y,hours_per_subperiod*(w-1)+t] - EP[:vSOC_UTES_cold][y,hours_per_subperiod*(w-1)+1])
        @constraint(EP, cMaxSoCVarPos_UTES_hot[y in STOR_UTES_LONG_DURATION, w=1:REP_PERIOD, t=2:hours_per_subperiod],
                    vdSOC_maxPos_UTES_hot[y,w] >= EP[:vSOC_UTES_hot][y,hours_per_subperiod*(w-1)+t] - EP[:vSOC_UTES_hot][y,hours_per_subperiod*(w-1)+1])

        # Extract maximum storage level variation (negative) within subperiod
        @constraint(EP, cMaxSoCVarNeg_UTES_cold[y in STOR_UTES_LONG_DURATION, w=1:REP_PERIOD, t=2:hours_per_subperiod],
                        vdSOC_maxNeg_UTES_cold[y,w] <= EP[:vSOC_UTES_cold][y,hours_per_subperiod*(w-1)+t] - EP[:vSOC_UTES_cold][y,hours_per_subperiod*(w-1)+1])
        @constraint(EP, cMaxSoCVarNeg_UTES_hot[y in STOR_UTES_LONG_DURATION, w=1:REP_PERIOD, t=2:hours_per_subperiod],
                        vdSOC_maxNeg_UTES_hot[y,w] <= EP[:vSOC_UTES_hot][y,hours_per_subperiod*(w-1)+t] - EP[:vSOC_UTES_hot][y,hours_per_subperiod*(w-1)+1])

        # # Max storage content within each modeled period cannot exceed installed energy capacity
        # @constraint(EP, cSoCLongDurationStorageMaxInt_UTES[y in STOR_UTES_LONG_DURATION, r in NON_REP_PERIODS_INDEX],
        # vSOC_UTESw[y,r] + (1 - gen[y].self_disch) * EP[:vSOC_RTES][y,hours_per_subperiod*(dfPeriodMap[r,:Rep_Period_Index]-1)+1] +
        # gen[y].thermal_capacity_second_loop * EP[:eMassFlow_Sec_Loop][y, hours_per_subperiod*(dfPeriodMap[r,:Rep_Period_Index]-1)+1] * (- EP[:vTemp_Chiller][y, hours_per_subperiod*(dfPeriodMap[r,:Rep_Period_Index]-1)+1] + EP[:eTemp_HX_12][y, hours_per_subperiod*(dfPeriodMap[r,:Rep_Period_Index]-1)+1]) <= EP[:eTotalCap_UTES][y, storage] * gen[y].thermal_capacity_tertiary_loop * (gen[y].temp_hot_thermal_storage - gen[y].temp_cold_thermal_storage)/3600)

        # # Min storage content within each modeled period cannot be negative
        # @constraint(EP, cSoCLongDurationStorageMinInt_UTES[y in STOR_UTES_LONG_DURATION, r in NON_REP_PERIODS_INDEX],
        # vSOC_UTESw[y,r] + (1 - gen[y].self_disch) * EP[:vSOC_RTES][y,hours_per_subperiod*(dfPeriodMap[r,:Rep_Period_Index]-1)+1] +
        # gen[y].thermal_capacity_second_loop * EP[:eMassFlow_Sec_Loop][y, hours_per_subperiod*(dfPeriodMap[r,:Rep_Period_Index]-1)+1] * (- EP[:vTemp_Chiller][y, hours_per_subperiod*(dfPeriodMap[r,:Rep_Period_Index]-1)+1] + EP[:eTemp_HX_12][y, hours_per_subperiod*(dfPeriodMap[r,:Rep_Period_Index]-1)+1]) >= 0)     
    end
end