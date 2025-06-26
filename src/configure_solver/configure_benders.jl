function configure_benders(settings_path::String)
	
	println("Configuring Benders Settings")
	model_settings = YAML.load(open(settings_path))

	settings = Dict{Any,Any}("BD_ConvTol"=>1e-3,
							"BD_MaxIter"=>300,
							"BD_MaxCpuTime"=>24*3600,
							"BD_StabParam"=>0.0,
							"BD_Stab_Method"=>"off");

	merge!(settings, model_settings)

return settings
end
