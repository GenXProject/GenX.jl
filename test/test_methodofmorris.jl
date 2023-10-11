module TestMethodOfMorris

using Test

include(joinpath(@__DIR__, "utilities.jl"))

test_path = "MethodofMorris"

# Define test inputs
genx_setup = Dict(
    "MacOrWindows" => "Mac",
    "PrintModel" => 0,
    "NetworkExpansion" => 0,
    "Trans_Loss_Segments" => 1,
    "Reserves" => 0,
    "EnergyShareRequirement" => 0,
    "CapacityReserveMargin" => 0,
    "CO2Cap" => 0,
    "StorageLosses" => 1,
    "MinCapReq" => 0,
    "MaxCapReq" => 0,
    "Solver" => "HiGHS",
    "ParameterScale" => 1,
    "WriteShadowPrices" => 1,
    "UCommit" => 0,
    "TimeDomainReductionFolder" => "TDR_Results",
    "TimeDomainReduction" => 0,
    "ModelingToGenerateAlternatives" => 0,
    "ModelingtoGenerateAlternativeSlack" => 0.1,
    "ModelingToGenerateAlternativeIterations" => 3,
    "MethodofMorris" => 1,
    "EnableJuMPStringNames" => false,
    "MultiStage" => 0,
    "IncludeLossesInESR" => 0,
)

# Run the case and check if the model was built
built = false
try
    Morris_range = redirect_stdout(devnull) do
        EP, inputs, OPTIMIZER = run_genx_case_testing(test_path, genx_setup)
        morris(EP, test_path, genx_setup, inputs, test_path, OPTIMIZER)
        rm(joinpath(@__DIR__, test_path, "morris.csv"))
    end
    #TODO: test Morris range 
    built = true

catch BoundsError
end

@static if VERSION ≥ v"1.7"
    test_result = Test.@test built broken = true
else
    test_result = built ? Test.Pass : Test.Fail
end

# Add the results to the test log
write_testlog(test_path, "Build and Run", test_result)

end # module TestMethodOfMorris
