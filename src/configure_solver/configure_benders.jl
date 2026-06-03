function configure_benders(settings_path::String)

    println("Configuring Benders Settings")
    settings = isfile(settings_path) ? YAML.load_file(settings_path, dicttype=Dict{Symbol, Any}) : Dict{Any,Any}()

    # GenX-convention string keys (configurable via benders_settings.yml)
    default_settings = Dict{Any,Any}(
        :ConvTol                   => 1e-3,
        :MaxIter                   => 50,
        :MaxCpuTime                => 7200,
        :StabParam                 => 0.0,
        :StabDynamic               => false,
        :ExpectFeasibleSubproblems => false,
        :IntegerInvestment         => false,
        :Distributed               => false,
        :ThetaLB                   => 0.0,
    )

    merge!(default_settings, settings)

    return default_settings
end
