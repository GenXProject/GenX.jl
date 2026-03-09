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

GenX.expand_new_cap_resources_to_nodal!(myinputs, mysetup, p, "")

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


myinputs_copy = deepcopy(myinputs)

# perturb pD X
# perturb pP_Max,  X
# update pNet Map X
# update existing and candidate data
# update zone ids of resources; double_resources
# update G, L, Z, L_cand, L_exist
# update existing_to_cand_map, 
# append HAS_FUEL, MUST_RUN, STOR_ASYMMETRIC, STOR_SYMMETRIC, THERM_NO_COMMIT, ELECTROLYZER, MULTI_FUELS, NEW_CAP, RETROFIT_OPTIONS, STOR_HYDRO_LONG_DURATION, NEW_CAP_CHARGE, RET_CAP, SINGLE_FUEL, STOR_HYDRO_SHORT_DURATION, THERM_ALL, VRE, CCS, HYDRO_RES, NEW_CAP_ENERGY, QUALIFIED_SUPPLY, RET_CAP_CHARGE, STOR_LONG_DURATION, THERM_COMMIT, VRE_STOR, COMMIT, FLEX, RETROFIT_CAP, RET_CAP_ENERGY, STOR_ALL, STOR_SHORT_DRUATION, THERM_COMMIT_PWFU, new_cap_names

using Random
Random.seed!(1234)

pD_data = deepcopy(myinputs_copy["pD"])
pD_noise = (rand(size(pD_data)[1], size(pD_data)[2]) .- 0.5) .* 0.05 .+ 1
pP_data = deepcopy(myinputs_copy["pP_Max"])
pP_noise = (rand(size(pP_data)[1], size(pP_data)[2]) .- 0.25) .* 0.05 .+ 1

pD_data = pD_data .* pD_noise
pP_data = pP_data .* pP_noise
pP_data[pP_data .> 1] .= 1

myinputs_copy["pD"] = hcat(myinputs_copy["pD"], pD_data)
myinputs_copy["pP_Max"] = vcat(myinputs_copy["pP_Max"], pP_data)

pNet_Map = myinputs_copy["pNet_Map"]
new_pNet_Map = zeros(246 * 2 + 5, 73 * 2) # add 5 new lines
new_pNet_Map[1:120, 1:73] .= pNet_Map[1:120, :]
new_pNet_Map[121:240, 74:146] .= pNet_Map[1:120, :]
new_pNet_Map[241, 11] = -1 # new line 1
new_pNet_Map[241, 145] = 1
new_pNet_Map[242, 6] = -1 # new line 2
new_pNet_Map[242, 127] = 1
new_pNet_Map[243, 8] = -1 # new line 3
new_pNet_Map[243, 124] = 1
new_pNet_Map[244, 12] = -1 # new line 4
new_pNet_Map[244, 129] = 1
new_pNet_Map[245, 2] = -1 # new line 5
new_pNet_Map[245, 126] = 1
new_pNet_Map[246:371, 1:73] .= pNet_Map[121:246, :]
new_pNet_Map[372:497, 74:146] .= pNet_Map[121:246, :]

# CANDIDATE_LINES, L, Line_Reinforcement_Cap_Size, pC_Line_Reinforcement, pTrans_Max_Possible, CANNOT_RETIRE_LINES, CAN_RETIRE_LINES, EXISTING_LINES, L_cand, pDC_OPF_coeff, EXPANSION_LINES, L_exist, Max_Trans_Cap, RECONDUCTOR_LINES, existing_to_cand_map, pC_Line_Reconductor_High, pTrans_Loss_coef, Line_Angle_Limit, NO_EXPANSION_LINES, pC_Line_Reconductor_Low, pMax_Line_Reinforcement, pTrans_Max

myinputs_copy["pNet_Map"] = new_pNet_Map
myinputs_copy["L"] = size(new_pNet_Map, 1)
myinputs_copy["Z"] = size(new_pNet_Map, 2)
myinputs_copy["L_exist"] = 245
myinputs_copy["L_cand"] = 252
key_set = ["Line_Reinforcement_Cap_Size", "pC_Line_Reinforcement", "pDC_OPF_coeff", "Max_Trans_Cap", "Line_Angle_Limit","pTrans_Max", "pC_Line_Reconductor_Low", "pC_Line_Reconductor_High", "pPercent_Loss", "BigM"]

for k in key_set
    if haskey(myinputs_copy, k)
        data = myinputs_copy[k]

        myinputs_copy[k] = vcat(data[1:120], data[1:120], data[241:245], data[121:246], data[121:246])
    end
end 
myinputs_copy["pTrans_Max"][241:245] .= 500
myinputs_copy["Line_Reinforcement_Cap_Size"][241:245] .= 0

myinputs_copy["EXISTING_LINES"] = [i for i in 1:245]
myinputs_copy["CAN_RETIRE_LINES"] = vcat(myinputs_copy["CAN_RETIRE_LINES"], myinputs_copy["CAN_RETIRE_LINES"] .+ 120)
myinputs_copy["CANNOT_RETIRE_LINES"] = vcat(myinputs_copy["CANNOT_RETIRE_LINES"], myinputs_copy["CANNOT_RETIRE_LINES"] .+ 120, [241, 242, 243, 244, 245])
myinputs_copy["RECONDUCTOR_LINES"] = vcat(myinputs_copy["RECONDUCTOR_LINES"], myinputs_copy["RECONDUCTOR_LINES"] .+ 120)
myinputs_copy["CANDIDATE_LINES"] = [i for i in 246:497]
myinputs_copy["EXPANSION_LINES"] = deepcopy(myinputs_copy["CANDIDATE_LINES"])

existing_to_cand_map = deepcopy(myinputs_copy["existing_to_cand_map"])

for k in keys(myinputs_copy["existing_to_cand_map"])
    key_val = myinputs_copy["existing_to_cand_map"][k]
    existing_to_cand_map[k] = key_val + 125
    existing_to_cand_map[k + 120] = key_val + 251
end

myinputs_copy["existing_to_cand_map"] = existing_to_cand_map
resource_copy = deepcopy(myinputs_copy["RESOURCES"])
resource_names = deepcopy(myinputs_copy["RESOURCE_NAMES"])


myinputs_copy["RESOURCES"] = vcat(myinputs_copy["RESOURCES"], resource_copy)
myinputs_copy["RESOURCE_NAMES"] = vcat(myinputs_copy["RESOURCE_NAMES"], resource_names)
myinputs_copy["C_Start"] = vcat(myinputs_copy["C_Start"], myinputs_copy["C_Start"])

G_original = myinputs["G"]
myinputs_copy["G"] = length(myinputs_copy["RESOURCES"])

# RESET RESOURCE IDX
for i in 1:G_original
    r = myinputs_copy["RESOURCES"][i + G_original]
    id_num = parent(r)[:zone]
    new_id_num = id_num + 73
    parent(r)[:zone] = new_id_num
    parent(r)[:id] = parent(r)[:id] + G_original
    r_name = GenX.resource_name(r)
    push!(myinputs_copy["RESOURCE_ZONES"], r_name * "_z" * string(new_id_num))
    push!(myinputs_copy["R_ZONES"], new_id_num)
end

key_set = ["HAS_FUEL", "MUST_RUN", "STOR_ASYMMETRIC", "STOR_SYMMETRIC", "THERM_NO_COMMIT", "ELECTROLYZER", "MULTI_FUELS", "NEW_CAP", "RETROFIT_OPTIONS", "STOR_HYDRO_LONG_DURATION", "NEW_CAP_CHARGE", "RET_CAP", "SINGLE_FUEL", "STOR_HYDRO_SHORT_DURATION", "THERM_ALL", "VRE", "CCS", "HYDRO_RES", "NEW_CAP_ENERGY", "QUALIFIED_SUPPLY", "RET_CAP_CHARGE", "STOR_LONG_DURATION", "THERM_COMMIT", "VRE_STOR", "COMMIT", "FLEX", "RETROFIT_CAP", "RET_CAP_ENERGY", "STOR_ALL", "STOR_SHORT_DURATION", "THERM_COMMIT_PWFU"]

for k in key_set
    if haskey(myinputs_copy, k)
        myinputs_copy[k] = vcat(myinputs_copy[k], myinputs_copy[k] .+ G_original)
    else
        println("Key $k is not found")
    end
end

# Run TDR
TDR_params = Dict("MinPeriods" => 16, "MaxPeriods" => 16, "UseExtremePeriods" => 1)
cluster_inputs(case, settings_path, mysetup; inputs = myinputs_copy, TDR_params = TDR_params, random = false)


mysetup["NetworkExpansion"] = 1
mysetup["Benders"] = 1
mysetup["IntegerInvestments"] = 1
mysetup["bilinear"] = 0
mysetup["DC_OPF"] = 1
mysetup["unfix_slacks"] = 0
optimizer = optimizer_with_attributes(Gurobi.Optimizer, "TimeLimit" => 115200, "MIPGap" => 1e-3)

m = GenX.generate_model(mysetup, myinputs_copy, optimizer)

optimize!(m)

for v in m[:vNEW_TRANS_CAP_DECISION_INT]
    println(v, "   ", value(v))
end

for v in m[:vCAP]
    println(v, "   ", value(v))
end