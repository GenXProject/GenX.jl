module TestMultiStageAnalytical

# An end-to-end check of multi-stage cost reporting against hand-computed
# values, rather than against the code that produced them.
#
# The case is built so the optimal solution is forced: one zone, one thermal
# generator with no existing capacity, flat demand that steps up each stage,
# and no storage, renewables, network, policies or unit commitment. The
# generator must therefore build exactly the peak demand and run flat out, so
# capacity, generation and new build are known before solving and every cost
# follows arithmetically from the inputs.
#
# Stage lengths are deliberately uneven (10, 5, 8 years) so that the annuity
# truncation at the horizon differs by stage: with a 20-year recovery period the
# payments inside the horizon are 20, 13 and 8.

using Test

include(joinpath(@__DIR__, "utilities.jl"))

const CASE = joinpath(@__DIR__, "multi_stage_analytical")

# --- inputs, mirrored from the fixture CSVs --------------------------------
const STAGE_LENS = [10, 5, 8]
const DR = 0.05
const CRP = 20
const AIC = 100_000.0     # Inv_Cost_per_MWyr
const FOM = 10_000.0      # Fixed_OM_Cost_per_MWyr
const VOM = 5.0           # Var_OM_Cost_per_MWh
const HEAT_RATE = 10.0    # MMBTU_per_MWh
const FUEL_PRICE = 3.0    # $/MMBTU
const HOURS = 8760.0
const DEMAND = [100.0, 150.0, 200.0]
const NEWCAP = [100.0, 50.0, 50.0]     # demand less what the previous stage left

# --- the conventions, written out independently of GenX --------------------
"Years elapsed before stage i begins."
years_before(i) = sum(STAGE_LENS[1:(i - 1)]; init = 0)
"Discount a stage cost back to the start of the horizon."
df(i) = 1 / (1 + DR)^years_before(i)
"Annual operating cost to stage level, each year discounted to its end."
opexmult(i) = sum(1 / (1 + DR)^j for j in 1:STAGE_LENS[i])
"Annuity payments falling inside the horizon."
paym(i) = min(CRP, sum(STAGE_LENS[i:end]))
"Annuity factor over those payments."
annuity(i) = sum(1 / (1 + DR)^p for p in 1:paym(i))

# --- the expected cost of each stage ---------------------------------------
inv_annual(i) = AIC * NEWCAP[i]
fom_annual(i) = FOM * DEMAND[i]
var_annual(i) = VOM * DEMAND[i] * HOURS
fuel_annual(i) = HEAT_RATE * FUEL_PRICE * DEMAND[i] * HOURS

expected_discounted(i) = df(i) * (annuity(i) * inv_annual(i) +
                          opexmult(i) * (fom_annual(i) + var_annual(i) + fuel_annual(i)))
expected_undiscounted(i) = paym(i) * inv_annual(i) +
                           STAGE_LENS[i] * (fom_annual(i) + var_annual(i) + fuel_annual(i))

function run_case()
    ms = Dict("NumStages" => 3, "StageLengths" => STAGE_LENS, "WACC" => DR,
        "ConvergenceTolerance" => 1e-6, "Myopic" => 0,
        "WriteIntermittentOutputs" => 0)
    gs = Dict("MultiStage" => 1, "MultiStageSettingsDict" => ms,
        "ParameterScale" => 0, "UCommit" => 0, "OperationalReserves" => 0,
        "CO2Cap" => 0, "StorageLosses" => 0)
    settings = GenX.default_settings()
    merge!(settings, gs)

    EP, inputs, _ = redirect_stdout(devnull) do
        with_logger(ConsoleLogger(stderr, Logging.Error)) do
            run_genx_case_testing(CASE, settings)
        end
    end
    outdir = mktempdir()
    for p in 1:3
        settings["MultiStageSettingsDict"]["CurStage"] = p
        d = joinpath(outdir, "results_p$p")
        mkpath(d)
        redirect_stdout(devnull) do
            GenX.write_costs(d, inputs[p], settings, EP[p])
        end
    end
    return EP, inputs, outdir
end

totals(path) = begin
    df_ = CSV.read(path, DataFrame)
    Dict(string(df_[i, "Costs"]) => something(tryparse(Float64,
            string(df_[i, "Total"])), 0.0) for i in 1:nrow(df_))
end

@testset "Multi-stage costs against hand-computed values" begin
    EP, inputs, outdir = run_case()

    # The solution must be the forced one, or the hand computation is moot.
    for p in 1:3
        @test value(EP[p][:eTotalCap][1]) ≈ DEMAND[p] rtol=1e-6
        @test value(EP[p][:vCAP][1]) ≈ NEWCAP[p] rtol=1e-6
        @test value(EP[p][:eTotalCNSE]) ≈ 0 atol=1e-6
    end

    # The truncation really does differ by stage, so the case exercises it.
    @test [paym(i) for i in 1:3] == [20, 13, 8]

    for p in 1:3
        disc = totals(joinpath(outdir, "results_p$p", "costs.csv"))
        undisc = totals(joinpath(outdir, "results_p$p", "costs_undiscounted.csv"))

        @test disc["cTotal"] ≈ expected_discounted(p) rtol=1e-6
        @test undisc["cTotal"] ≈ expected_undiscounted(p) rtol=1e-6

        # And each component separately, so a failure localises.
        @test disc["cFix"] ≈ df(p) * (annuity(p) * inv_annual(p) +
                                      opexmult(p) * fom_annual(p)) rtol=1e-6
        @test disc["cVar"] ≈ df(p) * opexmult(p) * var_annual(p) rtol=1e-6
        @test disc["cFuel"] ≈ df(p) * opexmult(p) * fuel_annual(p) rtol=1e-6
        @test undisc["cFix"] ≈ paym(p) * inv_annual(p) +
                               STAGE_LENS[p] * fom_annual(p) rtol=1e-6
        @test undisc["cVar"] ≈ STAGE_LENS[p] * var_annual(p) rtol=1e-6
        @test undisc["cFuel"] ≈ STAGE_LENS[p] * fuel_annual(p) rtol=1e-6
    end

    # The discounted stage total is what the objective charges for that stage.
    for p in 1:3
        disc = totals(joinpath(outdir, "results_p$p", "costs.csv"))
        @test disc["cTotal"] ≈ objective_value(EP[p]) - value(EP[p][:vALPHA]) rtol=1e-6
    end

    rm(outdir, recursive = true, force = true)
end

end # module
