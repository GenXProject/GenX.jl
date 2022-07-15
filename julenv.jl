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
Pkg.add("Cbc")
Pkg.add("Clp")
Pkg.add("DataStructures")
Pkg.add(Pkg.PackageSpec(name="Dates"))
Pkg.add("GLPK")
Pkg.add("Ipopt")
Pkg.add("JuMP")
Pkg.add("MathOptInterface")
Pkg.add("SCIP")
Pkg.add(Pkg.PackageSpec(name="HiGHS"))
############################################################################################
#Uncomment either of the following two lines for the particular version of CPLEX.jl desired
############################################################################################
#Pkg.add(Pkg.PackageSpec(name="CPLEX", version="0.6.1"))
#Pkg.add(Pkg.PackageSpec(name="CPLEX", version="0.7.7"))
############################################################################################
#Uncomment either of the following two lines for the particular version of Gurobi.jl desired
############################################################################################
Pkg.add("Gurobi")
#Pkg.add(Pkg.PackageSpec(name="Gurobi", version="0.10.3"))
#Pkg.add(Pkg.PackageSpec(name="Gurobi", version="0.9.14"))
Pkg.add("CSV")
Pkg.add("Clustering")
Pkg.add("Combinatorics")
Pkg.add("Distances")
Pkg.add("DataFrames")
Pkg.add("Documenter")
Pkg.add("DocumenterTools")
Pkg.add("DiffEqSensitivity")
Pkg.add(Pkg.PackageSpec(name="Statistics"))
Pkg.add("OrdinaryDiffEq")
Pkg.add("QuasiMonteCarlo")
Pkg.add("BenchmarkTools")
Pkg.add("MathProgBase")
Pkg.add("StatsBase")
Pkg.add("YAML")
Pkg.add(Pkg.PackageSpec(name="LinearAlgebra"))
Pkg.add(Pkg.PackageSpec(name="Random"))
Pkg.add("RecursiveArrayTools")

