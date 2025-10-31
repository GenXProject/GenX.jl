function filenotfoundconstant()::String
    "FILENOTFOUND"
end

@doc raw"""
    file_exists(dir::AbstractString, basenames::Vector{String})::Bool

Checks that a file exists in a directory under (at least) one of a list of 'aliases'.
Now also checks for .csv.gz and .parquet alternatives.
"""
function file_exists(dir, basenames::Vector{String})::Bool
    if !isdir(dir)
        return false
    end
    best_basename = popfirst!(basenames)
    best_path = joinpath(dir, best_basename)
    if isfile(best_path)
        return true
    end

    FILENOTFOUND = filenotfoundconstant()
    
    # Try to find the file with different extensions if the basename ends with .csv
    if endswith(best_basename, ".csv")
        basename_without_ext = best_basename[1:end-4]
        found_file = find_file_with_extension(dir, basename_without_ext)
        if found_file != FILENOTFOUND
            return true
        end
    end

    for base in basenames
        target = look_for_file_with_alternate_case(dir, base)
        if target != FILENOTFOUND
            return true
        end
    end
    false
end

@doc raw"""
    load_dataframe(path::AbstractString)

Attempts to load a dataframe from a csv file with the given path.
If it's not found immediately, it will look for files with a different case (lower/upper)
in the file's basename.
"""
function load_dataframe(path::AbstractString)::DataFrame
    dir, base = dirname(path), basename(path)
    load_dataframe(dir, [base])
end

@doc raw"""
    load_dataframe(dir::AbstractString, base::AbstractString)

Attempts to load a dataframe from a csv file with the given directory and file name.
If not found immediately, look for files with a different case (lower/upper)
in the file's basename.
"""
function load_dataframe(dir::AbstractString, base::AbstractString)::DataFrame
    load_dataframe(dir, [base])
end

function load_dataframe(dir::AbstractString, basenames::Vector{String})::DataFrame
    best_basename = popfirst!(basenames)
    best_path = joinpath(dir, best_basename)
    
    # First try exact match
    if isfile(best_path)
        return load_dataframe_from_file(best_path)
    end
    
    FILENOTFOUND = filenotfoundconstant()
    
    # Try to find the file with different extensions if the basename ends with .csv
    if endswith(best_basename, ".csv")
        basename_without_ext = best_basename[1:end-4]  # Remove .csv extension
        found_file = find_file_with_extension(dir, basename_without_ext)
        if found_file != FILENOTFOUND
            if found_file != best_basename
                # Warn if using a different extension
                @info "Using file '$found_file' instead of '$best_basename'"
            end
            return load_dataframe_from_file(joinpath(dir, found_file))
        end
    else
        # If basename doesn't end with .csv, try case-insensitive match
        target = look_for_file_with_alternate_case(dir, best_basename)
        if target != FILENOTFOUND
            Base.depwarn(
                """The filename '$target' is deprecated. '$best_basename' is preferred.""",
                :load_dataframe,
                force = true)
            return load_dataframe_from_file(joinpath(dir, target))
        end
    end
    
    # Try alternative basenames (deprecated names)
    for base in basenames
        target = look_for_file_with_alternate_case(dir, base)
        if target != FILENOTFOUND
            Base.depwarn(
                """The filename '$target' is deprecated. '$best_basename' is preferred.""",
                :load_dataframe,
                force = true)
            return load_dataframe_from_file(joinpath(dir, target))
        end
    end
    
    throw_filenotfound_error(dir, best_basename)
end

function throw_filenotfound_error(dir, base)
    files_in_dir = readdir(dir)
    err_str = """File $base was not found in the directory, "$dir".
                 Try checking the spelling.
                 The files in the directory are $files_in_dir."""
    error(err_str)
end

"""
    find_file_with_extension(dir::AbstractString, basename_without_ext::AbstractString)::String

Find a file in the directory with one of the supported extensions (.csv, .csv.gz, .parquet).
Returns the filename if found, or FILENOTFOUND constant if not found.
"""
function find_file_with_extension(dir::AbstractString, basename_without_ext::AbstractString)::String
    FILENOTFOUND = filenotfoundconstant()
    
    # Try different extensions in order of preference
    extensions = [".csv", ".csv.gz", ".parquet"]
    
    for ext in extensions
        candidate = basename_without_ext * ext
        if isfile(joinpath(dir, candidate))
            return candidate
        end
        
        # Also try case-insensitive match
        target = look_for_file_with_alternate_case(dir, candidate)
        if target != FILENOTFOUND
            return target
        end
    end
    
    return FILENOTFOUND
end

function look_for_file_with_alternate_case(dir, base)::String
    lower_base = lowercase(base)

    files_in_dir = readdir(dir)
    lower_files = map(lowercase, files_in_dir)
    mapping = Dict(zip(lower_files, files_in_dir))

    if length(mapping) != length(files_in_dir)
        error("""Files in the directory may have names which differ only by upper/lowercase.
              This must be corrected.""")
    end

    FILENOTFOUND = filenotfoundconstant()
    target = get(mapping, lower_base, FILENOTFOUND)

    return target
end

"""
    get_column_names(path::AbstractString)

Get column names from a file using DuckDB's DESCRIBE functionality.
Supports CSV, gzipped CSV (.csv.gz), and Parquet files.

Note: The path comes from file system operations (not user input) and is 
validated by Julia's file existence checks before reaching this function.
"""
function get_column_names(path::AbstractString)
    # Validate that the path exists (security check)
    if !isfile(path)
        error("File does not exist: $path")
    end
    
    # Use DuckDB to describe the file and get column names
    db = DuckDB.DB()
    try
        # Escape single quotes in path for SQL safety
        # This is sufficient since paths come from file system, not user input
        escaped_path = replace(path, "'" => "''")
        
        # DuckDB can automatically detect file type
        desc_query = "DESCRIBE SELECT * FROM read_csv_auto('$escaped_path')"
        if endswith(path, ".parquet")
            desc_query = "DESCRIBE SELECT * FROM '$escaped_path'"
        end
        result = DuckDB.execute(db, desc_query) |> DataFrame
        return String.(result.column_name)
    finally
        DuckDB.close(db)
    end
end

function keep_duplicated_entries!(s, uniques)
    for u in uniques
        deleteat!(s, first(findall(x -> x == u, s)))
    end
    return s
end

function check_for_duplicate_keys(path::AbstractString)
    column_names = get_column_names(path)
    
    # DuckDB automatically renames duplicate columns (e.g., Name -> Name_1)
    # Check if any column names end with _N where N is a number, which indicates a duplicate
    duplicate_pattern = r"(.+)_(\d+)$"
    potential_dupes = String[]
    
    for col in column_names
        m = match(duplicate_pattern, col)
        if !isnothing(m)
            # Found a column with _N suffix, check if base name exists
            base_name = m.captures[1]
            if base_name in column_names
                push!(potential_dupes, col)
            end
        end
    end
    
    if !isempty(potential_dupes)
        @error """Some duplicate column names detected in the header of $path: $potential_dupes.
        DuckDB has automatically renamed them by appending _N suffixes.
        Duplicate column names may cause errors, as only the first is used.
        """
    end
end

"""
    load_dataframe_from_file(path)::DataFrame

Load a dataframe from a file using DuckDB.
Supports CSV, gzipped CSV (.csv.gz), and Parquet files.

Note: The path comes from file system operations (not user input) and is
validated by file existence checks before reaching this function.
"""
function load_dataframe_from_file(path)::DataFrame
    # Validate that the path exists (security check)
    if !isfile(path)
        error("File does not exist: $path")
    end
    
    check_for_duplicate_keys(path)
    
    # Use DuckDB to read the file
    db = DuckDB.DB()
    try
        # Escape single quotes in path for SQL safety
        # This is sufficient since paths come from file system, not user input
        escaped_path = replace(path, "'" => "''")
        
        # DuckDB automatically detects file type and handles CSV, CSV.GZ, and Parquet
        query = "SELECT * FROM read_csv_auto('$escaped_path')"
        if endswith(path, ".parquet")
            query = "SELECT * FROM '$escaped_path'"
        end
        return DuckDB.execute(db, query) |> DataFrame
    finally
        DuckDB.close(db)
    end
end

function find_matrix_columns_in_dataframe(df::DataFrame,
        columnprefix::AbstractString;
        prefixseparator = '_')::Vector{Int}
    all_columns = names(df)

    # 2 is the length of the '_' connector plus one for indexing
    get_integer_part(c) = tryparse(Int, c[(length(columnprefix) + 2):end])

    # if prefix is "ESR", the column name should be like "ESR_1"
    function is_of_this_column_type(c)
        startswith(c, columnprefix) &&
            length(c) >= length(columnprefix) + 2 &&
            c[length(columnprefix) + 1] == prefixseparator &&
            !isnothing(get_integer_part(c))
    end

    columns = filter(is_of_this_column_type, all_columns)
    columnnumbers = sort!(get_integer_part.(columns))
    return columnnumbers
end

@doc raw"""
    extract_matrix_from_dataframe(df::DataFrame, columnprefix::AbstractString)

Finds all columns in the dataframe which are of the form columnprefix_[Integer],
and extracts them in order into a matrix. The function also checks that there's at least
one column with this prefix, and that all columns numbered from 1...N exist.

This is now acceptable:
```
ESR_1, other_thing, ESR_3, ESR_2,
  0.1,           1,   0.3,   0.2,
  0.4,           2,   0.6,   0.5,
```
"""
function extract_matrix_from_dataframe(df::DataFrame,
        columnprefix::AbstractString;
        prefixseparator = '_')
    all_columns = names(df)
    columnnumbers = find_matrix_columns_in_dataframe(df,
        columnprefix,
        prefixseparator = prefixseparator)

    if length(columnnumbers) == 0
        msg = """an input dataframe with columns $all_columns was searched for
        numbered columns starting with $columnprefix, but nothing was found."""
        error(msg)
    end

    # check that the sequence of column numbers is 1..N
    if columnnumbers != collect(1:length(columnnumbers))
        msg = """the columns $columns in an input file must be numbered in
        a complete sequence from 1...N. It looks like some of the sequence is missing.
        This error could also occur if there are two columns with the same number."""
        error(msg)
    end

    sorted_columns = columnprefix .* prefixseparator .* string.(columnnumbers)
    Matrix(dropmissing(df[:, sorted_columns]))
end

function extract_matrix_from_resources(rs::Vector{T},
        columnprefix::AbstractString,
        default = 0.0) where {T <: AbstractResource}

    # attributes starting with columnprefix with a numeric suffix
    attributes_n = [attr
                    for attr in string.(attributes(rs[1]))
                    if startswith(attr, columnprefix)]
    # sort the attributes by the numeric suffix
    sort!(attributes_n, by = x -> parse(Int, split(x, "_")[end]))

    # extract the matrix of the attributes
    value = Matrix{Float64}(undef, length(rs), length(attributes_n))
    for (i, r) in enumerate(rs)
        for (j, attr) in enumerate(attributes_n)
            value[i, j] = get(r, Symbol(attr), default)
        end
    end

    return value
end

"""
    validate_df_cols(df::DataFrame, df_name::AbstractString, required_cols::Vector{AbstractString})

Check that the dataframe has all the required columns.

# Arguments
- `df::DataFrame`: the dataframe to check
- `df_name::AbstractString`: the name of the dataframe, for error messages
- `required_cols::Vector{AbstractString}`: the names of the required columns
"""
function validate_df_cols(df::DataFrame, df_name::AbstractString, required_cols)
    for col in required_cols
        if col ∉ names(df)
            error("$df_name data file is missing column $col")
        end
    end
end
