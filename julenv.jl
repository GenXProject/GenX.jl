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

import Pkg
using Pkg
Pkg.activate("GenXJulEnv")

Pkg.add(Pkg.PackageSpec(name="Cbc"))
Pkg.add(Pkg.PackageSpec(name="Clp"))
Pkg.add(Pkg.PackageSpec(name="Documenter"))
Pkg.add(Pkg.PackageSpec(name="DataStructures"))
Pkg.add(Pkg.PackageSpec(name="Dates"))
Pkg.add(Pkg.PackageSpec(name="JuMP"))
Pkg.add("MathOptInterface")
Pkg.add(Pkg.PackageSpec(name="SCIP"))
#Pkg.build("SCIP")
Pkg.add(Pkg.PackageSpec(name="HiGHS"))
############################################################################################
#Uncomment either of the following two lines for the particular version of CPLEX.jl desired
############################################################################################
#Pkg.add(Pkg.PackageSpec(name="CPLEX", version="0.6.1"))
#Pkg.add(Pkg.PackageSpec(name="CPLEX"))
############################################################################################
#Uncomment either of the following two lines for the particular version of Gurobi.jl desired
############################################################################################
#Pkg.add(Pkg.PackageSpec(name="Gurobi", version="0.10.3"))
#Pkg.add(Pkg.PackageSpec(name="Gurobi", version="0.11.3"))
Pkg.add(Pkg.PackageSpec(name="CSV"))
Pkg.add(Pkg.PackageSpec(name="Clustering"))
Pkg.add(Pkg.PackageSpec(name="Combinatorics"))
Pkg.add(Pkg.PackageSpec(name="Distances"))
Pkg.add(Pkg.PackageSpec(name="DataFrames"))
Pkg.add(Pkg.PackageSpec(name="Statistics"))
Pkg.add(Pkg.PackageSpec(name="OrdinaryDiffEq"))
Pkg.add(Pkg.PackageSpec(name="BenchmarkTools"))
Pkg.add(Pkg.PackageSpec(name="StatsBase"))
Pkg.add(Pkg.PackageSpec(name="YAML"))
Pkg.add(Pkg.PackageSpec(name="LinearAlgebra"))
Pkg.add(Pkg.PackageSpec(name="Random"))
Pkg.add(Pkg.PackageSpec(name="RecursiveArrayTools"))

