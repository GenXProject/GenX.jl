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