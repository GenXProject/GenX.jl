module GenX

#export package_activate
export configure_settings
export configure_solver
export load_inputs
export load_dataframe
export generate_model
export solve_model
export write_outputs
export cluster_inputs
export mga
export morris
export choose_output_dir

# Multi-stage methods
export run_ddp
export configure_multi_stage_inputs
export load_inputs_multi_stage
export compute_cumulative_min_retirements!
export write_multi_stage_outputs
export run_genx_case!
export run_timedomainreduction!

using JuMP # used for mathematical programming
using DataFrames #This package allows put together data into a matrix
using CSV
using StatsBase
using LinearAlgebra
using YAML
using Dates
using Clustering
using Distances
using Combinatorics
using Random
using RecursiveArrayTools
using Statistics
using HiGHS
using Logging

using PrecompileTools: @compile_workload

# Global scaling factor used when ParameterScale is on to shift values from MW to GW
# DO NOT CHANGE THIS (Unless you do so very carefully)
# To translate MW to GW, divide by ModelScalingFactor
# To translate $ to $M, multiply by ModelScalingFactor^2
# To translate $/MWh to $M/GWh, multiply by ModelScalingFactor
const ModelScalingFactor = 1e+3

"""
An abstract type that should be subtyped for users creating GenX resources.
"""
abstract type AbstractResource end

# thanks, ChatGPT
function include_all_in_folder(folder)
    base_path = joinpath(@__DIR__, folder)
    for (root, dirs, files) in Base.Filesystem.walkdir(base_path)
        for file in files
            if endswith(file, ".jl")
                include(joinpath(root, file))
            end
        end
    end
end

include_all_in_folder("case_runners")
include_all_in_folder("configure_settings")
include_all_in_folder("configure_solver")
include_all_in_folder("load_inputs")
include_all_in_folder("model")
include_all_in_folder("write_outputs")

include("time_domain_reduction/time_domain_reduction.jl")
include("time_domain_reduction/precluster.jl")
include("time_domain_reduction/full_time_series_reconstruction.jl")

include_all_in_folder("multi_stage")
include_all_in_folder("additional_tools")

include("startup/genx_startup.jl")

end
