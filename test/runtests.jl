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

using GenX
using Test
using Logging

include("utilities.jl")


@testset "Simple operation" begin
    include("simple_op_test.jl")
end

@testset "Resource validation" begin
    include("resource_test.jl")
end

@testset "Expression manipulation" begin
    include("expression_manipulation_test.jl")
end

# Test GenX modules
@testset verbose = true "GenX modules" begin
    @testset "Three zones" begin
        include("test_threezones.jl")
    end

    @testset "Time domain reduction" begin
        include("test_time_domain_reduction.jl")
    end

    @testset "PiecewiseFuel CO2" begin
        include("test_piecewisefuel_CO2.jl")
    end

    @testset "VRE and storage" begin
        include("test_VREStor.jl")
    end

    @testset "Electrolyzer" begin
        include("test_electrolyzer.jl")
    end

    @testset "Multi Stage" begin
        include("test_multistage.jl")
    end
end
