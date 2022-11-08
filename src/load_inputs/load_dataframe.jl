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
    load_dataframe(path::AbstractString)

Attempts to load a dataframe from a csv file with the given path.
If it's not found immediately, it will look for files with a different case (lower/upper)
in the file's basename.
"""
function load_dataframe(path::AbstractString)
    if isfile(path)
        return load_dataframe_from_file(path)
    end

    # not immediately found
    dir, base = dirname(path), basename(path)
    target = look_for_file_with_alternate_case(dir, base)
    load_dataframe_from_file(joinpath(dir, target))
end

function look_for_file_with_alternate_case(dir, base)
    lower_base = lowercase(base)

    files_in_dir = readdir(dir)
    lower_files = map(lowercase, files_in_dir)
    mapping = Dict(zip(lower_files, files_in_dir))

    if length(mapping) != length(files_in_dir)
        error("""Files in the directory may have names which differ only by upper/lowercase.
              This must be corrected.""")
    end

    FILE_NOT_FOUND = "FILENOTFOUND"
    target = get(mapping, lower_base, FILE_NOT_FOUND)
    if target == FILE_NOT_FOUND
        err_str = """File $base was not found in the directory, "$dir".
                     Try checking the spelling.
                     The files in the directory are $files_in_dir"""
        error(err_str)
    end


    return target
end


function load_dataframe_from_file(path)
    CSV.read(path, DataFrame, header=1)
end
