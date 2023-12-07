@doc raw"""
	function dcopf_transmission!(EP::Model, inputs::Dict, setup::Dict)
"""
function dcopf_transmission!(EP::Model, inputs::Dict, setup::Dict)

	println("DC-OPF Module")

	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	L = inputs["L"]     # Number of transmission lines

	### DC-OPF variables ###

	# Voltage angle variables of each zone "z" at hour "t" 
	@variable(EP, vANGLE[z=1:Z,t=1:T])

	### DC-OPF constraints ###

	# Power flow constraint
	@constraint(EP, cPOWER_FLOW_OPF[l=1:L, t=1:T], EP[:vFLOW][l,t] == inputs["pDC_OPF_coeff"][l] * sum(inputs["pNet_Map"][l,z] * vANGLE[z,t] for z=1:Z))
		
	# Bus angle limits (except slack bus)
	@constraints(EP, begin
		cANGLE_ub[l=1:L, t=1:T], sum(inputs["pNet_Map"][l,z] * vANGLE[z,t] for z=1:Z) <= (pi/180)*inputs["LINE_Angle_Limit"][l]
		cANGLE_lb[l=1:L, t=1:T], sum(inputs["pNet_Map"][l,z] * vANGLE[z,t] for z=1:Z) >= -(pi/180)*inputs["LINE_Angle_Limit"][l]
	end)

	# Slack Bus angle limit
	@constraint(EP, cANGLE_SLACK[t=1:T], vANGLE[1,t]== 0)



end
