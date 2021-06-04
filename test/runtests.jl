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
#These are just some dummy sample test; The full-grown unit testing module is under active development currently
@testset "GenX.jl" begin
    @test simple_operation(2.0, 3.0) == 5
    @test simple_operation(2.1, 3.1)==5.2
    @test simple_operation(21.0, 31.0)== 52.0
    @test simple_operation(73.0, 34.0)== 107.0
end
