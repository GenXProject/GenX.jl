using GenX
using Gurobi
using HiGHS
using Logging, LoggingExtras

optimizer = HiGHS.Optimizer
# optimizer = Gurobi.Optimizer

# case = "Example_Systems/Electrolyzer_Example"
case = "test/LoadResourceData"

genx_settings = GenX.get_settings_path(case, "genx_settings.yml") 
setup = configure_settings(genx_settings)

settings_path = GenX.get_settings_path(case)

println("Configuring Solver")
OPTIMIZER = configure_solver(settings_path, optimizer)

# const ModelScalingFactor = 1e+3
# scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

# # get path to resources data
# resources_folder = setup["ResourcePath"]
# resources_folder = joinpath(case,resources_folder)

# # load resources data and scale it if necessary
# resources = GenX.load_scaled_resources_data(resources_folder, scale_factor)

# # add policies-related attributes to resource dataframe
# policy_folder = setup["PolicyPath"]
# policy_folder = joinpath(case, policy_folder)
# GenX._add_policies_to_resources!(policy_folder, resources)

inputs = load_inputs(setup, case);

gen = inputs["RESOURCES"];

time_elapsed = @elapsed EP = generate_model(setup, inputs, OPTIMIZER)
println("Time to generate model: $time_elapsed")

@profview generate_model(setup, inputs, OPTIMIZER)

println("Solving Model")
EP, solve_time = solve_model(EP, setup)

println("Loading Inputs")
function test_1(setup, case)
    warnerror_logger = ConsoleLogger(stderr, Logging.Error)

    with_logger(warnerror_logger) do
        redirect_stdout(devnull) do
            input_data = load_inputs(setup, case)
        end
    end
end

function test_2(setup, input_data, OPTIMIZER)
    redirect_stdout(devnull) do
        EP = generate_model(setup, input_data, OPTIMIZER)
    end
end

using BenchmarkTools
@benchmark test_1($setup, $case)
@benchmark test_2($setup, $input_data, $OPTIMIZER)