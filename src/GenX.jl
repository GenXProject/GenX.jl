"""
GenX: An Configurable Capacity Expansion Model
Copyright (C) 2021,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

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
export simple_operation
export choose_output_dir

# Multi-stage methods
export run_ddp
export configure_multi_stage_inputs
export load_inputs_multi_stage
export write_multi_stage_outputs
export run_genx_case!

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

# Uncomment if Gurobi or CPLEX active license and installations are there and the user intends to use either of them
#using CPLEX
#using Gurobi
#using CPLEX
#using MOI
#using SCIP
using HiGHS
using Clp
using Cbc

# Global scaling factor used when ParameterScale is on to shift values from MW to GW
# DO NOT CHANGE THIS (Unless you do so very carefully)
# To translate MW to GW, divide by ModelScalingFactor
# To translate $ to $M, multiply by ModelScalingFactor^2
# To translate $/MWh to $M/GWh, multiply by ModelScalingFactor
ModelScalingFactor = 1e+3

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

# don't want to include PreCluster.jl
include("time_domain_reduction/time_domain_reduction.jl")

#Just for unit testing; Under active development
include("simple_operation.jl")

include_all_in_folder("multi_stage")
include_all_in_folder("additional_tools")
end
