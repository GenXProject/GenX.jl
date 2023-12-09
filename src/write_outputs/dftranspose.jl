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
"""
   df = dftranspose(df::DataFrame, withhead::Bool)

Returns a transpose of a Dataframe.\n
FIXME: This is for DataFrames@0.20.2, as used in GenX. 
Versions 0.21+ could use stack and unstack to make further changes while retaining the order
"""
function dftranspose(df::DataFrame, withhead::Bool)
	if withhead
		colnames = cat(:Row, Symbol.(df[!,1]), dims=1)
		return DataFrame([[names(df)]; collect.(eachrow(df))], colnames)
	else
		return DataFrame([[names(df)]; collect.(eachrow(df))], [:Row; Symbol.("x",axes(df, 1))])
	end
end # End dftranpose()
