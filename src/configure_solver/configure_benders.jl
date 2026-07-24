@doc raw"""
    configure_benders(settings_path::String)

Load Benders decomposition settings from a YAML file and return them as a `Dict`.

Reads `benders_settings.yml` from `settings_path` if it exists; otherwise returns
default values. The returned dictionary uses `Symbol` keys.

| Parameter                  | Default  | Description |
|:---------------------------|:---------|:------------|
| `ConvTol`                  | `1e-3`   | Relative optimality-gap convergence tolerance |
| `MaxIter`                  | `50`     | Maximum number of Benders iterations |
| `MaxCpuTime`               | `7200`   | Wall-clock time limit (seconds) |
| `StabParam`                | `0.0`    | Level-set stabilisation parameter (0 = disabled) |
| `StabDynamic`              | `false`  | Enable Magnanti–Wong / in-out dynamic stabilisation |
| `ExpectFeasibleSubproblems`| `false`  | Skip feasibility cuts (assumes subproblems always feasible) |
| `IntegerInvestment`        | `false`  | Use integer (MILP) investment variables in the planning problem |
| `Distributed`              | `false`  | Distribute subproblems to remote workers. When `true`, GenX will automatically launch worker processes (see `NWorkers`) if fewer are currently running. |
| `NWorkers`                 | `-1`     | Target number of Julia worker processes for parallel subproblem solving. Only used when `Distributed: true`. `-1` (the default) sizes the pool automatically from the Slurm/LSF allocation, or from `min(n_subproblems, Sys.CPU_THREADS)` on a local machine; a value `> 1` requests that many workers explicitly; `0` or `1` disables parallel solving. |
| `ThetaLB`                  | `0.0`    | Lower bound on the subproblem objective |
"""
function configure_benders(settings_path::String)

    println("Configuring Benders Settings")
    settings = isfile(settings_path) ? YAML.load_file(settings_path, dicttype=Dict{Symbol, Any}) : Dict{Any,Any}()

    # GenX-convention string keys (configurable via benders_settings.yml)
    default_settings = Dict{Any,Any}(
        :ConvTol                   => 1e-3,
        :MaxIter                   => 50,
        :MaxCpuTime                => 7200,
        :StabParam                 => 0.0,
        :StabDynamic               => false,
        :ExpectFeasibleSubproblems => false,
        :IntegerInvestment         => false,
        :Distributed               => false,
        :NWorkers                  => -1,
        :ThetaLB                   => 0.0,
    )

    merge!(default_settings, settings)

    return default_settings
end
