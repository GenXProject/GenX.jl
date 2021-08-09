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
#=if v"1.3" <= VERSION < v"1.5"
	Pkg.add(Pkg.PackageSpec(name="Cbc", version="0.8.0"))
	Pkg.add(Pkg.PackageSpec(name="Clp", version="0.8.1"))
	Pkg.add(Pkg.PackageSpec(name="DataStructures", version="0.17.20"))
	Pkg.add(Pkg.PackageSpec(name="Dates"))
	Pkg.add(Pkg.PackageSpec(name="GLPK", version="0.14.8"))
	Pkg.add(Pkg.PackageSpec(name="Ipopt", version="0.6.0"))
	Pkg.add(Pkg.PackageSpec(name="JuMP", version="0.21.3"))
	Pkg.add(Pkg.PackageSpec(name="CPLEX", version="0.6.1"))
	Pkg.add(Pkg.PackageSpec(name="CSV", version="0.6.0"))
	Pkg.add(Pkg.PackageSpec(name="Clustering", version="0.14.2"))
	Pkg.add(Pkg.PackageSpec(name="Combinatorics", version="1.0.2"))
	Pkg.add(Pkg.PackageSpec(name="Distances", version="0.10.2"))
	Pkg.add(Pkg.PackageSpec(name="DataFrames", version="0.20.2")) #1.0.0
	Pkg.add(Pkg.PackageSpec(name="Documenter", version="0.24.7"))
	Pkg.add(Pkg.PackageSpec(name="DocumenterTools", version="0.1.9"))
	Pkg.add(Pkg.PackageSpec(name="Gurobi", version="0.7.6"))
	Pkg.add(Pkg.PackageSpec(name="DiffEqSensitivity"))
	Pkg.add(Pkg.PackageSpec(name="Statistics"))
	Pkg.add(Pkg.PackageSpec(name="OrdinaryDiffEq"))
	Pkg.add(Pkg.PackageSpec(name="QuasiMonteCarlo"))
	Pkg.add(Pkg.PackageSpec(name="BenchmarkTools"))
	Pkg.add(Pkg.PackageSpec(name="MathProgBase", version="0.7.8"))
	Pkg.add(Pkg.PackageSpec(name="StatsBase", version="0.33.0"))
	Pkg.add(Pkg.PackageSpec(name="YAML", version="0.4.3"))
	Pkg.add(Pkg.PackageSpec(name="LinearAlgebra"))
elseif v"1.5" <= VERSION < v"1.7"=#
	Pkg.add(Pkg.PackageSpec(name="Cbc", version="0.8.0"))
	Pkg.add(Pkg.PackageSpec(name="Clp", version="0.8.4"))
	Pkg.add(Pkg.PackageSpec(name="DataStructures", version="0.18.9"))
	Pkg.add(Pkg.PackageSpec(name="Dates"))
	Pkg.add(Pkg.PackageSpec(name="GLPK", version="0.14.12"))
	Pkg.add(Pkg.PackageSpec(name="Ipopt", version="0.7.0"))
	Pkg.add(Pkg.PackageSpec(name="JuMP", version="0.21.8"))
	#Pkg.add(Pkg.PackageSpec(name="CPLEX", version="0.7.7"))
	Pkg.add(Pkg.PackageSpec(name="CSV", version="0.8.5"))
	Pkg.add(Pkg.PackageSpec(name="Clustering", version="0.14.2"))
	Pkg.add(Pkg.PackageSpec(name="Combinatorics", version="1.0.2"))
	Pkg.add(Pkg.PackageSpec(name="Distances", version="0.10.3"))
	Pkg.add(Pkg.PackageSpec(name="DataFrames", version="1.0.0")) #0.20.2
	Pkg.add(Pkg.PackageSpec(name="Documenter", version="0.27.3"))
	Pkg.add(Pkg.PackageSpec(name="DocumenterTools", version="0.1.13"))
	#Pkg.add(Pkg.PackageSpec(name="Gurobi", version="0.9.14"))
	#Pkg.build("Gurobi")
	##Add if elseif with Method of Morris for these
	Pkg.add(Pkg.PackageSpec(name="DiffEqSensitivity", version="6.52.1"))
	Pkg.add(Pkg.PackageSpec(name="Statistics"))
	Pkg.add(Pkg.PackageSpec(name="OrdinaryDiffEq", version="5.60.1"))
	Pkg.add(Pkg.PackageSpec(name="QuasiMonteCarlo", version="0.2.3"))
	##Add if elseif with Method of Morris for these
	Pkg.add(Pkg.PackageSpec(name="BenchmarkTools", version="1.1.1"))
	Pkg.add(Pkg.PackageSpec(name="MathProgBase", version="0.7.8"))
	Pkg.add(Pkg.PackageSpec(name="StatsBase", version="0.33.8"))
	Pkg.add(Pkg.PackageSpec(name="YAML", version="0.4.7"))
	Pkg.add(Pkg.PackageSpec(name="LinearAlgebra"))
#end
#=
[336ed68f] CSV v0.8.5
[9961bab8] Cbc v0.8.0
[e2554f3b] Clp v0.8.4
[aaaa29a8] Clustering v0.14.2
[861a8166] Combinatorics v1.0.2
[a93c6f00] DataFrames v1.0.0
[864edb3b] DataStructures v0.18.9
[41bf760c] DiffEqSensitivity v6.52.1
[b4f34e82] Distances v0.10.3
[e30172f5] Documenter v0.27.3
[35a29f4d] DocumenterTools v0.1.13
[60bf3e95] GLPK v0.14.12
[2e9cd046] Gurobi v0.9.14
[b6b21f68] Ipopt v0.7.0
[4076af6c] JuMP v0.21.8
[fdba3010] MathProgBase v0.7.8
[1dea7af3] OrdinaryDiffEq v5.60.1
[8a4e6c94] QuasiMonteCarlo v0.2.3
[2913bbd2] StatsBase v0.33.8
[ddb6d928] YAML v0.4.7
[ade2ca70] Dates
[37e2e46d] LinearAlgebra
[10745b16] Statistics
=#