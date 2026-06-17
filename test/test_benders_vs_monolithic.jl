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

# Relative optimality-gap tolerance for comparing Benders UB to monolithic objective.
const OBJECTIVE_RTOL = 1e-3

# Test TDR settings file (4 × 6-hour periods).
const TEST_TDR_SETTINGS        = joinpath(@__DIR__, "benders", "test_tdr_settings.yml")
const TEST_TDR_FOLDER          = "TDR_results"

# Example systems to test (number => folder name).
const EXAMPLE_CASES = [
    (1,  "1_three_zones"),
    (2,  "2_three_zones_w_electrolyzer_and_hourly_matching"),
    (3,  "3_three_zones_w_co2_capture"),
    (4,  "4_three_zones_w_policies_slack"),
    (5,  "5_three_zones_w_piecewise_fuel"),
    (7,  "7_three_zones_w_colocated_VRE_storage"),
    (10, "10_IEEE_9_bus_DC_OPF"),
    (11, "11_three_zones_w_allam_cycle_lox"),
]

# Cases that ship with pre-built short-horizon system data in test/benders/<case_name>/.
# These cases skip TDR entirely (data is already small enough to solve directly).
const _CASES_SHORT_HORIZON = Dict{Int, String}(
    10 => joinpath(@__DIR__, "benders", "10_IEEE_9_bus_DC_OPF"),
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

"""Copy every item (files and subdirectories) from `src` into `dst`."""
function _copy_dir(src::AbstractString, dst::AbstractString)
    for item in readdir(src; join = false)
        cp(joinpath(src, item), joinpath(dst, item); force = true)
    end
end

"""
Overwrite system CSV files in `dst_dir/system/` with pre-built short-horizon
versions from `src_dir`, if they exist.
"""
function _inject_short_horizon_data!(dst_dir::AbstractString, src_dir::AbstractString)
    system_dst = joinpath(dst_dir, "system")
    for filename in readdir(src_dir; join = false)
        cp(joinpath(src_dir, filename), joinpath(system_dst, filename); force = true)
    end
end

"""Set a top-level key in a YAML file, overwriting any existing value."""
function _set_yaml_key!(filepath::AbstractString, key::AbstractString, value)
    d = isfile(filepath) ? YAML.load_file(filepath) : Dict{Any,Any}()
    d[key] = value
    YAML.write_file(filepath, d)
end

# ---------------------------------------------------------------------------
# Per-case comparison function
# ---------------------------------------------------------------------------

"""
Run a monolithic solve and a Benders solve for `case_name`, then compare
the Benders upper bound to the monolithic objective value within `rtol`.

Both runs operate in temporary directories that are removed on exit.
If `genx_benders_settings.yml` exists in the example, it is used as the
base `genx_settings.yml` for both runs so that the model configuration is
identical and the only difference is whether Benders decomposition is active.
"""
function run_benders_comparison(case_num::Int, case_name::String, optimizer; rtol::Float64 = OBJECTIVE_RTOL)
    base_path = Base.dirname(Base.dirname(pathof(GenX)))
    example_path = joinpath(base_path, "example_systems", case_name)
    short_horizon_src = get(_CASES_SHORT_HORIZON, case_num, nothing)
    use_tdr = isnothing(short_horizon_src)

    mono_dir    = mktempdir()
    benders_dir = mktempdir()

    try
        # ------------------------------------------------------------------
        # Common setup: decide which genx_settings.yml to use as the base.
        # genx_benders_settings.yml (if present) contains settings tuned
        # for Benders (e.g. HourlyMatchingRequirement, ParameterScale) that
        # must also be active in the monolithic run for a fair comparison.
        # ------------------------------------------------------------------
        benders_genx_src = joinpath(example_path, "settings", "genx_benders_settings.yml")
        has_benders_genx = isfile(benders_genx_src)

        # ------------------------------------------------------------------
        # Monolithic run
        # ------------------------------------------------------------------
        _copy_dir(example_path, mono_dir)

        if !isnothing(short_horizon_src)
            _inject_short_horizon_data!(mono_dir, short_horizon_src)
        end

        # Overwrite TDR settings with the fast test configuration (4 × 6-hour periods).
        cp(TEST_TDR_SETTINGS,
           joinpath(mono_dir, "settings", "time_domain_reduction_settings.yml"); force = true)
        # Remove any pre-existing TDR results so clustering always uses our settings.
        rm(joinpath(mono_dir, TEST_TDR_FOLDER); recursive = true, force = true)

        mono_settings = joinpath(mono_dir, "settings", "genx_settings.yml")
        if has_benders_genx
            cp(joinpath(example_path, "settings", "genx_benders_settings.yml"),
               mono_settings; force = true)
        end
        _set_yaml_key!(mono_settings, "Benders", 0)
        _set_yaml_key!(mono_settings, "OverwriteResults", 1)
        _set_yaml_key!(mono_settings, "PrintModel", 0)
        _set_yaml_key!(mono_settings, "TimeDomainReduction", use_tdr ? 1 : 0)
        _set_yaml_key!(mono_settings, "TimeDomainReductionFolder", TEST_TDR_FOLDER)

        redirect_stdout(devnull) do
            run_genx_case!(mono_dir, optimizer)
        end

        mono_status = joinpath(mono_dir, "results", "status.csv")
        if !isfile(mono_status)
            @warn "Monolithic status.csv not found for $case_name — skipping"
            return
        end
        obj_mono = CSV.read(mono_status, DataFrame)[1, :Objval]

        # ------------------------------------------------------------------
        # Benders run
        # ------------------------------------------------------------------
        _copy_dir(example_path, benders_dir)

        if !isnothing(short_horizon_src)
            _inject_short_horizon_data!(benders_dir, short_horizon_src)
        end

        # Overwrite TDR settings and remove stale TDR results.
        cp(TEST_TDR_SETTINGS,
           joinpath(benders_dir, "settings", "time_domain_reduction_settings.yml"); force = true)
        rm(joinpath(benders_dir, TEST_TDR_FOLDER); recursive = true, force = true)

        # Copy the TDR results produced by the monolithic run into the Benders directory
        # so both solves use identical clustered time series data.
        mono_tdr_path = joinpath(mono_dir, TEST_TDR_FOLDER)
        if isdir(mono_tdr_path)
            cp(mono_tdr_path, joinpath(benders_dir, TEST_TDR_FOLDER); force = true)
        end

        benders_settings = joinpath(benders_dir, "settings", "genx_settings.yml")
        if has_benders_genx
            cp(joinpath(example_path, "settings", "genx_benders_settings.yml"),
               benders_settings; force = true)
        end
        _set_yaml_key!(benders_settings, "Benders", 1)
        _set_yaml_key!(benders_settings, "OverwriteResults", 1)
        _set_yaml_key!(benders_settings, "PrintModel", 0)
        _set_yaml_key!(benders_settings, "TimeDomainReduction", use_tdr ? 1 : 0)
        _set_yaml_key!(benders_settings, "TimeDomainReductionFolder", TEST_TDR_FOLDER)

        redirect_stdout(devnull) do
            run_genx_case!(benders_dir, optimizer)
        end

        # ------------------------------------------------------------------
        # Read Benders convergence history
        # ------------------------------------------------------------------
        conv_csv = joinpath(benders_dir, "results_benders", "benders_convergence.csv")
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

        # Benders UB must match the monolithic objective within tolerance.
        rel_diff = abs(ub - obj_mono) / max(abs(obj_mono), 1.0)
        parity_ok = @test rel_diff ≤ rtol

        write_testlog(case_name,
            "mono=$obj_mono | Benders UB=$ub LB=$lb | gap=$(round(benders_gap; sigdigits=3)) | rel_diff=$(round(rel_diff; sigdigits=3))",
            parity_ok)

    finally
        # On Windows, solver processes may briefly hold file locks after returning.
        # Retry a few times before giving up so the test doesn't error on cleanup.
        for dir in (mono_dir, benders_dir)
            for attempt in 1:5
                try
                    rm(dir; recursive = true, force = true)
                    break
                catch
                    attempt < 5 ? sleep(1) : @warn "Could not remove temp dir $dir — it will be cleaned up by the OS"
                end
            end
        end
    end
end

# ---------------------------------------------------------------------------
# Test set
# ---------------------------------------------------------------------------

@testset "Benders vs Monolithic" begin
    for (case_num, case_name) in EXAMPLE_CASES
        @testset "Example $case_num: $case_name" begin
            run_benders_comparison(case_num, case_name, _BENDERS_OPTIMIZER)
        end
    end
end

end # module TestBendersVsMonolithic

