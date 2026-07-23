@doc raw"""
    lds_slack!(EP::Model, inputs::Dict, setup::Dict)

    Adds slack variables to all LDES constraints and penalizes them in the objective function.
"""
function lds_slack!(EP::Model, inputs::Dict, setup::Dict)

    println("Including slacks for all LDES constraints")

    @variable(EP,vLDS_SLACK_MAX[w in 1:inputs["REP_PERIOD"]]);

	@constraint(EP,cPosSlack[w in 1:inputs["REP_PERIOD"]],vLDS_SLACK_MAX[w]>=0)
    
    PenaltyValue = 100*(inputs["Weights"]/inputs["H"])*inputs["Voll"][1] ;
    println("LDES slack penalty value is:")
    println(PenaltyValue)

	@expression(EP,eObjSlack,sum(PenaltyValue[w]*vLDS_SLACK_MAX[w] for w in 1:inputs["REP_PERIOD"]))
    
    EP[:eObj] += eObjSlack
end

@doc raw"""
    vre_stor_lds_slack!(EP::Model, inputs::Dict, setup::Dict)

    Adds slack variables to all LDES constraints for VRE_STOR module 
    and penalizes them in the objective function.
"""
function vre_stor_lds_slack!(EP::Model, inputs::Dict, setup::Dict)

    println("Including slacks for all LDES constraints")

    @variable(EP,vVRE_STOR_LDS_SLACK_MAX[w in 1:inputs["REP_PERIOD"]]);

	@constraint(EP,cVreStorPosSlack[w in 1:inputs["REP_PERIOD"]],vVRE_STOR_LDS_SLACK_MAX[w]>=0)
    
    PenaltyValue = 100*(inputs["Weights"]/inputs["H"])*inputs["Voll"][1] ;
    println("LDES slack penalty value is:")
    println(PenaltyValue)

	@expression(EP,eObjSlackVreStor,sum(PenaltyValue[w]*vVRE_STOR_LDS_SLACK_MAX[w] for w in 1:inputs["REP_PERIOD"]))
    
    EP[:eObj] += eObjSlackVreStor

end
