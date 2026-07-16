module TestDCOPFExpansion

using Test
using CSV, DataFrames
using YAML

include(joinpath(@__DIR__, "utilities.jl"))

# Reduced (24-hour) IEEE 9-bus DC-OPF case with integer transmission expansion.
# Reference objective captured from a HiGHS solve at mip_rel_gap = 1e-6.
obj_true = 554906.257731
test_path = joinpath(@__DIR__, "DCOPF_expansion")

# Define test inputs: DC-OPF + network expansion + discrete (integer) line builds.
genx_setup = Dict("DC_OPF" => 1,
    "NetworkExpansion" => 1,
    "DiscreteInvestments" => 1,
    "Trans_Loss_Segments" => 0,
    "StorageLosses" => 0)

# Run the case
EP, _, _ = redirect_stdout(devnull) do
    run_genx_case_testing(test_path, genx_setup)
end
obj_test = objective_value(EP)

# This is a MILP (binary transmission builds), so the solver's interior-point tolerance does not
# bound the objective gap. Use a fixed relative tolerance comfortably above the MIP gap (1e-6).
optimal_tol = 1.0e-3 * abs(obj_true)

# Test the objective value
test_result = @test obj_test≈obj_true atol=optimal_tol

# Confirm the integer network-expansion path was actually exercised: the model solved to optimality
# and at least one discrete candidate line was built (with a non-zero expansion cost).
@test termination_status(EP) == JuMP.MOI.OPTIMAL
@test sum(round.(Int, value.(EP[:vNEW_TRANS_LINES]))) >= 1
@test value(EP[:eTotalCNetworkExp]) > 0

# Round objective value and tolerance. Write to test log.
obj_test = round_from_tol!(obj_test, optimal_tol)
optimal_tol = round_from_tol!(optimal_tol, optimal_tol)
write_testlog(test_path, obj_test, optimal_tol, test_result)

# ---------------------------------------------------------------------------
# Benders decomposition on the same system
# ---------------------------------------------------------------------------
# Same system as the monolithic test above (test/DCOPF_expansion/), but driven through
# run_genx_case!, which is the only entry point that runs Benders. That path reads its settings from
# test/DCOPF_expansion/settings/ rather than taking a genx_setup dict, so the two runs are kept in
# sync by hand: settings/genx_settings.yml must carry the same DC_OPF / NetworkExpansion /
# DiscreteInvestments / Trans_Loss_Segments / StorageLosses values as `genx_setup` above.
# The Benders upper bound is compared against the same monolithic optimum, obj_true.

# Gurobi gives sharper duals for the Benders cuts; fall back to HiGHS when it is not installed.
# const GUROBI_AVAILABLE = !isnothing(Base.find_package("Gurobi"))
# if GUROBI_AVAILABLE
#     using Gurobi
# end
# const BENDERS_OPTIMIZER = GUROBI_AVAILABLE ? Gurobi.Optimizer : HiGHS.Optimizer
const BENDERS_OPTIMIZER = HiGHS.Optimizer

const BENDERS_PATH = test_path
const BENDERS_SETTINGS_FILE = joinpath(BENDERS_PATH, "settings", "benders_settings.yml")

# Each testset rewrites benders_settings.yml with its own flags; put the committed version back
# afterwards so a test run leaves no diff behind.
const BENDERS_SETTINGS_ORIGINAL = read(BENDERS_SETTINGS_FILE, String)

# Relative tolerance on the Benders UB vs. the monolithic optimum. Looser than ConvTol because the
# planning problem is a MILP solved to its own MIPGap on top of the Benders convergence tolerance.
const BENDERS_RTOL = 1.0e-2

"""
Write `settings` to the case's benders_settings.yml, run the Benders case, and return the last row
of the convergence history as `(UB, LB, gap, iterations)`. `nothing` if no history was written.
"""
function run_benders_dcopf_expansion(settings::Dict)
    YAML.write_file(BENDERS_SETTINGS_FILE, settings)
    results_dir = joinpath(BENDERS_PATH, "results_benders")
    rm(results_dir; recursive = true, force = true)

    redirect_stdout(devnull) do
        run_genx_case!(BENDERS_PATH, BENDERS_OPTIMIZER)
    end

    conv_csv = joinpath(results_dir, "benders_convergence.csv")
    isfile(conv_csv) || return nothing

    df = CSV.read(conv_csv, DataFrame)
    last_row = df[end, :]
    ub, lb = last_row[:UB], last_row[:LB]
    return (UB = ub, LB = lb, gap = abs(ub - lb) / max(abs(ub), 1.0), iterations = nrow(df))
end

# Shared Benders configuration.
#   StabParam > 0        — level-set regularization, so RegularizationPostHotstart has something to
#                          keep switched on after the hot-start passes.
#   ExpectFeasibleSubproblems = false — generate feasibility cuts; the subproblems really are
#                          infeasible for some of the early transmission builds.
#   IntegerInvestment    — deliberately absent (defaults to false). GenX's LP hot-starts perform the
#                          integer relaxation themselves; MacroEnergySolvers' own integer routine
#                          must not also run. run_genx_case! forces it off when hot-starts are on.
benders_settings = Dict{String, Any}("ConvTol" => 1.0e-3,
    "MaxIter" => 300,
    "MaxCpuTime" => 7200,
    "StabParam" => 0.0,
    "StabDynamic" => false,
    "ExpectFeasibleSubproblems" => false,
    "RunTransportModel" => true,
    "LPTransportHotstart" => true,
    "LPDCOPFHotstart" => true,
    "RegularizationPostHotstart" => false)

@testset "Benders with LP hot-starts" begin
    res = run_benders_dcopf_expansion(benders_settings)

    @test res !== nothing
    if res !== nothing
        # Converged to the Benders tolerance...
        converged = @test res.gap≤benders_settings["ConvTol"]
        # ...and to the same optimum as the monolithic MILP.
        rel_diff = abs(res.UB - obj_true) / abs(obj_true)
        parity = @test rel_diff ≤ BENDERS_RTOL

        write_testlog(BENDERS_PATH,
            "hotstart | UB=$(res.UB) LB=$(res.LB) gap=$(round(res.gap; sigdigits = 3)) " *
            "iters=$(res.iterations) | monolithic=$obj_true rel_diff=$(round(rel_diff; sigdigits = 3))",
            parity)
    end
end

rm(joinpath(BENDERS_PATH, "results_benders"); recursive = true, force = true)
write(BENDERS_SETTINGS_FILE, BENDERS_SETTINGS_ORIGINAL)

end # module TestDCOPFExpansion
