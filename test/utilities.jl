using GenX
using JuMP
using Dates
using Logging, LoggingExtras


const TestResult = Union{Test.Result, String}

function run_genx_case_testing(test_path::AbstractString, genx_setup::Dict)
    @assert genx_setup["MultiStage"] ∈ [0, 1]
    # Create a ConsoleLogger that prints any log messages with level >= Warn to stderr
    warnerror_logger = ConsoleLogger(stderr, Logging.Warn)

    EP, inputs, OPTIMIZER = with_logger(warnerror_logger) do
        if genx_setup["MultiStage"] == 0
            run_genx_case_simple_testing(test_path, genx_setup)
        else
            run_genx_case_multistage_testing(test_path, genx_setup)
        end
    end
    return EP, inputs, OPTIMIZER
end

function run_genx_case_simple_testing(test_path::AbstractString, genx_setup::Dict)
    # Run the case
    OPTIMIZER = configure_solver(genx_setup["Solver"], test_path)
    inputs = load_inputs(genx_setup, test_path)
    EP = generate_model(genx_setup, inputs, OPTIMIZER)
    EP, _ = solve_model(EP, genx_setup)
    return EP, inputs, OPTIMIZER
end

function run_genx_case_multistage_testing(test_path::AbstractString, genx_setup::Dict)
    # Run the case
    OPTIMIZER = configure_solver(genx_setup["Solver"], test_path)

    model_dict = Dict()
    inputs_dict = Dict()

    for t in 1:genx_setup["MultiStageSettingsDict"]["NumStages"]
        # Step 0) Set Model Year
        genx_setup["MultiStageSettingsDict"]["CurStage"] = t

        # Step 1) Load Inputs
        inpath_sub = joinpath(test_path, string("Inputs_p", t))
        inputs_dict[t] = load_inputs(genx_setup, inpath_sub)
        inputs_dict[t] = configure_multi_stage_inputs(inputs_dict[t], genx_setup["MultiStageSettingsDict"], genx_setup["NetworkExpansion"])

        # Step 2) Generate model
        model_dict[t] = generate_model(genx_setup, inputs_dict[t], OPTIMIZER)
    end
    model_dict, _, inputs_dict = run_ddp(model_dict, genx_setup, inputs_dict)
    return model_dict, inputs_dict, OPTIMIZER
end


function write_testlog(test_path::AbstractString, message::AbstractString, test_result::TestResult)
    # Save the results to a log file
    # Format: datetime, objective value, tolerance, test result

    if !isdir(joinpath("Logs"))
        mkdir(joinpath("Logs"))
    end

    log_file_path = joinpath("Logs", "$(test_path).log")

    logger = FormatLogger(open(log_file_path, "a")) do io, args
        # Write only if the test passed or failed
        println(io, split(args.message,"\n")[1])
    end

    with_logger(logger) do
        time = Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
        @info "$time | $message | $test_result"
    end
end

function write_testlog(test_path::AbstractString, obj_test::Real, optimal_tol::Real, test_result::TestResult)
    message = "$obj_test ± $optimal_tol"
    write_testlog(test_path, message, test_result)
end

function write_testlog(test_path::AbstractString, obj_test::Vector{<:Real}, optimal_tol::Vector{<:Real}, test_result::TestResult)
    @assert length(obj_test) == length(optimal_tol)
    message = join(join.(zip(obj_test,optimal_tol), " ± "), ", ")
    write_testlog(test_path, message, test_result)
end
