@doc raw"""
	storage_symmetric!(EP::Model, inputs::Dict, setup::Dict)

Sets up constraints specific to storage resources with symmetric charge and discharge capacities. See ```storage()``` in ```storage.jl``` for description of constraints.
"""
function storage_symmetric!(EP::Model, inputs::Dict, setup::Dict)
    # Set up additional constraints associated with storage resources with symmetric charge & discharge capacity
    # (e.g. most electrochemical batteries that use same components for charge & discharge)
    # STOR = 1 corresponds to storage with distinct power and energy capacity decisions but symmetric charge/discharge power ratings

    println("Storage Resources with Symmetric Charge/Discharge Capacity Module")

    OperationalReserves = setup["OperationalReserves"] == 1
    CapacityReserveMargin = setup["CapacityReserveMargin"] > 0

    T = inputs["T"]     # Number of time steps (hours)

    SYMMETRIC = inputs["STOR_SYMMETRIC"]
    eTotalCap = EP[:eTotalCap]
    vP = EP[:vP]
    vCHARGE = EP[:vCHARGE]

    ### Constraints ###

    # Maximum charging rate plus contribution to regulation down must be less than symmetric power rating
    # Max simultaneous charge and discharge rates cannot be greater than symmetric charge/discharge capacity
    expr = @expression(EP, [y in SYMMETRIC, t in 1:T], vP[y, t] + vCHARGE[y, t])

    if OperationalReserves
        REG = intersect(SYMMETRIC, inputs["REG"])
        RSV = intersect(SYMMETRIC, inputs["RSV"])
        vREG_charge = EP[:vREG_charge]
        vRSV_charge = EP[:vRSV_charge]
        vREG_discharge = EP[:vREG_discharge]
        vRSV_discharge = EP[:vRSV_discharge]
        add_similar_to_expression!(expr[REG, :], vREG_charge[REG, :])
        add_similar_to_expression!(expr[REG, :], vREG_discharge[REG, :])
        add_similar_to_expression!(expr[RSV, :], vRSV_discharge[RSV, :])
    end

    if CapacityReserveMargin
        # Maximum charging rate (including virtual charging to move energy held in reserve back to available storage) must be less than symmetric power rating
        vCAPRES_charge = EP[:vCAPRES_charge]
        vCAPRES_discharge = EP[:vCAPRES_discharge]
        add_similar_to_expression!(expr[SYMMETRIC, :], vCAPRES_charge[SYMMETRIC, :])
        add_similar_to_expression!(expr[SYMMETRIC, :], vCAPRES_discharge[SYMMETRIC, :])
    end

    @constraint(EP, [y in SYMMETRIC, t in 1:T], expr[y, t]<=eTotalCap[y])
end
