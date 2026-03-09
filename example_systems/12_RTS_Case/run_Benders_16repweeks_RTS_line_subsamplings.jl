ENV["GENX_PRECOMPILE"] = "false"

using Revise
using JuMP
using GenX
using PowerSystemsInvestmentsPortfolios
using Gurobi
using TimeSeries
using CSV
using DataFrames
using Dates
using InfrastructureSystems
using PowerSystems
const PSIP = PowerSystemsInvestmentsPortfolios
const IS = InfrastructureSystems
const PSY = PowerSystems
import Pkg
using Distributed, ClusterManagers
using Random


# Load in portfolio
include((@__DIR__)*"/load_portfolio.jl")
# Load in functions for adding candidate lines
include((@__DIR__)*"/load_candidate_line_functions.jl")

# Set internal portfolio data for use in GenX
p.internal.ext["Rep_Periods"] = 1
p.internal.ext["Timesteps_per_Rep_Period"] = 168
p.internal.ext["hours_per_subperiod"] = 168
p.internal.ext["sub_weights"] = [8784 for i in 1:p.internal.ext["Rep_Periods"]] 
add_om_costs(p)

techs = collect(get_technologies(SupplyTechnology, p))

bilinear_bool = parse(Bool, ARGS[1])
sampling_number = parse(Int, ARGS[2])
speedup_strategy = parse(Int, ARGS[3])

# Build map of buses to zones; used in downscaling
buses = collect(get_components(Bus, p.base_system))
zones = []
zone_map = Dict{Int, Int}()
for i in 1:length(buses)
    if buses[i].area.name == "area1"
        push!(zones, 1)
        zone_map[i] = 1
    elseif buses[i].area.name == "area2"
        push!(zones, 2)
        zone_map[i] = 2
    elseif buses[i].area.name == "area3"
        push!(zones, 3)
        zone_map[i] = 3
    else
        error()
    end
end

cpus_per_task = parse(Int, ENV["SLURM_CPUS_PER_TASK"]);
addprocs(cpus_per_task)
println("Adding processors")

@everywhere begin
    import Pkg
    Pkg.activate((@__DIR__)*"/../../")
end

println("Number of procs: ", nprocs())
println("Number of workers: ", nworkers())
for i in workers()
    id, pid, host = fetch(@spawnat i (myid(), getpid(), gethostname()))
    println(id, " " , pid, " ", host)
end
@everywhere using GenX, Distributed


# Load in settings
genx_settings = GenX.get_settings_path(case, "genx_settings.yml") # Settings YAML file path
writeoutput_settings = GenX.get_settings_path(case, "output_settings.yml") # Write-output settings YAML file path
mysetup = GenX.configure_settings(genx_settings, writeoutput_settings) # mysetup dictionary stores settings and GenX-specific parameters

# Make sure certain parameters are set
mysetup["ParameterScale"] = 0
mysetup["DC_OPF"] = 1
settings_path = GenX.get_settings_path(case)    
mysetup["settings_path"] = settings_path;
mysetup["NetworkExpansion"] = 1

node_names = ["Alder", "Alger", "Ali", "Archer", "Austen", "Bach", "Bailey", "Bain", "Bajer", "Baker", "Balch", "Bardeen", "Barkla", "Barlow", "Caine", "Calvin", "Camus", "Carew", "Carrel", "Carter", "Caxton", "Comte"]

# Split node names by initial letter (A, B, C)
a_node_names = filter(n -> startswith(n, "A"), node_names)
b_node_names = filter(n -> startswith(n, "B"), node_names)
c_node_names = filter(n -> startswith(n, "C"), node_names)

# Set a reproducible seed (outside the function)
function sample_three(names::AbstractVector{<:AbstractString})
    @assert length(names) >= 3 "Need at least 3 names (got $(length(names)))"
    idxs = sort(randperm(length(names))[1:3])
    return collect(names[idxs])
end
node_name_dict = Dict('A' => a_node_names, 'B' => b_node_names, 'C' => c_node_names)
techs = collect(get_technologies(ResourceTechnology, p))

Random.seed!(1234)
for i in 1:length(techs)
    t = techs[i]
    if length(t.region) > 1
        old_region_list = t.region
        new_region_list = PSIP.RegionTopology[]
        key = t.region[1].name[1]
        node_name_vector = node_name_dict[key]
        new_nodes = sample_three(node_name_vector)
        for name in new_nodes
            for n in old_region_list
                if n.name == name
                    push!(new_region_list, n)
                    break
                end 
            end
        end
        @assert length(new_region_list) >=1
        t.region = new_region_list
    end
end

myinputs = GenX.load_inputs(mysetup, case, p)

optimizer = optimizer_with_attributes(Gurobi.Optimizer, "TimeLimit" => 64800, "MIPGap" => 1e-3)

# Add expected candidate line data
# also scales demands up by 2x
load_candidates_base(myinputs, 8784, add_new_corridors = true, use_official_lengths = true)
update_fuel_and_investment_costs(myinputs)

# Run TDR
TDR_params = Dict("MinPeriods" => 16, "MaxPeriods" => 16, "UseExtremePeriods" => 1)
cluster_inputs(case, settings_path, mysetup; inputs = myinputs, TDR_params = TDR_params, random=false)

GenX.expand_new_cap_resources_to_nodal!(myinputs, mysetup, p, "")


using StatsBase, Random
if sampling_number == 1
    Random.seed!(123)
elseif sampling_number == 2
    Random.seed!(456)
elseif sampling_number == 3
    Random.seed!(789)
elseif sampling_number == 4
    Random.seed!(101112)
else
    error("Invalid sampling number. Must be 1, 2, 3, or 4.")
end
CANDIDATE_LINES = myinputs["CANDIDATE_LINES"]
RECONDUCTOR_LINES = myinputs["RECONDUCTOR_LINES"]
lines_to_keep = sample(CANDIDATE_LINES, 80, replace=false, ordered=true)

println("LINES TO KEEP ARE: ")
sort!(lines_to_keep)
println(lines_to_keep)

lines_to_keep_reconductor = sample(RECONDUCTOR_LINES, 30, replace=false, ordered=true)
myinputs["RECONDUCTOR_LINES"] = lines_to_keep_reconductor

GenX.filter_candidate_lines(myinputs, lines_to_keep)

existing_to_cand_map = myinputs["existing_to_cand_map"]
candidate_to_existing_map = Dict([existing_to_cand_map[i] => i for i in keys(existing_to_cand_map)])

if haskey(myinputs, "BigM")
    println("RESETTING BIG M VALUES")
    for l in myinputs["CANDIDATE_LINES"]
        if l in keys(candidate_to_existing_map)
            if candidate_to_existing_map[l] in myinputs["RECONDUCTOR_LINES"]
                myinputs["BigM"][l] = myinputs["Line_Reinforcement_Cap_Size"][l] * 1.25
            else
                myinputs["BigM"][l] = myinputs["Line_Reinforcement_Cap_Size"][l]
            end
        else
            myinputs["BigM"][l] = myinputs["Line_Reinforcement_Cap_Size"][l]
        end
    end
end

println("NUMBER OF POSSIBLE LINE RETIREMENTS: ", length(myinputs["CAN_RETIRE_LINES"]))


mysetup["IntegerInvestments"] = 1
mysetup["DC_OPF"] = 1
mysetup["NetworkExpansion"] = 1

if haskey(mysetup, "IntegerInvestments")
    if mysetup["IntegerInvestments"] == 1
        for i in myinputs["NEW_CAP"]
            resource = myinputs["RESOURCES"][i]
            parent(resource)[:cap_size] = 200
        end
    end
end

benders_settings_path = GenX.get_settings_path(case, "benders_settings.yml")
mysetup_benders = GenX.configure_benders(benders_settings_path) 
mysetup = merge(mysetup,mysetup_benders);


mysetup["NetworkExpansion"] = 1
mysetup["Benders"] = 1
mysetup["IntegerInvestments"] = 1
mysetup["BD_MaxIter"] = 3000
mysetup["BD_MaxCpuTime"] = 79200
mysetup["BD_ConvTol"] = .001


# defaults that are adjusted below as needed
mysetup["bilinear"] = 0
mysetup["BD_integer_routine"] = 0
mysetup["BD_post_warmstart_integer_routine"] = 0
mysetup["BD_warmstart_bilinear"] = 0
mysetup["BD_warmstart_bigM"] = 0
mysetup["unfix_slacks"] = 0
mysetup["BD_Stab_Method"] = "off"
mysetup["BD_regularization_switch"] = 0


if speedup_strategy == 0 # baseline
    if bilinear_bool
        mysetup["bilinear"] = 1
        mysetup["BD_post_warmstart_ConvTol"] = 1e-6
    end
elseif speedup_strategy == 1 # HS only
    if bilinear_bool
        mysetup["BD_post_warmstart_ConvTol"] = 1e-6
        mysetup["BD_warmstart_bilinear"] = 1
        mysetup["unfix_slacks"] = 1
    else
        mysetup["BD_warmstart_bigM"] = 1
        mysetup["unfix_slacks"] = 1
    end
elseif speedup_strategy == 2 # LP only
    if bilinear_bool
        mysetup["bilinear"] = 1
        mysetup["BD_integer_routine"] = 1
        mysetup["BD_post_warmstart_ConvTol"] = 1e-6
    else
        mysetup["BD_integer_routine"] = 1
    end
elseif speedup_strategy == 3 # regularization only
    if bilinear_bool
        mysetup["bilinear"] = 1
        mysetup["BD_post_warmstart_ConvTol"] = 1e-6
        mysetup["BD_Stab_Method"] = "int_level_set"
    else
        mysetup["BD_Stab_Method"] = "int_level_set"
    end
elseif speedup_strategy == 4 # HS + LP 
    if bilinear_bool
        mysetup["BD_integer_routine"] = 1
        mysetup["BD_post_warmstart_ConvTol"] = 1e-6
        mysetup["BD_post_warmstart_integer_routine"] = 1
        mysetup["BD_warmstart_bilinear"] = 1
        mysetup["unfix_slacks"] = 1
    else
        mysetup["BD_integer_routine"] = 1
        mysetup["BD_post_warmstart_integer_routine"] = 1
        mysetup["BD_warmstart_bigM"] = 1
        mysetup["unfix_slacks"] = 1
    end
elseif speedup_strategy == 5 # HS + LP + regularization
    if bilinear_bool
        mysetup["BD_integer_routine"] = 1
        mysetup["BD_post_warmstart_ConvTol"] = 1e-6
        mysetup["BD_post_warmstart_integer_routine"] = 1
        mysetup["BD_warmstart_bilinear"] = 1
        mysetup["unfix_slacks"] = 1
        mysetup["BD_Stab_Method"] = "int_level_set"
    else
        mysetup["BD_integer_routine"] = 1
        mysetup["BD_post_warmstart_integer_routine"] = 1
        mysetup["BD_warmstart_bigM"] = 1
        mysetup["unfix_slacks"] = 1
        mysetup["BD_Stab_Method"] = "int_level_set"
    end
elseif speedup_strategy == 6
    if bilinear_bool
        mysetup["BD_integer_routine"] = 1
        mysetup["BD_post_warmstart_ConvTol"] = 1e-6
        mysetup["BD_post_warmstart_integer_routine"] = 1
        mysetup["BD_warmstart_bilinear"] = 1
        mysetup["unfix_slacks"] = 1
        mysetup["BD_Stab_Method"] = "int_level_set"
        mysetup["BD_regularization_switch"] = 1
    else
        mysetup["BD_integer_routine"] = 1
        mysetup["BD_post_warmstart_integer_routine"] = 1
        mysetup["BD_warmstart_bigM"] = 1
        mysetup["unfix_slacks"] = 1
        mysetup["BD_Stab_Method"] = "int_level_set"
        mysetup["BD_regularization_switch"] = 1
    end
else
    error("Speedup strategy of $speedup_strategy not allowed")
end

myinputs_decomp = GenX.separate_inputs_subperiods(myinputs);
benders_inputs = GenX.generate_benders_inputs(mysetup,myinputs,myinputs_decomp)
myinputs["inputs_decomp"] = myinputs_decomp

planning_problem1, planning_sol1, operational_sol1, LB_hist1,UB_hist1, cpu_time1,feasibility_hist1  = GenX.benders(benders_inputs,mysetup,myinputs);


for i in keys(planning_sol1.values)
    if planning_sol1.values[i] != 0
        println(i, " = ", planning_sol1.values[i])
    end
end
