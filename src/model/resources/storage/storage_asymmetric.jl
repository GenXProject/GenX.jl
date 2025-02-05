@doc raw"""
	storage_asymmetric!(EP::Model, inputs::Dict, setup::Dict)

Sets up constraints specific to storage resources with asymmetric charge and discharge capacities. See ```storage()``` in ```storage.jl``` for description of constraints.
"""
function storage_asymmetric!(EP::Model, inputs::Dict, setup::Dict)
    # Set up additional constraints associated with storage resources with asymmetric charge & discharge capacity
    # (e.g. most chemical, thermal, and mechanical storage options with distinct charge & discharge components/processes)
    # STOR = 2 corresponds to storage with distinct power and energy capacity decisions and distinct charge and discharge power capacity decisions/ratings

    println("Storage Resources with Asymmetric Charge/Discharge Capacity Module")

    OperationalReserves = setup["OperationalReserves"] == 1
    CapacityReserveMargin = setup["CapacityReserveMargin"] > 0

    T = inputs["T"]     # Number of time steps (hours)

    ASYMMETRIC = inputs["STOR_ASYMMETRIC"]

    eTotalCapCharge = EP[:eTotalCapCharge]
    vCHARGE = EP[:vCHARGE]

    ### Constraints ###

    # Storage discharge and charge power (and reserve contribution) related constraints for symmetric storage resources:
    expr = extract_time_series_to_expression(vCHARGE, ASYMMETRIC)

    if OperationalReserves
        STOR_ASYM_REG = intersect(ASYMMETRIC, inputs["REG"]) # Set of asymmetric storage resources with REG reserves
        vREG_charge = EP[:vREG_charge]
        add_similar_to_expression!(expr[STOR_ASYM_REG, :], vREG_charge[STOR_ASYM_REG, :])
    end

    if CapacityReserveMargin
        vCAPRES_charge = EP[:vCAPRES_charge]
        add_similar_to_expression!(expr[ASYMMETRIC, :], vCAPRES_charge[ASYMMETRIC, :])
    end

    @constraint(EP, [y in ASYMMETRIC, t in 1:T], expr[y, t] <= eTotalCapCharge[y])
end
