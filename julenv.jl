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
Pkg.add(Pkg.PackageSpec(name="DataFrames", version="0.20.2"))
Pkg.add(Pkg.PackageSpec(name="Documenter", version="0.24.7"))
Pkg.add(Pkg.PackageSpec(name="DocumenterTools", version="0.1.9"))
Pkg.add(Pkg.PackageSpec(name="Gurobi", version="0.7.6"))
Pkg.add(Pkg.PackageSpec(name="MathProgBase", version="0.7.8"))
Pkg.add(Pkg.PackageSpec(name="StatsBase", version="0.33.0"))
Pkg.add(Pkg.PackageSpec(name="YAML", version="0.4.3"))
Pkg.add(Pkg.PackageSpec(name="LinearAlgebra"))
