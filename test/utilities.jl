using GenX
using JuMP, HiGHS
using Dates
using CSV, DataFrames
using Logging, LoggingExtras

const TestResult = Union{Test.Result, String}

# Exception to throw if a csv file is not found
struct CSVFileNotFound <: Exception
    filefullpath::String
end
Base.showerror(io::IO, e::CSVFileNotFound) = print(io, e.filefullpath, " not found")

function run_genx_case_testing(test_path::AbstractString,
    test_setup::Dict,
    optimizer::Any = HiGHS.Optimizer)
    # Merge the genx_setup with the default settings
    settings = GenX.default_settings()
    merge!(settings, test_setup)

    @assert settings["MultiStage"] ∈ [0, 1]
    # Create a ConsoleLogger that prints any log messages with level >= Warn to stderr
    warnerror_logger = ConsoleLogger(stderr, Logging.Warn)

    EP, inputs, OPTIMIZER = with_logger(warnerror_logger) do
        if settings["MultiStage"] == 0
            run_genx_case_simple_testing(test_path, settings, optimizer)
        else
            run_genx_case_multistage_testing(test_path, settings, optimizer)
        end
    end
    return EP, inputs, OPTIMIZER
end

function run_genx_case_conflict_testing(test_path::AbstractString,
    test_setup::Dict,
    optimizer::Any = HiGHS.Optimizer)

    # Merge the genx_setup with the default settings
    settings = GenX.default_settings()
    merge!(settings, test_setup)

    @assert settings["MultiStage"] ∈ [0, 1]
    # Create a ConsoleLogger that prints any log messages with level >= Error to stderr
    error_logger = ConsoleLogger(stderr, Logging.Error)

    output = with_logger(error_logger) do
        OPTIMIZER = configure_solver(test_path, optimizer)
        inputs = load_inputs(settings, test_path)
        EP = generate_model(settings, inputs, OPTIMIZER)
        solve_model(EP, settings)
    end
    return output
end

function run_genx_case_simple_testing(test_path::AbstractString,
    genx_setup::Dict,
    optimizer::Any)
    # Run the case
    OPTIMIZER = configure_solver(test_path, optimizer)
    inputs = load_inputs(genx_setup, test_path)
    EP = generate_model(genx_setup, inputs, OPTIMIZER)
    EP, _ = solve_model(EP, genx_setup)
    return EP, inputs, OPTIMIZER
end

function run_genx_case_multistage_testing(test_path::AbstractString,
    genx_setup::Dict,
    optimizer::Any)
    # Run the case
    OPTIMIZER = configure_solver(test_path, optimizer)

    model_dict = Dict()
    inputs_dict = Dict()

    for t in 1:genx_setup["MultiStageSettingsDict"]["NumStages"]
        # Step 0) Set Model Year
        genx_setup["MultiStageSettingsDict"]["CurStage"] = t

        # Step 1) Load Inputs
        inpath_sub = joinpath(test_path, string("inputs_p", t))
        inputs_dict[t] = load_inputs(genx_setup, inpath_sub)
        inputs_dict[t] = configure_multi_stage_inputs(inputs_dict[t],
            genx_setup["MultiStageSettingsDict"],
            genx_setup["NetworkExpansion"])

        compute_cumulative_min_retirements!(inputs_dict, t)

        # Step 2) Generate model
        model_dict[t] = generate_model(genx_setup, inputs_dict[t], OPTIMIZER)
    end
    model_dict, _, inputs_dict = run_ddp(model_dict, genx_setup, inputs_dict)
    return model_dict, inputs_dict, OPTIMIZER
end

function write_testlog(test_path::AbstractString,
    message::AbstractString,
    test_result::TestResult)
    # Save the results to a log file
    # Format: datetime, message, test result

    Log_path = joinpath(@__DIR__, "Logs")
    if !isdir(Log_path)
        mkdir(Log_path)
    end

    log_file_path = joinpath(Log_path, "$(basename(test_path)).log")

    logger = FormatLogger(open(log_file_path, "a")) do io, args
        # Write only if the test passed or failed
        println(io, split(args.message, "\n")[1])
    end

    with_logger(logger) do
        time = Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
        @info "$time | $message | $test_result"
    end
end

function write_testlog(test_path::AbstractString,
    obj_test::Real,
    optimal_tol::Real,
    test_result::TestResult)
    # Save the results to a log file
    # Format: datetime, objective value ± tolerance, test result
    message = "$obj_test ± $optimal_tol"
    write_testlog(test_path, message, test_result)
end

function write_testlog(test_path::AbstractString,
    obj_test::Vector{<:Real},
    optimal_tol::Vector{<:Real},
    test_result::TestResult)
    # Save the results to a log file
    # Format: datetime, [objective value ± tolerance], test result
    @assert length(obj_test) == length(optimal_tol)
    message = join(join.(zip(obj_test, optimal_tol), " ± "), ", ")
    write_testlog(test_path, message, test_result)
end

function get_exponent_sciform(number::Real)
    # Get the exponent of a number in scientific notation
    return number == 0.0 ? 0 : Int(floor(log10(abs(number))))
end

function round_from_tol!(obj::Real, tol::Real)
    # Round the objective value to the same number of digits as the tolerance
    return round(obj, digits = (-1) * get_exponent_sciform(tol))
end

function cmp_csv(csv1::AbstractString, csv2::AbstractString)
    # Compare two csv files
    # Return true (false) if they are identical (different)
    # Throw an error if one of the files does not exist
    if !isfile(csv1)
        throw(CSVFileNotFound(csv1))
    end
    if !isfile(csv2)
        throw(CSVFileNotFound(csv2))
    end

    df1 = CSV.read(csv1, DataFrame)
    df2 = CSV.read(csv2, DataFrame)

    # Sort the csv files
    cols = sort(names(df1))
    cols ≠ sort(names(df2)) && error("Column names in $csv1 and $csv2 are different.")

    return isapprox_df(df1, df2)
end

"""
    isapprox_df(df1::DataFrame, df2::DataFrame)

Compare two DataFrames. Return true if they are identical or approximately equal.

# Arguments
- `df1::DataFrame`: first DataFrame
- `df2::DataFrame`: second DataFrame

# Returns
- `true` if the two DataFrames are identical or approximately equal
- `false` otherwise
"""
function isapprox_df(df1::DataFrame, df2::DataFrame)
    @assert length(names(df1)) == length(names(df2))
    @assert Set(names(df1)) == Set(names(df2))
    is_approx = true
    for col in names(df1)
        !isapprox_col(df1[!, col], df2[!, col]) && return false
    end
    return is_approx
end

"""
    isapprox_col(col1, col2)

Compare two columns of a DataFrame. Return true if they are identical or approximately equal.

# Arguments
- `col1::Vector`: first column
- `col2::Vector`: second column

# Returns
- `true` if the two columns are identical or approximately equal
- `false` otherwise
"""
function isapprox_col(col1, col2)
    if isequal(col1, col2) || (eltype(col1) <: Float64 && isapprox(col1, col2))
        return true
    elseif eltype(col1) <: AbstractString
        isapprox_col = true
        for i in eachindex(col1)
            if !isapprox_col
                break
            elseif !isnothing(tryparse(Float64, col1[i])) &&
                   !isnothing(tryparse(Float64, col2[i]))
                isapprox_col = isapprox_col &&
                               isapprox(parse(Float64, col1[i]), parse(Float64, col2[i]))
            else
                isapprox_col = isapprox_col && isequal(col1[i], col2[i])
            end
        end
        return isapprox_col
    end
    return false
end

macro warn_error_logger(block)
    quote
        result = nothing
        redirect_stdout(devnull) do
            # Create a ConsoleLogger that prints any log messages with level >= Warn to stderr
            warnerror_logger = ConsoleLogger(stderr, Logging.Warn)
            with_logger(warnerror_logger) do
                result = $(esc(block))
            end
        end
        result
    end
end
