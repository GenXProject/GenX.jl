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

push!(LOAD_PATH,"../src/")
cd("../")
include(joinpath(pwd(), "package_activate.jl"))
genx_path = joinpath(pwd(), "src")
push!(LOAD_PATH, genx_path)
import DataStructures: OrderedDict
using GenX
using Documenter
#DocumenterTools.genkeys(user="GenXProject", repo="git@github.com:GenXProject/GenX.git")
DocMeta.setdocmeta!(GenX, :DocTestSetup, :(using GenX); recursive=true)
println(pwd())
genx_docpath = joinpath(pwd(), "docs/src")
push!(LOAD_PATH, genx_docpath)
pages = OrderedDict(
    "Welcome Page" => "index.md",
    "Model Concept and Overview" => [
        "Model Introduction" => "model_introduction.md",
        "Notation" => "model_notation.md",
        "Objective Function" => "objective_function.md",
        "Power Balance" => "power_balance.md"
    ],
    "Model Function Reference" => [
        "Core" => [
            "Discharge" => [
                "Discharge" => "discharge.md",
                "Investment Discharge" => "investment_discharge.md"
            ],
            "Non Served Energy" => "non_served_energy.md",
            "Reserves" => "reserves.md",
            "Transmission" => "transmission.md",
            "Unit Commitment" => "ucommit.md"
        ],
        "Resources" => [
            "Curtailable Variable Renewable" => "curtailable_variable_renewable.md",
            "Flexible Demand" => "flexible_demand.md",
            "Hydro" => "hydro_res.md",
            "Must Run" => "must_run.md",
            "Storage" => [
                "Storage" => "storage.md",
                "Investment Charge" => "investment_charge.md",
                "Investment Energy" => "investment_energy.md",
                "Long Duration Storage" => "long_duration_storage.md",
                "Storage All" => "storage_all.md",
                "Storage Asymmetric" => "storage_asymmetric.md",
                "Storage Symmetric" => "storage_symmetric.md"
            ],
            "Thermal" => [
                "Thermal" => "thermal.md",
                "Thermal Commit" => "thermal_commit.md",
                "Thermal No Commit" => "thermal_no_commit.md"
            ]
        ],
        "Policies" => [
            "Capacity Reserve Margin" => "cap_reserve_margin.md",
            "CO2 Capacity" => "co2_cap.md",
            "Energy Share Requirement" => "energy_share_requirement.md",
            "Minimum Capacity Requirement" => "minimum_capacity_requirement.md"
        ]
    ],
    "Methods" => "methods.md",
    "Additional Features" => "additional_features.md",
    "Model Inputs/Outputs Documentation" => "data_documentation.md",
    "GenX Inputs" => "load_inputs.md",
    "GenX Outputs" => "write_outputs.md",
)
makedocs(;
    modules=[GenX],
    authors="Jesse Jenkins, Nestor Sepulveda, Dharik Mallapragada, Aaron Schwartz, Neha Patankar, Qingyu Xu, Jack Morris, Sambuddha Chakrabarti",
    #repo="https://github.com/sambuddhac/GenX.jl/blob/{commit}{path}#{line}",
    sitename="GenX",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://genxproject.github.io/GenX",
        assets=String[],
    ),
    pages=[p for p in pages]
)

deploydocs(;
    repo="github.com/GenXProject/GenX.git",
    #target = "build",
    #branch = "main",
    #devbranch = "main",
    #push_preview = true,
)
