module TestIncentivesSystem

using Test

include(joinpath(@__DIR__, "utilities.jl"))

# Use a compact 3-zone system with incentives enabled
obj_true = nothing  # no golden value yet; we just check solve and non-negativity

test_path = "incentives"

# Define test inputs with incentives
genx_setup = Dict(
    "NetworkExpansion" => 1,
    "Trans_Loss_Segments" => 1,
    "CO2Cap" => 0,
    "StorageLosses" => 1,
    "MinCapReq" => 0,
    "InvestmentIncentive" => 1,
    "ProductionIncentive" => 1,
    "ParameterScale" => 1,
    "UCommit" => 2,
)

EP, inputs, _ = redirect_stdout(devnull) do
    run_genx_case_testing(test_path, genx_setup)
end

# Basic checks
@test haskey(EP.obj_dict, :eTotalInvIncentiveBenefit)
@test haskey(EP.obj_dict, :eTotalProdIncentiveBenefit)
@test haskey(EP.obj_dict, :eInvIncentiveBenefit)
@test haskey(EP.obj_dict, :eProdIncentiveBenefit)

inv_incentive_benefit = JuMP.value(EP[:eTotalInvIncentiveBenefit])
prod_incentive_benefit = JuMP.value(EP[:eTotalProdIncentiveBenefit])

@test inv_incentive_benefit >= 0
@test prod_incentive_benefit >= 0

# We at least assert the model solved to optimality
@test termination_status(EP) in (MOI.OPTIMAL, MOI.LOCALLY_SOLVED)

end # module
