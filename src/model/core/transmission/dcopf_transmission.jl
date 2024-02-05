@doc raw"""
	function dcopf_transmission!(EP::Model, inputs::Dict, setup::Dict)
The addtional constraints imposed upon the line flows in the case of DC-OPF are as follows:
For the definition of the line flows, in terms of the voltage phase angles:
```math
\begin{aligned}
        & \Phi_{l,t}=\mathcal{B}_{l} \times (\sum_{z\in \mathcal{Z}}{(\varphi^{map}_{l,z} \times \theta_{z,t})}) \forall l \in \mathcal{L}, \forall t  \in \mathcal{T}\\
\end{aligned}
```
For imposing the constraint of maximum allowed voltage phase angle difference across lines:
```math
\begin{aligned}
        & \sum_{z\in \mathcal{Z}}{(\varphi^{map}_{l,z} \times \theta_{z,t})} \leq \frac{\pi}{180} \Theta^{max}_{l} \forall l \in \mathcal{L}, \forall t  \in \mathcal{T}\\
	& \sum_{z\in \mathcal{Z}}{(\varphi^{map}_{l,z} \times \theta_{z,t})} \geq -\frac{\pi}{180} \Theta^{max}_{l} \forall l \in \mathcal{L}, \forall t  \in \mathcal{T}\\
\end{aligned}
```
For ensuring the slack-bus, voltage phase angle is set as the reference we enforce the constraint

```math
\begin{aligned}
        & \theta_{1,t})} = 0 \forall t  \in \mathcal{T}\\
\end{aligned}
```

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
		cANGLE_ub[l=1:L, t=1:T], sum(inputs["pNet_Map"][l,z] * vANGLE[z,t] for z=1:Z) <= inputs["Line_Angle_Limit"][l]
		cANGLE_lb[l=1:L, t=1:T], sum(inputs["pNet_Map"][l,z] * -vANGLE[z,t] for z=1:Z) <= inputs["Line_Angle_Limit"][l]
	end)

	# Slack Bus angle limit
	@constraint(EP, cANGLE_SLACK[t=1:T], vANGLE[1,t]== 0)



end
