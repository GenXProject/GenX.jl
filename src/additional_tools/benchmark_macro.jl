@doc draw"""
    macro benchmarked(args...)
    This macro is needed for getting both benchmark results and a return value from a function.
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

            display($trial)

            $result, $trial
        end,
    )
end





