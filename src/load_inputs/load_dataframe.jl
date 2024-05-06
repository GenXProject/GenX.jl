function filenotfoundconstant()::String
    "FILENOTFOUND"
end

@doc raw"""
    file_exists(dir::AbstractString, basenames::Vector{String})::Bool

Checks that a file exists in a directory under (at least) one of a list of 'aliases'.
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
    if isfile(best_path)
        return load_dataframe_from_file(best_path)
    end

    FILENOTFOUND = filenotfoundconstant()

    for base in basenames
        target = look_for_file_with_alternate_case(dir, base)
        # admonish
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

function csv_header(path::AbstractString)
    f = open(path, "r")
    header = readline(f)
    close(f)
    header
end

function keep_duplicated_entries!(s, uniques)
    for u in uniques
        deleteat!(s, first(findall(x -> x == u, s)))
    end
    return s
end

function check_for_duplicate_keys(path::AbstractString)
    header = csv_header(path)
    keys = split(header, ',')
    uniques = unique(keys)
    if length(keys) > length(uniques)
        dupes = keep_duplicated_entries!(keys, uniques)
        @error """Some duplicate column names detected in the header of $path: $dupes.
        Duplicate column names may cause errors, as only the first is used.
        """
    end
end

function load_dataframe_from_file(path)::DataFrame
    check_for_duplicate_keys(path)
    CSV.read(path, DataFrame, header = 1)
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
