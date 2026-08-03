
@doc raw"""
	separate_inputs_subperiods(inputs)

Decompose the full-year `inputs` dictionary into per-representative-period sub-dictionaries.

Returns a `Dict` keyed by subperiod index `w = 1:REP_PERIOD`, where each entry is a deep
copy of `inputs` with time-indexed arrays (demand `pD`, capacity factors `pP_Max`,
fuel costs, start costs, time weights `omega`, etc.) sliced to the hours belonging to
subperiod `w`.  Each sub-dictionary also carries `REP_PERIOD = 1` and a `SubPeriod` field
with its index, making it self-contained for building a single operational subproblem.
"""
function separate_inputs_subperiods(inputs::Dict)

    inputs_all=Dict();
    number_periods = inputs["REP_PERIOD"];
    hours_per_subperiod = inputs["hours_per_subperiod"];
    

    for w in 1:number_periods
        inputs_all[w] = Dict()
        Tw = (w-1)*hours_per_subperiod+1:w*hours_per_subperiod;
        inputs_all[w]["omega"] = inputs["omega"][Tw];
        inputs_all[w]["REP_PERIOD"]=1;
        STARTS = 1:hours_per_subperiod:hours_per_subperiod;
        INTERIORS = setdiff(1:hours_per_subperiod,STARTS);   
        inputs_all[w]["INTERIOR_SUBPERIODS"] = INTERIORS;
        inputs_all[w]["START_SUBPERIODS"] = STARTS;
        inputs_all[w]["pP_Max"] = inputs["pP_Max"][:,Tw];
        inputs_all[w]["T"] = hours_per_subperiod;
        inputs_all[w]["fuel_costs"] = Dict();
        for ks in keys(inputs["fuel_costs"])
            inputs_all[w]["fuel_costs"][ks] = inputs["fuel_costs"][ks][Tw];
        end
        if haskey(inputs, "pP_Max_Wind")
            inputs_all[w]["pP_Max_Wind"] = inputs["pP_Max_Wind"][:,Tw];
        end
        if haskey(inputs, "pP_Max_Solar")
            inputs_all[w]["pP_Max_Solar"] = inputs["pP_Max_Solar"][:,Tw];
        end
        inputs_all[w]["Weights"] = [inputs["Weights"][w]];
        inputs_all[w]["pD"] = inputs["pD"][Tw,:];
        if haskey(inputs, "C_Start")
            inputs_all[w]["C_Start"] = inputs["C_Start"][:,Tw]; 
        end
        inputs_all[w]["SubPeriod"] = w;
		if haskey(inputs,"Period_Map")
			inputs_all[w]["SubPeriod_Index"] = inputs["Period_Map"].Rep_Period[findfirst(inputs["Period_Map"].Rep_Period_Index.==w)];
		end
        if haskey(inputs, "dfHM_absolute")
            inputs_all[w]["dfHM_absolute"] = inputs["dfHM_absolute"][Tw,:];
        end
        for k in keys(inputs)
            if !haskey(inputs_all[w],k)
                inputs_all[w][k] = inputs[k];
            end
        end
    end

    return inputs_all

end

@doc raw"""
	generate_benders_inputs(setup, inputs, inputs_decomp, optimizer)

Build and return the complete set of Benders decomposition inputs as a `Dict`.

Initializes the planning (master) problem and all operational subproblems, then assembles
them into a single `benders_inputs` dictionary with fields:
- `"planning_problem"`: the master JuMP model
- `"planning_variables"`: names of first-stage decision variables
- `"subproblems"`: operational subproblem dicts — a `Vector{Dict}` when running with a
  single Julia process (`nworkers() == 1`), or a `DArray` across multiple workers otherwise
- `"planning_variables_sub"`: per-subperiod mapping of linking variable names

The "subproblems" entry of the dictionary uses a `Vector{Dict}` when only one process is 
available to avoid routing every subproblem solve through Julia's distributed message-passing
infrastructure (`@fetchfrom 1 / @spawnat 1`), which can deadlock when the solver (e.g. HiGHS IPM) 
spawns OpenMP threads that interfere with Julia's cooperative task scheduler on the single OS thread. 
"""
function generate_benders_inputs(setup::Dict, inputs::Dict, inputs_decomp::Dict, optimizer::Any)

    planning_problem, planning_variables = init_planning_problem(setup, inputs, optimizer);

    if nworkers() == 1
        subproblems, planning_variables_sub = init_sequential_subproblems(setup, inputs_decomp, planning_variables, optimizer)
    else
        subproblems, planning_variables_sub = init_dist_subproblems(setup, inputs_decomp, planning_variables, optimizer)
    end

    benders_inputs = Dict();
	benders_inputs["planning_problem"] = planning_problem;
	benders_inputs["planning_variables"] = planning_variables;

    benders_inputs["subproblems"] = subproblems;
	benders_inputs["planning_variables_sub"] = planning_variables_sub;

    return benders_inputs
end

@doc raw"""
	setup_benders_workers!(setup::Dict, number_of_subproblems::Int; lsf_cpus_per_task::Int = 1)

Launch the Julia worker processes used to solve Benders subproblems in parallel, and return
the resulting `nworkers()`.

Does nothing (returns the current `nworkers()`) unless `setup[:Distributed]` is `true`.
The number of workers is controlled by `setup[:NWorkers]`:

- `NWorkers = -1` (the default): the worker count is chosen automatically by
  [`start_distributed_processes!`](@ref), which detects an HPC allocation from the environment
  (Slurm or LSF) and otherwise falls back to `min(number_of_subproblems, Sys.CPU_THREADS)`.
- `NWorkers > 1`: that many workers are requested explicitly; workers are added only if fewer
  are already running.  If more are already running, the existing ones are used as-is.
- `NWorkers` of `0` or `1`: parallel solving is disabled and the subproblems are solved
  sequentially on the main process (a warning is emitted, since `Distributed: true` was asked for).

`number_of_subproblems` is the number of operational subproblems (representative periods);
there is no benefit to launching more workers than that.  `lsf_cpus_per_task` is the number of
CPUs assigned to each worker under LSF and is only used on that path.
"""
function setup_benders_workers!(setup::Dict, number_of_subproblems::Int;
    lsf_cpus_per_task::Int = 1)

    if !get(setup, :Distributed, false)
        return nworkers()
    end

    target = get(setup, :NWorkers, -1)

    if target == -1
        if nworkers() > 1
            @info "Benders: $(nworkers()) workers already running — reusing them (NWorkers=-1)."
        else
            start_distributed_processes!(number_of_subproblems;
                lsf_cpus_per_task = lsf_cpus_per_task)
        end
    elseif target > 1
        # nworkers() == 1 when no extra processes have been added (the main process counts
        # as the sole worker), so `current` is directly comparable to the requested target.
        current = nworkers()
        if current < target
            n_to_add = target - current
            @info "Benders: adding $n_to_add worker process(es) to reach $target total workers."
            add_benders_workers!(n_to_add)
        elseif current > target
            @warn "Benders: $current workers are already running but NWorkers=$target was requested. Proceeding with $current workers."
        else
            @info "Benders: $current workers already running — no additional workers needed."
        end
    else
        @warn "Benders: Distributed=true but NWorkers=$target (must be > 1, or -1 for automatic sizing). Running sequentially."
    end

    return nworkers()
end

@doc raw"""
	start_distributed_processes!(number_of_subproblems::Int; lsf_cpus_per_task::Int = 1)

Automatically size and launch the pool of Benders worker processes.  Used when `NWorkers = -1`.

The worker count is taken from the surrounding HPC allocation when one is detected:

- **Slurm** (`SLURM_NTASKS` is set): workers are launched through
  `SlurmClusterManager.SlurmManager()`, which starts one worker per Slurm *task* — request
  `--ntasks=N` to get `N` workers.  Each worker gets `SLURM_CPUS_PER_TASK` Julia threads.
  A warning is issued if the allocation has more tasks than there are subproblems, since the
  surplus workers will sit idle.
- **LSF** (`LSB_DJOB_NUMPROC` is set): `min(LSB_DJOB_NUMPROC ÷ lsf_cpus_per_task,
  number_of_subproblems)` workers are launched, each with `lsf_cpus_per_task` Julia threads.
- **Otherwise** (laptop / workstation): `min(number_of_subproblems, Sys.CPU_THREADS)`
  single-threaded workers.

GenX (and any optional solver already loaded on the main process) is loaded on each new worker.
"""
function start_distributed_processes!(number_of_subproblems::Int; lsf_cpus_per_task::Int = 1)

    if haskey(ENV, "SLURM_NTASKS")
        parse(Int, ENV["SLURM_NTASKS"]) > number_of_subproblems ?
            @warn("SLURM_NTASKS is greater than the number of subproblems specified. Only $number_of_subproblems of the $(ENV["SLURM_NTASKS"]) requested processors will be used by the algorithm.") : nothing
        cpus_per_task = parse(Int, ENV["SLURM_CPUS_PER_TASK"])
        new_pids = addprocs(SlurmClusterManager.SlurmManager();
            exeflags = benders_worker_exeflags(cpus_per_task))
    elseif haskey(ENV, "LSB_DJOB_NUMPROC")
        lsb_numproc = parse(Int, ENV["LSB_DJOB_NUMPROC"])
        if lsb_numproc ÷ lsf_cpus_per_task > number_of_subproblems * lsf_cpus_per_task
            @warn("LSB_DJOB_NUMPROC is greater than the number of subproblems multiplied by number of CPUs per task: number_of_subproblems = $number_of_subproblems, cpus_per_task = $lsf_cpus_per_task, LSB_DJOB_NUMPROC = $lsb_numproc.
            Only $number_of_subproblems processes will be used.")
        end
        number_of_processes = min(lsb_numproc ÷ lsf_cpus_per_task, number_of_subproblems)
        new_pids = addprocs(number_of_processes;
            exeflags = benders_worker_exeflags(lsf_cpus_per_task))
    else
        ntasks = min(number_of_subproblems, Sys.CPU_THREADS)
        new_pids = addprocs(ntasks; exeflags = benders_worker_exeflags())
    end

    @sync for p in new_pids
        @async create_worker_process(p)
    end

    @info("Number of procs: $(nprocs())")
    @info("Number of workers: $(nworkers())")

    return new_pids
end

@doc raw"""
	add_benders_workers!(n::Int)

Add `n` Benders worker processes and prepare them, returning the new worker ids.

Used on the explicit `NWorkers > 1` path.  Workers inherit the currently active project.
"""
function add_benders_workers!(n::Int)
    new_pids = addprocs(n; exeflags = benders_worker_exeflags())
    @sync for p in new_pids
        @async create_worker_process(p)
    end
    return new_pids
end

"""
	benders_worker_exeflags()
	benders_worker_exeflags(cpus_per_task::Int)

Julia command-line flags for a Benders worker.

Always sets the active project, so that `using GenX` on the worker resolves to the same
environment as the main process.  The second method additionally gives the worker
`cpus_per_task` Julia threads, and is used on the HPC paths where the scheduler has allocated
that many CPUs to each task.
"""
benders_worker_exeflags() = ["--project=$(Base.active_project())"]

function benders_worker_exeflags(cpus_per_task::Int)
    return [benders_worker_exeflags()..., "-t $cpus_per_task"]
end

"""
	solver_available(solver_name::Symbol)

Return `true` if `solver_name` has been loaded into `Main` on the current process.
"""
function solver_available(solver_name::Symbol)::Bool
    return isdefined(Main, solver_name)
end

"""
	create_worker_process(pid)

Load GenX on worker `pid`, along with any optional solver package that is already loaded on the
main process (loading it on the main process only is not enough: subproblems are built and
solved on the workers).
"""
function create_worker_process(pid)
    Distributed.remotecall_eval(Main, pid, :(using GenX))

    optional_solvers = [:Gurobi]
    for solver in optional_solvers
        if solver_available(solver)
            Distributed.remotecall_eval(Main, pid, :(using $solver))
            @debug("Loaded $solver on worker $pid")
        end
    end
    return nothing
end
