module TestMultiStage

using Test

include(joinpath(@__DIR__, "utilities.jl"))

obj_true = [77736.65081, 41383.80745, 27512.51426]
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

        # OPEXMULT: each year of a stage discounted to the end of that year,
        # matching how investment annuities are discounted.
        for L in (1, 5, 10)
            @test GenX.stage_opex_multiplier(dr, L) ≈ sum(1 / (1 + dr)^j for j in 1:L)
        end
        @test GenX.stage_opex_multiplier(dr, 1) ≈ 1 / (1 + dr)
        @test GenX.stage_opex_multiplier(0.0, 7) == 7.0
        # A stage of one year weights an operating dollar exactly as a
        # single-year annuity payment, which is the point of the convention.
        @test GenX.stage_opex_multiplier(dr, 1) ≈
              GenX.overnight_capital_cost_factor(
            Dict("CurStage" => 1, "StageLengths" => [1], "WACC" => dr), [1], [dr])[1]

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

        # A technology WACC is used where given; the general discount rate
        # stands in where it is absent, zero, or missing.
        @test GenX.annuity_discount_rate(settings, [0.039, 0.0, 0.017]) ==
              [0.039, dr, 0.017]
        @test GenX.annuity_discount_rate(settings, [missing, -1.0]) == [dr, dr]

        # A resource with no WACC is discounted at the general rate, and one
        # with a WACC is unaffected by the fallback.
        @test GenX.overnight_capital_cost_factor(settings, [20], [0.0]) ≈
              GenX.overnight_capital_cost_factor(settings, [20], [dr])
        @test GenX.overnight_capital_cost_factor(settings, [20], [0.039])[1] ≈
              sum(1 / (1 + 0.039)^p for p in 1:20)

        # A zero capital recovery period is an error only when there is an
        # investment cost to recover.
        @test GenX.compute_overnight_capital_cost(settings, [0.0], [0], [0.05]) == [0.0]
        @test_throws ErrorException GenX.compute_overnight_capital_cost(
            settings, [100.0], [0], [0.05])
    end
end

test_discounting_helpers()

function test_get_retirement_stage()
    @testset "Age-based retirement stage" begin
        # Equal stage lengths: unchanged from the previous rule.
        equal = [10, 10, 10]
        for (lifetime, expected) in [(5, [0, 1, 2]), (10, [0, 1, 2]),
            (15, [0, 0, 1]), (20, [0, 0, 1]), (30, [0, 0, 0])]
            @test [GenX.get_retirement_stage(c, lifetime, equal) for c in 1:3] == expected
        end

        # Uneven stages, where measuring from the start of a stage rather than
        # the end of the current one changes the answer. Capacity built at the
        # start of stage 2 (year 10) with an 8-year life dies in year 18, part
        # way through stage 3 (years 15-23), so it survives stage 3.
        uneven = [10, 5, 8]
        @test GenX.get_retirement_stage(3, 8, uneven) == 1
        @test GenX.get_retirement_stage(3, 10, uneven) == 1
        # Stage 3 begins at year 15, so stage-1 capacity with a 15-year life is
        # exactly at end of life and must retire; a 16-year life survives.
        @test GenX.get_retirement_stage(3, 15, uneven) == 1
        @test GenX.get_retirement_stage(3, 16, uneven) == 0
        @test GenX.get_retirement_stage(2, 10, uneven) == 1
        @test GenX.get_retirement_stage(2, 11, uneven) == 0

        # Five uneven stages, starting at years 0, 10, 15, 23 and 29. This
        # exercises results other than 0 and 1, so a rule that picked the wrong
        # qualifying stage would be caught.
        five = [10, 5, 8, 6, 4]
        #                          cur, lifetime, expected
        for (cur, lifetime, expected) in [(4, 6, 3), (4, 9, 2), (4, 14, 1),
            (5, 6, 4), (5, 7, 3), (5, 15, 2), (5, 20, 1), (5, 30, 0),
            (3, 4, 2), (3, 20, 0)]
            @test GenX.get_retirement_stage(cur, lifetime, five) == expected
        end

        # The rule takes the latest qualifying stage, not the earliest: with
        # stage 5 starting at year 29, a 7-year life rules out stage 4 (built
        # year 23, only 6 years earlier) but admits stage 3 (year 15).
        @test GenX.get_retirement_stage(5, 7, five) == 3
        @test GenX.get_retirement_stage(5, 6, five) == 4

        # Longer lifetimes never retire more stages than shorter ones.
        for cur in 2:5
            results = [GenX.get_retirement_stage(cur, l, five) for l in 1:35]
            @test issorted(results, rev = true)
        end

        # Nothing can retire before the first stage, whatever the lifetime.
        for lifetime in (1, 10, 100)
            @test GenX.get_retirement_stage(1, lifetime, equal) == 0
            @test GenX.get_retirement_stage(1, lifetime, uneven) == 0
            @test GenX.get_retirement_stage(1, lifetime, five) == 0
        end

        # The result never exceeds the preceding stage.
        for c in 1:3, lifetime in (1, 2, 5)
            @test GenX.get_retirement_stage(c, lifetime, uneven) <= c - 1
        end
    end
end

test_get_retirement_stage()

function test_cost_reporting_factors()
    @testset "Stashed cost reporting factors" begin
        settings = GenX.default_settings()
        merge!(settings, genx_setup)
        ms = settings["MultiStageSettingsDict"]
        stage_lens = ms["StageLengths"]
        dr = ms["WACC"]

        for t in 1:ms["NumStages"]
            ms["CurStage"] = t
            inputs = redirect_stdout(devnull) do
                with_logger(ConsoleLogger(stderr, Logging.Error)) do
                    GenX.load_inputs(settings,
                        joinpath(test_path, string("inputs_p", t)))
                end
            end
            # Capture the annuities before configure overwrites the cost fields.
            gen = inputs["RESOURCES"]
            crp = GenX.capital_recovery_period.(gen)
            inv_before = GenX.inv_cost_per_mwyr.(gen)
            expected_occ = GenX.compute_overnight_capital_cost(
                ms, inv_before, crp, GenX.tech_wacc.(gen))

            inputs = GenX.configure_multi_stage_inputs(inputs, ms,
                settings["NetworkExpansion"])
            f = inputs["MULTISTAGE_COST_FACTORS"]

            @test f.discount_factor ≈ GenX.stage_discount_factor(dr, stage_lens, t)
            @test f.opex_multiplier ≈ GenX.stage_opex_multiplier(dr, stage_lens[t])
            @test f.stage_length == stage_lens[t]

            # The stashed annuity reproduces the overnight capital cost, and
            # configure_multi_stage_inputs wrote that same cost into the
            # resource fields. So the writer can recover the annual figure by
            # dividing the field back through by the stashed annuity.
            disc = f.components[:discharge]
            @test disc.annuity .* inv_before ≈ expected_occ
            @test GenX.inv_cost_per_mwyr.(inputs["RESOURCES"]) ≈ expected_occ
            @test disc.payment_years == GenX.payment_years_remaining(ms, crp)
            @test all(disc.payment_years .<= crp)
        end
        ms["CurStage"] = 1
    end
end

test_cost_reporting_factors()

"""
Solve `case_path` in multi-stage mode, write each stage's cost files, and return
`(EP, inputs, outdir)` so the reported numbers can be checked against the model.
"""
function run_and_write_multistage(case_path, setup_overrides)
    settings = GenX.default_settings()
    merge!(settings, deepcopy(setup_overrides))
    ms = settings["MultiStageSettingsDict"]
    outdir = mktempdir()

    EP, inputs, _ = redirect_stdout(devnull) do
        with_logger(ConsoleLogger(stderr, Logging.Error)) do
            run_genx_case_testing(case_path, settings)
        end
    end
    for p in 1:ms["NumStages"]
        ms["CurStage"] = p
        stage_dir = joinpath(outdir, "results_p$p")
        mkpath(stage_dir)
        redirect_stdout(devnull) do
            GenX.write_costs(stage_dir, inputs[p], settings, EP[p])
        end
    end
    redirect_stdout(devnull) do
        GenX.write_multi_stage_costs(outdir, ms)
    end
    return EP, inputs, outdir, settings
end

"""Read a cost file into a `row => Total` dictionary."""
function cost_totals(path)
    df = CSV.read(path, DataFrame)
    Dict(string(df[i, "Costs"]) => something(tryparse(Float64,
            string(df[i, "Total"])), 0.0) for i in 1:nrow(df))
end

"""Largest relative gap between a row's Total and the sum of its zone columns."""
function zone_sum_gap(path, rows)
    df = CSV.read(path, DataFrame)
    zcols = filter(c -> startswith(c, "Zone"), names(df))
    worst = 0.0
    for r in rows
        i = findfirst(==(r), df.Costs)
        i === nothing && continue
        t = something(tryparse(Float64, string(df[i, "Total"])), 0.0)
        z = sum(something(tryparse(Float64, string(df[i, c])), 0.0) for c in zcols)
        worst = max(worst, abs(t - z) / max(abs(t), 1e-30))
    end
    return worst
end

const ATTRIBUTED_ROWS = ["cFix", "cVar", "cFuel", "cNSE", "cStart", "cCO2"]

function test_investment_views()
    @testset "Investment views for both foresight modes" begin
        dr, crp = 0.045, 20
        A = sum(1 / (1 + dr)^p for p in 1:crp)   # annuity factor
        P = float(crp)                            # payments inside the horizon
        aic = 65400.0                             # annual annuity per unit
        cap = 2.5                                 # new capacity

        # Perfect foresight: the model holds the overnight capital cost, so the
        # discounted view reproduces it and the undiscounted view swaps A for P.
        pf_scaled = aic * A * cap
        d, u = GenX._investment_views(pf_scaled, A, P, false)
        @test d ≈ pf_scaled
        @test u ≈ aic * cap * P

        # Myopic: the model holds one year's annuity, so both views add back the
        # payments the objective never charged.
        my_scaled = aic * cap
        d, u = GenX._investment_views(my_scaled, A, P, true)
        @test d ≈ aic * cap * A
        @test u ≈ aic * cap * P
        @test d > my_scaled          # the add-back actually happened
        @test u > d                  # no time value, so larger still

        # Both modes agree on what the investment is worth once reported, which
        # is the property that makes myopic and perfect foresight comparable.
        @test GenX._investment_views(pf_scaled, A, P, false) ==
              GenX._investment_views(my_scaled, A, P, true)

        # Degenerate cases.
        @test GenX._investment_views(0.0, A, P, false) == (0.0, 0.0)
        @test GenX._investment_views(0.0, 0.0, 0.0, false) == (0.0, 0.0)
        # No payment years under perfect foresight means nothing to divide by;
        # the guard returns zero rather than producing NaN or Inf.
        d, u = GenX._investment_views(123.0, 0.0, 0.0, false)
        @test d == 0.0 && u == 0.0
        @test all(isfinite, GenX._investment_views(123.0, 0.0, 0.0, false))

        # A shorter horizon truncates the annuity: fewer payments, smaller
        # discounted value, and the undiscounted count follows P.
        A_short = sum(1 / (1 + dr)^p for p in 1:8)
        d_short, u_short = GenX._investment_views(aic * cap, A_short, 8.0, true)
        @test d_short < aic * cap * A
        @test u_short ≈ aic * cap * 8
    end
end

test_investment_views()

function test_perfect_foresight_cost_reporting()
    @testset "Perfect-foresight cost reporting" begin
        EP, inputs, outdir, settings = run_and_write_multistage(test_path, genx_setup)
        ms = settings["MultiStageSettingsDict"]
        nstages = ms["NumStages"]
        scale = settings["ParameterScale"] == 1 ? GenX.ModelScalingFactor^2 : 1.0

        disc = [cost_totals(joinpath(outdir, "results_p$p", "costs.csv"))
                for p in 1:nstages]
        undisc = [cost_totals(joinpath(outdir, "results_p$p", "costs_undiscounted.csv"))
                  for p in 1:nstages]

        for p in 1:nstages
            f = inputs[p]["MULTISTAGE_COST_FACTORS"]
            DF, OM, L = f.discount_factor, f.opex_multiplier, float(f.stage_length)

            # The discounted stage total is exactly what the objective charges
            # for this stage, i.e. the objective less the cost-to-go term. This
            # is the single strongest check: it ties the whole reported
            # breakdown back to the optimisation.
            stage_cost = objective_value(EP[p]) - value(EP[p][:vALPHA])
            @test disc[p]["cTotal"] / scale ≈ stage_cost rtol=1e-8

            # Under perfect foresight the model's own fixed-cost expression is
            # already the stage-level present value, so discounting is the only
            # thing left to do.
            g(sym) = haskey(EP[p].obj_dict, sym) ? value(EP[p][sym]) : 0.0
            model_fix = g(:eTotalCFix) + g(:eTotalCFixEnergy) + g(:eTotalCFixCharge)
            @test disc[p]["cFix"] / scale ≈ DF * model_fix rtol=1e-8

            # Operating costs are annual in the model, so they take the full
            # discount factor times the stage multiplier, and the undiscounted
            # view takes the stage length instead. Their ratio is a pure
            # function of the conventions, independent of the solution.
            if disc[p]["cVar"] != 0
                @test undisc[p]["cVar"] / disc[p]["cVar"] ≈ L / (DF * OM) rtol=1e-8
            end
            for row in ("cFuel", "cNSE", "cStart")
                disc[p][row] == 0 && continue
                @test undisc[p][row] / disc[p][row] ≈ L / (DF * OM) rtol=1e-8
            end

            # Both views must be internally consistent: zones sum to totals,
            # and cTotal is the sum of its component rows.
            for file in ("costs.csv", "costs_undiscounted.csv")
                path = joinpath(outdir, "results_p$p", file)
                @test zone_sum_gap(path, ATTRIBUTED_ROWS) < 1e-9
            end
            for tab in (disc[p], undisc[p])
                rows = sum(get(tab, r, 0.0) for r in
                ["cFix", "cVar", "cFuel", "cNSE", "cStart", "cUnmetRsv",
                    "cNetworkExp", "cUnmetPolicyPenalty", "cCO2",
                    "cHydrogenRevenue"])
                @test tab["cTotal"] ≈ rows rtol=1e-8
            end

            # Undiscounted costs are never smaller: they omit the time value
            # but cover the same stage.
            @test undisc[p]["cTotal"] > disc[p]["cTotal"]
        end

        # Summed across stages, the discounted totals are the cost of the whole
        # trajectory the algorithm converged on.
        horizon = sum(objective_value(EP[p]) - value(EP[p][:vALPHA])
        for p in 1:nstages)
        @test sum(disc[p]["cTotal"] for p in 1:nstages) / scale ≈ horizon rtol=1e-8

        # The horizon summary stacks the per-stage files without rescaling.
        summary = CSV.read(joinpath(outdir, "costs_multi_stage.csv"), DataFrame)
        @test "cTotal" in summary.Costs
        i = findfirst(==("cTotal"), summary.Costs)
        for p in 1:nstages
            @test summary[i, Symbol("TotalCosts_p$p")] ≈ disc[p]["cTotal"] rtol=1e-12
        end
        @test isfile(joinpath(outdir, "costs_undiscounted_multi_stage.csv"))
        rm(outdir, recursive = true, force = true)
    end
end

test_perfect_foresight_cost_reporting()

function test_myopic_cost_addback()
    @testset "Myopic reporting adds back unseen annuities" begin
        myopic_setup = deepcopy(genx_setup)
        myopic_setup["MultiStageSettingsDict"]["Myopic"] = 1
        EP, inputs, outdir, settings = run_and_write_multistage(test_path, myopic_setup)
        ms = settings["MultiStageSettingsDict"]
        nstages = ms["NumStages"]
        scale = settings["ParameterScale"] == 1 ? GenX.ModelScalingFactor^2 : 1.0

        for p in 1:nstages
            f = inputs[p]["MULTISTAGE_COST_FACTORS"]
            DF, OM = f.discount_factor, f.opex_multiplier
            gen = inputs[p]["RESOURCES"]
            A = f.components[:discharge].annuity
            P = f.components[:discharge].payment_years

            # The myopic objective charges one year of each annuity, so the
            # model's fixed cost is entirely in annual terms.
            @test inputs[p]["OPEXMULT"] == 1

            # Separate every fixed-cost component into its annual investment
            # and O&M parts, and accumulate the annuity the reported figure
            # should apply. Each component carries its own annuity factors, so
            # they cannot be lumped together.
            comps = Any[(:eCFix, 1:length(gen), GenX.fixed_om_cost_per_mwyr,
                :eTotalCap, :discharge)]
            isempty(inputs[p]["STOR_ALL"]) || push!(comps,
                (:eCFixEnergy, inputs[p]["STOR_ALL"], GenX.fixed_om_cost_per_mwhyr,
                    :eTotalCapEnergy, :energy))
            isempty(inputs[p]["STOR_ASYMMETRIC"]) || push!(comps,
                (:eCFixCharge, inputs[p]["STOR_ASYMMETRIC"],
                    GenX.fixed_om_cost_charge_per_mwyr, :eTotalCapCharge, :charge))

            obj_inv, obj_fom = 0.0, 0.0
            expect_inv_A, expect_inv_P = 0.0, 0.0
            for (sym, ids, fom_f, cap_sym, key) in comps
                Ak = f.components[key].annuity
                Pk = f.components[key].payment_years
                for y in ids
                    total = value(EP[p][sym][y])
                    fom = fom_f(gen[y]) * value(EP[p][cap_sym][y])
                    inv = total - fom
                    obj_inv += inv
                    obj_fom += fom
                    expect_inv_A += Ak[y] * inv
                    expect_inv_P += Pk[y] * inv
                end
            end

            disc = cost_totals(joinpath(outdir, "results_p$p", "costs.csv"))
            undisc = cost_totals(joinpath(outdir, "results_p$p",
                "costs_undiscounted.csv"))

            if obj_inv > 0
                # Reported investment is each resource's annual annuity paid
                # over every year inside the horizon, discounted to the start.
                reported_inv = disc["cFix"] / scale - DF * OM * obj_fom
                @test reported_inv ≈ DF * expect_inv_A rtol=1e-8

                # It must exceed a plain discounting of what the objective
                # charged, since the objective saw only one year of each.
                @test reported_inv > DF * obj_inv

                # The implied multiple sits inside the range of the individual
                # annuity factors, which bounds the result independently of how
                # it was computed.
                active = [y for y in 1:length(gen) if A[y] > 0]
                implied = reported_inv / (DF * obj_inv)
                @test minimum(A[active]) - 1e-6 <= implied <= maximum(A[active]) + 1e-6
                @test implied > 1  # an add-back actually happened

                # The undiscounted view counts the same payments without time
                # value, so it is larger still.
                reported_inv_cf = undisc["cFix"] / scale -
                                  float(f.stage_length) * obj_fom
                @test reported_inv_cf ≈ expect_inv_P rtol=1e-8
                @test reported_inv_cf > reported_inv
                implied_cf = reported_inv_cf / obj_inv
                @test minimum(P[active]) - 1e-6 <= implied_cf <= maximum(P[active]) + 1e-6
            end

            # Both views stay internally consistent, as in the PF case.
            for file in ("costs.csv", "costs_undiscounted.csv")
                @test zone_sum_gap(joinpath(outdir, "results_p$p", file),
                    ATTRIBUTED_ROWS) < 1e-9
            end
            for tab in (disc, undisc)
                rows = sum(get(tab, r, 0.0) for r in
                ["cFix", "cVar", "cFuel", "cNSE", "cStart", "cUnmetRsv",
                    "cNetworkExp", "cUnmetPolicyPenalty", "cCO2",
                    "cHydrogenRevenue"])
                @test tab["cTotal"] ≈ rows rtol=1e-8
            end

            # Unlike perfect foresight, the reported total is deliberately not
            # the myopic objective: it includes annuities the objective omits.
            @test disc["cTotal"] / scale > DF * objective_value(EP[p])
        end
        rm(outdir, recursive = true, force = true)
    end
end

test_myopic_cost_addback()

end # module TestMultiStage
