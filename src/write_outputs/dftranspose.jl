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

################################################################################
## function dftranspose(df)
##
## inputs: df - [DataFrame] a DataFrame object to be transposed
## results t - [DataFrame] a transposed version of the df DataFrame.
##		   withhead - [Boolean] if True, first column of df will become column
##		   names for t. Otherwise, first column will first row and column names
##		   will be generic (e.g. x1:xN)
##
## Note this function is necessary because no stock function to transpose
## DataFrames appears to exist.
################################################################################

function dftranspose(df::DataFrame, withhead::Bool)
	# Extract old column names (as Symbols)
	oldnames_temp = names(df)
	# Convert to String vector and save for use as new row names
	oldnames = Vector{Union{Nothing,String}}(nothing, length(oldnames_temp))
	for r in 1:length(oldnames_temp)
		oldnames[r] = String(oldnames_temp[r])
	end
	if(withhead)
		# Extract first row of data frame (Resources names) (as Strings) and save as new column names
		newnames = string.(df[:,1])
		startcol=2
	else
		startcol=1
	end
	# Collect each of the old columns and tranpose to new rows
	t = DataFrame(permutedims(df[:,startcol]))
	for c in (startcol+1):ncol(df)
		t = vcat(t,DataFrame(permutedims(df[:,c])))
	end
	# Set new column names
	if(withhead)
		t = DataFrame(t,Symbol(newnames[c]))
	end
	# Add new row names vector to data frame
	t = hcat(DataFrame(Row=oldnames[startcol:length(oldnames)]), t)
	# Return transposed data frame
	return t
end # End dftranpose()
