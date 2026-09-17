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
    "Myopic" => 0,
    "WriteIntermittentOutputs" => 0)

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
# Use the Benders convergence tolerance as the comparison bound — the IPM solver
# tolerance is far tighter than what Benders guarantees across different HiGHS versions.
benders_tol_rel = multistage_setup["ConvergenceTolerance"]
optimal_tol = benders_tol_rel .* abs.(obj_true)

# Test the objective value
# There can be degenerate solutions with DDP, so each stage's objective value may not match the known optimal value, but the sum across stages should be within the relative tolerance.
test_result = @test all(obj_true .- optimal_tol .<= obj_test .<= obj_true .+ optimal_tol) ? true : abs((sum(obj_test) - sum(obj_true)) / sum(obj_true)) ≤ benders_tol_rel

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

                    true_min_retirements[t] = CSV.read(
                        joinpath(inpath_sub,
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

function test_can_retire_validation()
    @testset "No resources switch from can_retire = 0 to can_retire = 1" begin
        inputs = Dict{Int, Dict}()
        inputs[1] = Dict("RESOURCES" => [
            GenX.Thermal(Dict(:resource => "thermal", :id => 1,
                :can_retire => 1)),
            GenX.Vre(Dict(:resource => "vre", :id => 2,
                :can_retire => 1)),
            GenX.Hydro(Dict(:resource => "hydro", :id => 3,
                :can_retire => 1)),
            GenX.FlexDemand(Dict(:resource => "flex_demand", :id => 4,
                :can_retire => 1))])
        inputs[2] = Dict("RESOURCES" => [
            GenX.Thermal(Dict(:resource => "thermal", :id => 1,
                :can_retire => 0)),
            GenX.Vre(Dict(:resource => "vre", :id => 2,
                :can_retire => 1)),
            GenX.Hydro(Dict(:resource => "hydro", :id => 3,
                :can_retire => 1)),
            GenX.FlexDemand(Dict(:resource => "flex_demand", :id => 4,
                :can_retire => 1))])
        inputs[3] = Dict("RESOURCES" => [
            GenX.Thermal(Dict(:resource => "thermal", :id => 1,
                :can_retire => 0)),
            GenX.Vre(Dict(:resource => "vre", :id => 2,
                :can_retire => 0)),
            GenX.Hydro(Dict(:resource => "hydro", :id => 3,
                :can_retire => 1)),
            GenX.FlexDemand(Dict(:resource => "flex_demand", :id => 4,
                :can_retire => 1))])
        @test isnothing(GenX.validate_can_retire_multistage(inputs, 3))
    end

    @testset "One resource switches from can_retire = 0 to can_retire = 1" begin
        inputs = Dict{Int, Dict}()
        inputs[1] = Dict("RESOURCES" => [
            GenX.Thermal(Dict(:resource => "thermal", :id => 1,
                :can_retire => 0)),
            GenX.Vre(Dict(:resource => "vre", :id => 2,
                :can_retire => 0)),
            GenX.Hydro(Dict(:resource => "hydro", :id => 3,
                :can_retire => 0)),
            GenX.FlexDemand(Dict(:resource => "flex_demand", :id => 4,
                :can_retire => 1))])
        inputs[2] = Dict("RESOURCES" => [
            GenX.Thermal(Dict(:resource => "thermal", :id => 1,
                :can_retire => 0)),
            GenX.Vre(Dict(:resource => "vre", :id => 2,
                :can_retire => 0)),
            GenX.Hydro(Dict(:resource => "hydro", :id => 3,
                :can_retire => 1)),
            GenX.FlexDemand(Dict(:resource => "flex_demand", :id => 4,
                :can_retire => 1))])
        inputs[3] = Dict("RESOURCES" => [
            GenX.Thermal(Dict(:resource => "thermal", :id => 1,
                :can_retire => 0)),
            GenX.Vre(Dict(:resource => "vre", :id => 2,
                :can_retire => 0)),
            GenX.Hydro(Dict(:resource => "hydro", :id => 3,
                :can_retire => 1)),
            GenX.FlexDemand(Dict(:resource => "flex_demand", :id => 4,
                :can_retire => 1))])
        @test_throws ErrorException GenX.validate_can_retire_multistage(inputs, 3)
    end
end

with_logger(ConsoleLogger(stderr, Logging.Error)) do
    test_can_retire_validation()
end

function test_discounting_helpers()
    @testset "Discounting helpers reproduce the inline expressions" begin
        dr = 0.045

        # OPEXMULT: each year of a stage discounted to the start of that year.
        for L in (1, 5, 10)
            @test GenX.stage_opex_multiplier(dr, L) ≈
                  sum([1 / (1 + dr)^(i - 1) for i in range(1, stop = L)])
        end
        @test GenX.stage_opex_multiplier(dr, 1) == 1.0
        @test GenX.stage_opex_multiplier(0.0, 7) == 7.0

        # Stage discount factor: years elapsed before the stage begins. Checked
        # for uneven stages too, which GenX supports.
        for stage_lens in ([10, 10, 10], [10, 5, 8])
            for p in 1:3
                @test GenX.stage_discount_factor(dr, stage_lens, p) ≈
                      1 / (1 + dr)^sum(stage_lens[1:(p - 1)]; init = 0)
            end
            @test GenX.stage_discount_factor(dr, stage_lens, 1) == 1.0
        end

        # Payment years: capital recovery period truncated at the horizon.
        settings = Dict("CurStage" => 1, "NumStages" => 3, "WACC" => dr,
            "StageLengths" => [10, 5, 8])
        @test GenX.payment_years_remaining(settings, [20, 40, 5]) == [20, 23, 5]
        settings["CurStage"] = 2
        @test GenX.payment_years_remaining(settings, [20, 40, 5]) == [13, 13, 5]
        settings["CurStage"] = 3
        @test GenX.payment_years_remaining(settings, [20, 40, 5]) == [8, 8, 5]

        # Overnight capital cost is the annuity times the factor, matching the
        # original per-resource loop.
        settings["CurStage"] = 1
        crp, wacc = [20, 40, 5], [0.039, 0.017, 0.027]
        inv = [65400.0, 41000.0, 12000.0]
        payment_yrs = GenX.payment_years_remaining(settings, crp)
        expected = [sum(inv[i] / (1 + wacc[i])^p for p in 1:payment_yrs[i]; init = 0.0)
                    for i in eachindex(inv)]
        @test GenX.compute_overnight_capital_cost(settings, inv, crp, wacc) ≈ expected
        @test GenX.overnight_capital_cost_factor(settings, crp, wacc) .* inv ≈ expected

        # A zero capital recovery period is an error only when there is an
        # investment cost to recover.
        @test GenX.compute_overnight_capital_cost(settings, [0.0], [0], [0.05]) == [0.0]
        @test_throws ErrorException GenX.compute_overnight_capital_cost(
            settings, [100.0], [0], [0.05])
    end
end

test_discounting_helpers()

end # module TestMultiStage
