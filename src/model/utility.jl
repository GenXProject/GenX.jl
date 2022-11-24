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

@doc raw"""
    hoursbefore(p::Int, t::Int, b::Int)

Determines the time index b hours before index t in
a landscape starting from t=1 which is separated
into distinct periods of length p.

For example, if p = 10,
1 hour before t=1 is t=10,
1 hour before t=10 is t=9
1 hour before t=11 is t=20
"""
function hoursbefore(p::Int, t::Int, b::Int)::Int
	period = div(t - 1, p)
	return period * p + mod1(t - b, p)
end

@doc raw"""
    hoursbefore(p::Int, t::Int, b::UnitRange)

This is a generalization of hoursbefore(... b::Int)
to allow for example b=1:3 to fetch a Vector{Int} of the three hours before
time index t.
"""
function hoursbefore(p::Int, t::Int, b::UnitRange{Int})::Vector{Int}
	period = div(t - 1, p)
	return period * p .+ mod1.(t .- b, p)
end


@doc raw"""
    hoursafter(p::Int, t::Int, a::Int)

Determines the time index a hours after index t in
a landscape starting from t=1 which is separated
into distinct periods of length p.

For example, if p = 10,
1 hour after t=9 is t=10,
1 hour after t=10 is t=1,
1 hour after t=11 is t=2
"""
function hoursafter(p::Int, t::Int, a::Int)::Int
    period = div(t - 1, p)
    return period * p + mod1(t + a, p)
end

@doc raw"""
    hoursafter(p::Int, t::Int, b::UnitRange)

This is a generalization of hoursafter(... b::Int)
to allow for example a=1:3 to fetch a Vector{Int} of the three hours after
time index t.
"""
function hoursafter(p::Int, t::Int, a::UnitRange{Int})::Vector{Int}
    period = div(t - 1, p)
    return period * p .+ mod1.(t .+ a, p)

end
