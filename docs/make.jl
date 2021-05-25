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

DocMeta.setdocmeta!(GenX, :DocTestSetup, :(using GenX); recursive=true)
println(pwd())
genx_docpath = joinpath(pwd(), "docs/src")
push!(LOAD_PATH, genx_docpath)
#=pages = OrderedDict(
    "Welcome Page" => "index.md",
    "Load Inputs" => "load-inputs.md",
    "Model Components" => Any[
        "Discharge" => "discharge.md",
        "Non Served Energy" => "non-served-energy.md",
        "Reserves" => "reserves.md",
        "Unit Commitment" => "ucommit.md"
    ],
    "Resources" => Any[
        "Curtailable Variable Renewable" => "curtailable-variable-renewable.md",
        "Flexible Demand" => "flexible-demand.md",
        "Hydro" => "hydro-res.md",
        "Must Run" => "must-run.md",
        "Thermal Commit" => "thermal-commit.md",
        "Thermal No Commit" => "thermal-no-commit.md"
    ],
    "Methods" => Any[
        "Time Domain Reduction" => "time-domain-reduction.md"
    ],
    "GenX Data" => "data-documentation.md",
    "GenX Outputs" => "write-outputs.md"
)=#

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
    pages=[
    "Welcome Page" => "index.md",
    "Load Inputs" => "load-inputs.md",
    "Model Components" => Any[
        "Discharge" => "discharge.md",
        "Non Served Energy" => "non-served-energy.md",
        "Reserves" => "reserves.md",
        "Unit Commitment" => "ucommit.md"
    ],
    "Resources" => Any[
        "Curtailable Variable Renewable" => "curtailable-variable-renewable.md",
        "Flexible Demand" => "flexible-demand.md",
        "Hydro" => "hydro-res.md",
        "Must Run" => "must-run.md",
        "Thermal Commit" => "thermal-commit.md",
        "Thermal No Commit" => "thermal-no-commit.md"
    ],
    "Methods" => Any[
        "Time Domain Reduction" => "time-domain-reduction.md"
    ],
    "GenX Data" => "data-documentation.md",
    "GenX Outputs" => "write-outputs.md"
    ]
)

deploydocs(;
    repo="github.com/GenXProject/GenX",
    target = "build",
    branch = "main",
    devbranch = "main",
    push_preview = true,
)
