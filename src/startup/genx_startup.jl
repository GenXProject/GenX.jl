function print_genx_version()
    v = pkgversion(GenX)
    ascii_art = raw"""
     ____           __  __   _ _
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

"""
    precompile()

Precompiles the functions `run_genx_case!` and `cluster_inputs` with specific 
arguments. This function is intended to speed up the first use of GenX in a 
new Julia session by precompiling it. 

The function redirects standard output to `devnull` to suppress any output 
generated during the precompilation process, and sets up a logger to capture 
any warnings or errors.

# Output
Returns `nothing`.

"""
function _precompile()
    @info "Running precompile script for GenX. This may take a few minutes."
    redirect_stdout(devnull) do
        warnerror_logger = ConsoleLogger(stderr, Logging.Warn)
        with_logger(warnerror_logger) do
            @compile_workload begin
                case = joinpath(pkgdir(GenX), "precompile/case")
                _precompile_tdr(case)   # Precompile TDR
                run_genx_case!(case, HiGHS.Optimizer)   # Precompile run_genx_case!
            end
        end
    end
    isdir("precompile/case/results") &&
        rm("precompile/case/results"; force = true, recursive = true)   # Clean up
    return nothing
end

function _precompile_tdr(case)
    settings_path = get_settings_path(case)
    setup = configure_settings(get_settings_path(case, "genx_settings.yml"),
        get_settings_path(case, "output_settings.yml"))
    setup["TimeDomainReduction"] = 1    # Enable TDR for precompilation
    cluster_inputs(case, settings_path, setup)
    isdir("precompile/case/TDR_results") &&
        rm("precompile/case/TDR_results"; force = true, recursive = true)   # Clean up
    return nothing
end

# Precompile `run_genx_case!` and `TDR` unless the environment variable `GENX_PRECOMPILE` is set to `false`
if get(ENV, "GENX_PRECOMPILE", "true") != "false"
    _precompile()
end
