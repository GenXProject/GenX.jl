module TestConflicts

using Test

include(joinpath(@__DIR__, "utilities.jl"))
test_path = joinpath(@__DIR__,"ComputeConflicts");

# Define test inputs
genx_setup =    Dict{Any,Any}(
    "PrintModel" => 0,
    "OverwriteResults" => 0,
    "NetworkExpansion" => 0,
    "Trans_Loss_Segments" => 1,
    "Reserves" => 0,
    "EnergyShareRequirement" => 0,
    "CapacityReserveMargin" => 0,
    "CO2Cap" => 0,
    "StorageLosses" => 1,
    "MinCapReq" => 0,
    "MaxCapReq" => 0,
    "ParameterScale" => 0,
    "WriteShadowPrices" => 0,
    "UCommit" => 0,
    "TimeDomainReduction" => 0,
    "TimeDomainReductionFolder" => "TDR_Results",
    "ModelingToGenerateAlternatives" => 0,
    "ModelingtoGenerateAlternativeSlack" => 0.1,
    "MultiStage" => 0,
    "MethodofMorris" => 0,
    "IncludeLossesInESR" => 0,
    "HydrogenHourlyMatching" => 0,
    "EnableJuMPStringNames" => false,
    "ComputeConflicts" => 0
)

genxoutput = redirect_stdout(devnull) do
    run_genx_case_conflict_testing(test_path, genx_setup)
end

test_result = @test  length(genxoutput)==2
write_testlog(test_path,"Testing that the infeasible model is correctly handled",test_result)


end