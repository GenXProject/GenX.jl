@doc draw"""
    @benchmarked <expr to benchmark> [setup=<setup expr>] [other keyword parameters...]

    Run benchmarked on a given expression.

    This macro is a customization of BenchmarkTools' `@benchmark`.
    `@benchmark` only provides benchmark results.
    With this customization, we can benchmark a function that has a return value.
    Customization uses internals from BenchmarkTools. 
    Updates to this macro is needed when internals get changed from BenchmarkTools.

    #Example
"""

using BenchmarkTools
using DataFrames

macro benchmarked(args...)
    _, params = BenchmarkTools.prunekwargs(args...)
    bench, trial, result = gensym(), gensym(), gensym()
    trialmin, trialallocs = gensym(), gensym()
    tune_phase = BenchmarkTools.hasevals(params) ? :() : :($BenchmarkTools.tune!($bench))
    return esc(
        quote
            local $bench = $BenchmarkTools.@benchmarkable $(args...)
            $BenchmarkTools.warmup($bench)
            $tune_phase
            local $trial, $result = $BenchmarkTools.run_result($bench)
            local $trialmin = $BenchmarkTools.minimum($trial)
            local $trialallocs = $BenchmarkTools.allocs($trialmin) 

             println(
                "  ",
                $BenchmarkTools.prettytime($BenchmarkTools.time($trialmin)),
                " (",
                $trialallocs,
                " allocation",
                $trialallocs == 1 ? "" : "s",
                ": ",
                $BenchmarkTools.prettymemory($BenchmarkTools.memory($trialmin)),
                ")",
            )

            $result, $trial
        end,
    )
end

function generate_benchmark_csv(path::String, bm_file::String, bm_results::BenchmarkTools.Trial)
    bm_df = DataFrame(
    time_ms = bm_results.times ./ 1e6,
    gctime_ms = bm_results.gctimes ./ 1e6,
    bm_nt_ms = (bm_results.times - bm_results.gctimes) ./ 1e6,
    memory_mb = bm_results.memory ./ 1e6,
    allocs = bm_results.allocs
    )
    CSV.write(joinpath(path, bm_file), bm_df)
end



