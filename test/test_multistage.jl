module TestMultiStage

using Test

include(joinpath(@__DIR__, "utilities.jl"))

obj_true = [79734.80032, 41630.03494, 27855.20631]
test_path = joinpath(@__DIR__, "multi_stage")

# Define test inputs
multistage_setup = Dict("NumStages" => 3,
    "StageLengths" => [10, 10, 10],
    "WACC" => 0.045,
    "ConvergenceTolerance" => 0.01,
    "Myopic" => 0)

genx_setup = Dict("Trans_Loss_Segments" => 1,
    "OperationalReserves" => 1,
    "CO2Cap" => 2,
    "StorageLosses" => 1,
    "ParameterScale" => 1,
    "UCommit" => 2,
    "MultiStage" => 1,
    "MultiStageSettingsDict" => multistage_setup)

# Run the case and get the objective value and tolerance
EP, _, _ = redirect_stdout(devnull) do
    run_genx_case_testing(test_path, genx_setup)
end
obj_test = objective_value.(EP[i] for i in 1:multistage_setup["NumStages"])
optimal_tol_rel = get_attribute.((EP[i] for i in 1:multistage_setup["NumStages"]),
    "ipm_optimality_tolerance")
optimal_tol = optimal_tol_rel .* obj_test  # Convert to absolute tolerance

# Test the objective value
test_result = @test all(obj_true .- optimal_tol .<= obj_test .<= obj_true .+ optimal_tol)

# Round objective value and tolerance. Write to test log.
obj_test = round_from_tol!.(obj_test, optimal_tol)
optimal_tol = round_from_tol!.(optimal_tol, optimal_tol)
write_testlog(test_path, obj_test, optimal_tol, test_result)

function test_new_build(EP::Dict, inputs::Dict)
    ### Test that the resource with New_Build = 0 did not expand capacity
    a = true

    for t in keys(EP)
        if t == 1
            a = value(EP[t][:eTotalCap][1]) <=
                GenX.existing_cap_mw(inputs[1]["RESOURCES"][1])[1]
        else
            a = value(EP[t][:eTotalCap][1]) <= value(EP[t - 1][:eTotalCap][1])
        end
        if a == false
            break
        end
    end

    return a
end

function test_can_retire(EP::Dict, inputs::Dict)
    ### Test that the resource with Can_Retire = 0 did not retire capacity
    a = true

    for t in keys(EP)
        if t == 1
            a = value(EP[t][:eTotalCap][1]) >=
                GenX.existing_cap_mw(inputs[1]["RESOURCES"][1])[1]
        else
            a = value(EP[t][:eTotalCap][1]) >= value(EP[t - 1][:eTotalCap][1])
        end
        if a == false
            break
        end
    end

    return a
end

test_path_new_build = joinpath(test_path, "new_build")
EP, inputs, _ = redirect_stdout(devnull) do
    run_genx_case_testing(test_path_new_build, genx_setup)
end

new_build_test_result = @test test_new_build(EP, inputs)
write_testlog(test_path,
    "Testing that the resource with New_Build = 0 did not expand capacity",
    new_build_test_result)

test_path_can_retire = joinpath(test_path, "can_retire")
EP, inputs, _ = redirect_stdout(devnull) do
    run_genx_case_testing(test_path_can_retire, genx_setup)
end
can_retire_test_result = @test test_can_retire(EP, inputs)
write_testlog(test_path,
    "Testing that the resource with Can_Retire = 0 did not expand capacity",
    can_retire_test_result)

function test_update_cumulative_min_ret!()
    # Merge the genx_setup with the default settings
    settings = GenX.default_settings()

    for ParameterScale in [0, 1]
        genx_setup["ParameterScale"] = ParameterScale
        merge!(settings, genx_setup)

        inputs_dict = Dict()
        true_min_retirements = Dict()

        scale_factor = settings["ParameterScale"] == 1 ? GenX.ModelScalingFactor : 1.0
        redirect_stdout(devnull) do
            warnerror_logger = ConsoleLogger(stderr, Logging.Warn)
            with_logger(warnerror_logger) do
                for t in 1:3
                    inpath_sub = joinpath(test_path, "cum_min_ret", string("inputs_p", t))

                    true_min_retirements[t] = CSV.read(joinpath(inpath_sub,
                            "resources",
                            "Resource_multistage_data.csv"),
                        DataFrame)
                    rename!(true_min_retirements[t],
                        lowercase.(names(true_min_retirements[t])))
                    GenX.scale_multistage_data!(true_min_retirements[t], scale_factor)

                    inputs_dict[t] = Dict()
                    inputs_dict[t]["Z"] = 1
                    GenX.load_demand_data!(settings, inpath_sub, inputs_dict[t])
                    GenX.load_resources_data!(inputs_dict[t],
                        settings,
                        inpath_sub,
                        joinpath(inpath_sub, settings["ResourcesFolder"]))
                    compute_cumulative_min_retirements!(inputs_dict, t)
                end
            end
        end

        for t in 1:3
            # Test that the cumulative min retirements are updated correctly
            gen = inputs_dict[t]["RESOURCES"]
            @test GenX.min_retired_cap_mw.(gen) ==
                  true_min_retirements[t].min_retired_cap_mw
            @test GenX.min_retired_energy_cap_mw.(gen) ==
                  true_min_retirements[t].min_retired_energy_cap_mw
            @test GenX.min_retired_charge_cap_mw.(gen) ==
                  true_min_retirements[t].min_retired_charge_cap_mw
            @test GenX.min_retired_cap_inverter_mw.(gen) ==
                  true_min_retirements[t].min_retired_cap_inverter_mw
            @test GenX.min_retired_cap_solar_mw.(gen) ==
                  true_min_retirements[t].min_retired_cap_solar_mw
            @test GenX.min_retired_cap_wind_mw.(gen) ==
                  true_min_retirements[t].min_retired_cap_wind_mw
            @test GenX.min_retired_cap_discharge_dc_mw.(gen) ==
                  true_min_retirements[t].min_retired_cap_discharge_dc_mw
            @test GenX.min_retired_cap_charge_dc_mw.(gen) ==
                  true_min_retirements[t].min_retired_cap_charge_dc_mw
            @test GenX.min_retired_cap_discharge_ac_mw.(gen) ==
                  true_min_retirements[t].min_retired_cap_discharge_ac_mw
            @test GenX.min_retired_cap_charge_ac_mw.(gen) ==
                  true_min_retirements[t].min_retired_cap_charge_ac_mw

            @test GenX.cum_min_retired_cap_mw.(gen) ==
                  sum(true_min_retirements[i].min_retired_cap_mw for i in 1:t)
            @test GenX.cum_min_retired_energy_cap_mw.(gen) ==
                  sum(true_min_retirements[i].min_retired_energy_cap_mw for i in 1:t)
            @test GenX.cum_min_retired_charge_cap_mw.(gen) ==
                  sum(true_min_retirements[i].min_retired_charge_cap_mw for i in 1:t)
            @test GenX.cum_min_retired_cap_inverter_mw.(gen) ==
                  sum(true_min_retirements[i].min_retired_cap_inverter_mw for i in 1:t)
            @test GenX.cum_min_retired_cap_solar_mw.(gen) ==
                  sum(true_min_retirements[i].min_retired_cap_solar_mw for i in 1:t)
            @test GenX.cum_min_retired_cap_wind_mw.(gen) ==
                  sum(true_min_retirements[i].min_retired_cap_wind_mw for i in 1:t)
            @test GenX.cum_min_retired_cap_discharge_dc_mw.(gen) ==
                  sum(true_min_retirements[i].min_retired_cap_discharge_dc_mw for i in 1:t)
            @test GenX.cum_min_retired_cap_charge_dc_mw.(gen) ==
                  sum(true_min_retirements[i].min_retired_cap_charge_dc_mw for i in 1:t)
            @test GenX.cum_min_retired_cap_discharge_ac_mw.(gen) ==
                  sum(true_min_retirements[i].min_retired_cap_discharge_ac_mw for i in 1:t)
            @test GenX.cum_min_retired_cap_charge_ac_mw.(gen) ==
                  sum(true_min_retirements[i].min_retired_cap_charge_ac_mw for i in 1:t)
        end
    end
end

test_update_cumulative_min_ret!()

end # module TestMultiStage
