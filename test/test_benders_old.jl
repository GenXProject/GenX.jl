module TestBenders

using Test
using GenX
using CSV, DataFrames
using Gurobi

include(joinpath(@__DIR__, "utilities.jl"))

# Check whether the Gurobi package is loadable in this environment.
const _GUROBI_AVAILABLE = !isnothing(Base.find_package("Gurobi"))

if _GUROBI_AVAILABLE
    using Gurobi
end

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

"""Copy every item (files and subdirectories) from `src` into `dst`."""
function _copy_dir(src::AbstractString, dst::AbstractString)
    for item in readdir(src; join=false)
        cp(joinpath(src, item), joinpath(dst, item); force=true)
    end
end

"""Append key-value pairs to a YAML settings file as new top-level keys."""
function _append_settings!(settings_path::AbstractString; kwargs...)
    open(settings_path, "a") do io
        for (k, v) in kwargs
            println(io, "$k: $v")
        end
    end
end

# ---------------------------------------------------------------------------
# Main test function
# ---------------------------------------------------------------------------

function test_benders_vs_monolithic()
    base_path = Base.dirname(Base.dirname(pathof(GenX)))
    example_path = joinpath(base_path, "example_systems", "1_three_zones")
    benders_test_settings = joinpath(@__DIR__, "benders_three_zones")

    mono_dir    = mktempdir()
    benders_dir = mktempdir()

    try
        # ── Copy the example system into both temp directories ──────────────
        _copy_dir(example_path, mono_dir)
        _copy_dir(example_path, benders_dir)

        # ── Monolithic run ───────────────────────────────────────────────────
        mono_settings_path = joinpath(mono_dir, "settings", "genx_settings.yml")
        _append_settings!(mono_settings_path; Benders=0, OverwriteResults=1)

        redirect_stdout(devnull) do
            run_genx_case!(mono_dir, Gurobi.Optimizer)
        end

        mono_results_dir = joinpath(mono_dir, "results")
        status_csv = joinpath(mono_results_dir, "status.csv")
        @test isfile(status_csv)

        df_status = CSV.read(status_csv, DataFrame)
        obj_mono = df_status[1, :Objval]

        # ── Benders run ──────────────────────────────────────────────────────
        benders_settings_path = joinpath(benders_dir, "settings", "genx_settings.yml")
        _append_settings!(benders_settings_path; Benders=1, OverwriteResults=1)

        # Copy Benders-specific solver settings into the case settings folder.
        benders_case_settings = joinpath(benders_dir, "settings")
        for fname in readdir(benders_test_settings; join=false)
            cp(joinpath(benders_test_settings, fname),
               joinpath(benders_case_settings, fname);
               force=true)
        end

        redirect_stdout(devnull) do
            run_genx_case!(benders_dir, Gurobi.Optimizer)
        end

        benders_results_dir = joinpath(benders_dir, "results_benders")
        conv_csv = joinpath(benders_results_dir, "benders_convergence.csv")

        @test isfile(joinpath(benders_results_dir, "benders_convergence.csv"))
        @test isfile(joinpath(benders_results_dir, "status.csv"))

        df_conv   = CSV.read(conv_csv, DataFrame)
        last_iter = df_conv[end, :]
        ub = last_iter[:UB]
        lb = last_iter[:LB]

        # Benders must have converged within tolerance
        gap = abs(ub - lb) / abs(ub)
        @test gap ≤ 1e-3

        # Benders UB must be within tolerance of monolithic objective
        rel_diff = abs(ub - obj_mono) / abs(obj_mono)
        parity_result = @test rel_diff ≤ 1e-3

        msg = "Monolithic obj=$obj_mono | Benders UB=$ub | LB=$lb | gap=$gap | rel_diff=$rel_diff"
        write_testlog("benders_three_zones", msg, parity_result)

    finally
        rm(mono_dir;    recursive=true, force=true)
        rm(benders_dir; recursive=true, force=true)
    end
end

# ---------------------------------------------------------------------------
# Test set
# ---------------------------------------------------------------------------
using Gurobi
@testset "Benders vs Monolithic (Three Zones)" begin
    if !_GUROBI_AVAILABLE
        @test_skip "Gurobi not available - skipping Benders decomposition test"
    else
        test_benders_vs_monolithic()
    end
end

end # module TestBenders
