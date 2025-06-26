function lds_slack!(EP::Model, inputs::Dict,setup::Dict)

    println("Including slacks for all LDES constraints")

    @variable(EP,vLDS_SLACK_MAX[w in 1:inputs["REP_PERIOD"]]);

	@constraint(EP,cPosSlack[w in 1:inputs["REP_PERIOD"]],vLDS_SLACK_MAX[w]>=0)
    
    PenaltyValue = 100*(inputs["Weights"]/inputs["H"])*inputs["Voll"][1] ;
    println("LDES slack penalty value is:")
    println(PenaltyValue)

	@expression(EP,eObjSlack,sum(PenaltyValue[w]*vLDS_SLACK_MAX[w] for w in 1:inputs["REP_PERIOD"]))
    
    EP[:eObj] += eObjSlack

    if setup["LDES_Feasible"]==1
        println("Fixing slacks for all LDES constraints to zero")
        fix.(vLDS_SLACK_MAX,0.0,force=true)
    end

end
