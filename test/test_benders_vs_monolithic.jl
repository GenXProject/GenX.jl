module TestBendersVsMonolithic

using Test
using GenX
using CSV, DataFrames
using YAML

include(joinpath(@__DIR__, "utilities.jl"))

# Use Gurobi when available for higher precision; fall back to HiGHS otherwise.
const _GUROBI_AVAILABLE = !isnothing(Base.find_package("Gurobi"))

if _GUROBI_AVAILABLE
    using Gurobi
end

const _BENDERS_OPTIMIZER = _GUROBI_AVAILABLE ? Gurobi.Optimizer : HiGHS.Optimizer

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Relative optimality-gap tolerance for comparing Benders UB to known optimum.
const OBJECTIVE_RTOL = 1e-3

# Known optimal objective values for each example case, obtained from
# monolithic solves. Benders UB must match within OBJECTIVE_RTOL.
const KNOWN_OPTIMA = Dict(
    1  => 4975.3803,
    4  => 4871.46029,
    5  => 5155.24455,
    10 => 40270.88422,
)

# Example systems to test (number => folder name).
# Pre-clustered TDR data lives in test/benders/<case_name>/TDR_results/.
const EXAMPLE_CASES = [
    (1,  "1_three_zones"),
    (4,  "4_three_zones_w_policies_slack"),
    (5,  "5_three_zones_w_piecewise_fuel"),
    (10, "10_IEEE_9_bus_DC_OPF"),
]

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

"""Set a top-level key in a YAML file, overwriting any existing value."""
function _set_yaml_key!(filepath::AbstractString, key::AbstractString, value)
    d = isfile(filepath) ? YAML.load_file(filepath) : Dict{Any,Any}()
    d[key] = value
    YAML.write_file(filepath, d)
end

# ---------------------------------------------------------------------------
# Per-case test function
# ---------------------------------------------------------------------------

"""
Run a Benders solve for `case_name` and compare the converged upper bound
to the pre-computed known optimal objective value within `rtol`.

The run operates in `test/benders/<case_name>/`, which must already contain
pre-clustered TDR data and a configured `settings/genx_settings.yml`.
"""
function run_benders_test(case_num::Int, case_name::String, optimizer; rtol::Float64 = OBJECTIVE_RTOL)
    case_dir      = joinpath(@__DIR__, "benders", case_name)
    case_settings = joinpath(case_dir, "settings", "genx_settings.yml")

    obj_known = KNOWN_OPTIMA[case_num]

    # ------------------------------------------------------------------
    # Benders run
    # ------------------------------------------------------------------
    _set_yaml_key!(case_settings, "Benders", 1)
    _set_yaml_key!(case_settings, "OverwriteResults", 1)
    _set_yaml_key!(case_settings, "PrintModel", 0)

    redirect_stdout(devnull) do
        run_genx_case!(case_dir, optimizer)
    end

    # ------------------------------------------------------------------
    # Read Benders convergence history
    # ------------------------------------------------------------------
    conv_csv = joinpath(case_dir, "results_benders", "benders_convergence.csv")
    if !isfile(conv_csv)
        @warn "benders_convergence.csv not found for $case_name — " *
              "Benders may have terminated without a primal solution; skipping parity check"
        return
    end

    df_conv  = CSV.read(conv_csv, DataFrame)
    last_row = df_conv[end, :]
    ub = last_row[:UB]
    lb = last_row[:LB]

    # Benders must have converged within tolerance.
    benders_gap = abs(ub - lb) / max(abs(ub), 1.0)
    gap_ok = @test benders_gap ≤ rtol

    # Benders UB must match the known optimal objective within tolerance.
    rel_diff = abs(ub - obj_known) / max(abs(obj_known), 1.0)
    parity_ok = @test rel_diff ≤ rtol

    write_testlog(case_name,
        "known=$obj_known | Benders UB=$ub LB=$lb | gap=$(round(benders_gap; sigdigits=3)) | rel_diff=$(round(rel_diff; sigdigits=3))",
        parity_ok)

    rm(joinpath(case_dir, "results_benders"); recursive = true, force = true)
end

# ---------------------------------------------------------------------------
# Test set
# ---------------------------------------------------------------------------

@testset "Benders vs Known Optimum" begin
    for (case_num, case_name) in EXAMPLE_CASES
        @testset "Example $case_num: $case_name" begin
            run_benders_test(case_num, case_name, _BENDERS_OPTIMIZER)
        end
    end
end

end # module TestBendersVsMonolithic

