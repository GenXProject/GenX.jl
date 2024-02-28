module TestMultiStage

using Test

include(joinpath(@__DIR__, "utilities.jl"))

obj_true = [79734.80032, 41630.03494, 27855.20631]
test_path = joinpath(@__DIR__, "multi_stage");

# Define test inputs
multistage_setup = Dict(
    "NumStages" => 3,
    "StageLengths" => [10, 10, 10],
    "WACC" => 0.045,
    "ConvergenceTolerance" => 0.01,
    "Myopic" => 0,
)

genx_setup = Dict(
    "Trans_Loss_Segments" => 1,
    "OperationalReserves" => 1,
    "CO2Cap" => 2,
    "StorageLosses" => 1,
    "ParameterScale" => 1,
    "UCommit" => 2,
    "MultiStage" => 1,
    "MultiStageSettingsDict" => multistage_setup,
)

# Run the case and get the objective value and tolerance
EP, _, _ = redirect_stdout(devnull) do
    run_genx_case_testing(test_path, genx_setup)
end
obj_test = objective_value.(EP[i] for i = 1:multistage_setup["NumStages"])
optimal_tol_rel =
    get_attribute.(
        (EP[i] for i = 1:multistage_setup["NumStages"]),
        "ipm_optimality_tolerance",
    )
optimal_tol = optimal_tol_rel .* obj_test  # Convert to absolute tolerance

# Test the objective value
test_result = @test all(obj_true .- optimal_tol .<= obj_test .<= obj_true .+ optimal_tol)

# Round objective value and tolerance. Write to test log.
obj_test = round_from_tol!.(obj_test, optimal_tol)
optimal_tol = round_from_tol!.(optimal_tol, optimal_tol)
write_testlog(test_path, obj_test, optimal_tol, test_result)

function test_new_build(EP::Dict,inputs::Dict)
    ### Test that the resource with New_Build = 0 did not expand capacity
    a = true;

    for t in keys(EP)
        if t==1
            a = value(EP[t][:eTotalCap][1]) <= GenX.existing_cap_mw(inputs[1]["RESOURCES"][1])[1]
        else
            a = value(EP[t][:eTotalCap][1]) <= value(EP[t-1][:eTotalCap][1])
        end
        if a==false
            break
        end
    end

    return a
end

function test_can_retire(EP::Dict,inputs::Dict)
    ### Test that the resource with Can_Retire = 0 did not retire capacity
    a = true;
    
    for t in keys(EP)
        if t==1
            a = value(EP[t][:eTotalCap][1]) >= GenX.existing_cap_mw(inputs[1]["RESOURCES"][1])[1]
        else
            a = value(EP[t][:eTotalCap][1]) >= value(EP[t-1][:eTotalCap][1])
        end
        if a==false
            break
        end
    end

    return a
end

test_path_new_build = joinpath(test_path, "new_build");
EP, inputs, _ = redirect_stdout(devnull) do
    run_genx_case_testing(test_path_new_build, genx_setup);
end

new_build_test_result = @test test_new_build(EP,inputs)
write_testlog(test_path,"Testing that the resource with New_Build = 0 did not expand capacity",new_build_test_result)

test_path_can_retire = joinpath(test_path, "can_retire");
EP, inputs, _ = redirect_stdout(devnull) do
    run_genx_case_testing(test_path_can_retire, genx_setup);
end
can_retire_test_result = @test test_can_retire(EP,inputs)
write_testlog(test_path,"Testing that the resource with Can_Retire = 0 did not expand capacity",can_retire_test_result)

end # module TestMultiStage
