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
using Gurobi
#using CPLEX
#using MOI
#using SCIP
using BenchmarkTools
using HiGHS
using Clp
using Cbc

# Global scaling factor used when ParameterScale is on to shift values from MW to GW
# DO NOT CHANGE THIS (Unless you do so very carefully)
# To translate MW to GW, divide by ModelScalingFactor
# To translate $ to $M, multiply by ModelScalingFactor^2
# To translate $/MWh to $M/GWh, multiply by ModelScalingFactor
ModelScalingFactor = 1e+3

# Case runner
include("case_runners/case_runner.jl")

# Configure settings
include("configure_settings/configure_settings.jl")

# Configure optimizer instance
include("configure_solver/configure_highs.jl")
include("configure_solver/configure_gurobi.jl")
include("configure_solver/configure_scip.jl")
include("configure_solver/configure_cplex.jl")
include("configure_solver/configure_clp.jl")
include("configure_solver/configure_cbc.jl")
include("configure_solver/configure_solver.jl")

# Load input data
include("load_inputs/load_generators_data.jl")
include("load_inputs/load_generators_variability.jl")
include("load_inputs/load_network_data.jl")
include("load_inputs/load_reserves.jl")
include("load_inputs/load_cap_reserve_margin.jl")
include("load_inputs/load_energy_share_requirement.jl")
include("load_inputs/load_co2_cap.jl")
include("load_inputs/load_period_map.jl")
include("load_inputs/load_minimum_capacity_requirement.jl")
include("load_inputs/load_load_data.jl")
include("load_inputs/load_fuels_data.jl")

include("load_inputs/load_inputs.jl")

include("time_domain_reduction/time_domain_reduction.jl")

#Core GenX Features
include("model/core/discharge/discharge.jl")
include("model/core/discharge/investment_discharge.jl")

include("model/core/non_served_energy.jl")
include("model/core/ucommit.jl")
include("model/core/emissions.jl")

include("model/core/reserves.jl")

include("model/core/transmission.jl")

include("model/resources/curtailable_variable_renewable/curtailable_variable_renewable.jl")

include("model/resources/flexible_demand/flexible_demand.jl")

include("model/resources/hydro/hydro_res.jl")
include("model/resources/hydro/hydro_inter_period_linkage.jl")

include("model/resources/must_run/must_run.jl")

include("model/resources/storage/storage.jl")
include("model/resources/storage/investment_energy.jl")
include("model/resources/storage/storage_all.jl")
include("model/resources/storage/long_duration_storage.jl")
include("model/resources/storage/investment_charge.jl")
include("model/resources/storage/storage_asymmetric.jl")
include("model/resources/storage/storage_symmetric.jl")

include("model/resources/thermal/thermal.jl")
include("model/resources/thermal/thermal_commit.jl")
include("model/resources/thermal/thermal_no_commit.jl")

include("model/resources/retrofits/retrofits.jl")

include("model/policies/co2_cap.jl")
include("model/policies/energy_share_requirement.jl")
include("model/policies/cap_reserve_margin.jl")
include("model/policies/minimum_capacity_requirement.jl")

include("model/generate_model.jl")
include("model/solve_model.jl")

include("write_outputs/dftranspose.jl")
include("write_outputs/write_capacity.jl")
include("write_outputs/write_capacityfactor.jl")
include("write_outputs/write_charge.jl")
include("write_outputs/write_charging_cost.jl")
include("write_outputs/write_costs.jl")
include("write_outputs/write_curtailment.jl")
include("write_outputs/write_emissions.jl")
include("write_outputs/write_energy_revenue.jl")
include("write_outputs/write_net_revenue.jl")
include("write_outputs/write_nse.jl")
include("write_outputs/write_power.jl")
include("write_outputs/write_power_balance.jl")
include("write_outputs/write_price.jl")
include("write_outputs/write_reliability.jl")
include("write_outputs/write_status.jl")
include("write_outputs/write_storage.jl")
include("write_outputs/write_storagedual.jl")
include("write_outputs/write_subsidy_revenue.jl")
include("write_outputs/write_time_weights.jl")
include("write_outputs/choose_output_dir.jl")

include("write_outputs/capacity_reserve_margin/write_capacity_value.jl")
include("write_outputs/capacity_reserve_margin/write_reserve_margin_revenue.jl")
include("write_outputs/capacity_reserve_margin/write_reserve_margin_w.jl")
include("write_outputs/capacity_reserve_margin/write_reserve_margin.jl")

include("write_outputs/energy_share_requirement/write_esr_prices.jl")
include("write_outputs/energy_share_requirement/write_esr_revenue.jl")

include("write_outputs/long_duration_storage/write_opwrap_lds_dstor.jl")
include("write_outputs/long_duration_storage/write_opwrap_lds_stor_init.jl")

include("write_outputs/reserves/write_reg.jl")
include("write_outputs/reserves/write_rsv.jl")

include("write_outputs/transmission/write_nw_expansion.jl")
include("write_outputs/transmission/write_transmission_flows.jl")
include("write_outputs/transmission/write_transmission_losses.jl")

include("write_outputs/ucommit/write_commit.jl")
include("write_outputs/ucommit/write_shutdown.jl")
include("write_outputs/ucommit/write_start.jl")

include("write_outputs/write_outputs.jl")

#Just for unit testing; Under active development
include("simple_operation.jl")

# Multi Stage files
include("multi_stage/write_multi_stage_settings.jl")
include("multi_stage/write_multi_stage_capacities_discharge.jl")
include("multi_stage/write_multi_stage_capacities_charge.jl")
include("multi_stage/write_multi_stage_capacities_energy.jl")
include("multi_stage/write_multi_stage_network_expansion.jl")
include("multi_stage/write_multi_stage_costs.jl")
include("multi_stage/write_multi_stage_stats.jl")
include("multi_stage/write_multi_stage_settings.jl")
include("multi_stage/dual_dynamic_programming.jl")
include("multi_stage/configure_multi_stage_inputs.jl")
include("multi_stage/endogenous_retirement.jl")

include("additional_tools/modeling_to_generate_alternatives.jl")
include("additional_tools/method_of_morris.jl")
end
