function __init__()
    print_genx_version()
end

function print_genx_version()
    v = pkgversion(GenX)
    ascii_art = raw"""  ____           __  __   _ _
    / ___| ___ _ __ \ \/ /  (_) |
   | |  _ / _ \ '_ \ \  /   | | |
   | |_| |  __/ | | |/  \ _ | | |
    \____|\___|_| |_/_/\_(_)/ |_|
                          |__/
    """
    ascii_art *= "Version: $(v)"
    println(ascii_art)
    return nothing
end


# This function is a workaround for Julia versions < 1.9.
function pkgversion(m::Module)
    if VERSION >= v"1.9"
        return Base.pkgversion(m)
    else
        _pkgdir = pkgdir(m)
        _pkgdir === nothing && return nothing
        project_file = joinpath(_pkgdir, "Project.toml")
        isa(project_file, String) && return get_project_version(project_file)
        return nothing
    end
end

function get_project_version(project_file::String)
    d = Base.parsed_toml(project_file)
    v = get(d, "version", nothing)
    isnothing(v) && return nothing
    return VersionNumber(v::AbstractString)
end
