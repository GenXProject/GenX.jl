ENV["GENX_PRECOMPILE"] = "false"

using Pkg;
Pkg.activate((@__DIR__)*"/../..")
using Revise
using GenX
using PowerSystemsInvestmentsPortfolios
using PowerSystems
using InfrastructureSystems
const PSIP = PowerSystemsInvestmentsPortfolios
const IS = InfrastructureSystems
const PSY = PowerSystems
using CSV
using DataFrames
using Random
using HiGHS
using JuMP

include((@__DIR__)*"/load_portfolio.jl")
include((@__DIR__)*"/load_candidate_line_functions.jl")


# Set internal portfolio data for use in GenX
p.internal.ext["Rep_Periods"] = 1
p.internal.ext["Timesteps_per_Rep_Period"] = 2
p.internal.ext["hours_per_subperiod"] = 2
p.internal.ext["sub_weights"] = [8784 for i in 1:p.internal.ext["Rep_Periods"]] 
add_om_costs(p)


# Load in settings
genx_settings = GenX.get_settings_path(case, "genx_settings.yml") # Settings YAML file path
writeoutput_settings = GenX.get_settings_path(case, "output_settings.yml") # Write-output settings YAML file path
mysetup = GenX.configure_settings(genx_settings, writeoutput_settings) # mysetup dictionary stores settings and GenX-specific parameters

# Make sure certain parameters are set
mysetup["ParameterScale"] = 0
mysetup["DC_OPF"] = 1
mysetup["ptdf"] = 0
mysetup["bilinear"] = 0
mysetup["disaggregate"] = 0
mysetup["unfix_slacks"] = 0
mysetup["SOS1"] = 0
settings_path = GenX.get_settings_path(case)    
mysetup["settings_path"] = settings_path;
mysetup["NetworkExpansion"] = 1
mysetup["Benders"] = 0

###################### SOLUTIONS WITH TRANSMISSION ######################
mysetup["DC_OPF"] = 1
myinputs = GenX.load_inputs(mysetup, case, p)

load_candidates_base(myinputs, 24, use_official_lengths = true)

mysetup["ptdf"] = 0
mysetup["bilinear"] = 1
mysetup["unfix_slacks"] = 0
mysetup["DC_OPF"] = 1
mysetup["settings_path"] = settings_path;
mysetup["NetworkExpansion"] = 1
mysetup["BD_integer_routine"] = 1
mysetup["BD_MaxCpuTime"] = 600

benders_settings_path = GenX.get_settings_path(case, "benders_settings.yml")
mysetup_benders = GenX.configure_benders(benders_settings_path) 
mysetup = merge(mysetup,mysetup_benders);


mysetup["NetworkExpansion"] = 1
mysetup["Benders"] = 1
mysetup["bilinear"] = 0
mysetup["unfix_slacks"] = 1
mysetup["DC_OPF"] = 1
mysetup["IntegerInvestments"] = 1
mysetup["BD_MaxIter"] = 300

myinputs_decomp = GenX.separate_inputs_subperiods(myinputs);
benders_inputs = GenX.generate_benders_inputs(mysetup,myinputs,myinputs_decomp)

planning_problem1, planning_sol1, operational_sol1, LB_hist1,UB_hist1, cpu_time1,feasibility_hist1  = GenX.benders(benders_inputs,mysetup,myinputs);
