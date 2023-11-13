module TestMethodOfMorris

using Test

include(joinpath(@__DIR__, "utilities.jl"))

test_path = "MethodofMorris"

# Define test inputs
genx_setup = Dict(
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
    "ParameterScale" => 1,
    "UCommit" => 0,
    "TimeDomainReductionFolder" => "TDR_Results",
    "TimeDomainReduction" => 0,
    "MethodofMorris" => 1,
    "EnableJuMPStringNames" => false,
    "MultiStage" => 0,
    "IncludeLossesInESR" => 0,
)

# Run the case and the Method of Morris
Morris_range = redirect_stdout(devnull) do
    EP, inputs, OPTIMIZER = run_genx_case_testing(test_path, genx_setup)
    morris(EP, test_path, genx_setup, inputs, test_path, OPTIMIZER, random = false)
end

# Test if output files are correct
test_result = Test.@test cmp_csv(
    joinpath(test_path, "morris.csv"),
    joinpath(test_path, "morris_true.csv"),
)

end # module TestMethodOfMorris
