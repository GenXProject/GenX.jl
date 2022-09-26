function opf_formulation_shift_factor_method((EP::Model, inputs::Dict, setup::Dict))
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	L = inputs["L"]     # Number of transmission lines
end

function opf_formulation_b_theta_method((EP::Model, inputs::Dict, setup::Dict))
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	L = inputs["L"]     # Number of transmission lines
end