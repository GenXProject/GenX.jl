module TestTDR


import GenX
import Test
import JLD2, Clustering

include(joinpath(@__DIR__, "utilities.jl"))

# suppress printing
console_out = stdout
redirect_stdout(devnull)

test_folder = settings_path = "TDR"
TDR_Results_test = joinpath(test_folder, "TDR_Results_test")

# Folder with true clustering results for LTS and non-LTS versions
TDR_Results_true = if VERSION == v"1.6.7"
    joinpath(test_folder, "TDR_Results_true_LTS")
else 
    joinpath(test_folder, "TDR_Results_true")
end

# Remove test folder if it exists
if isdir(TDR_Results_test)
    rm(TDR_Results_test, recursive = true)
end

# Inputs for cluster_inputs function
genx_setup = Dict(
    "NetworkExpansion" => 0,
    "TimeDomainReduction" => 1,
    "TimeDomainReductionFolder" => "TDR_Results_test",
    "MultiStage" => 0,
    "UCommit" => 2,
    "CapacityReserveMargin" => 1,
    "Reserves" => 0,
    "MinCapReq" => 1,
    "MaxCapReq" => 1,
    "EnergyShareRequirement" => 1,
    "CO2Cap" => 2,
)

clustering_test =
    GenX.cluster_inputs(test_folder, settings_path, genx_setup, random = false)["ClusterObject"]

# Load true clustering
clustering_true = JLD2.load(joinpath(TDR_Results_true, "clusters_true.jld2"))["ClusterObject"]

# Clustering validation
R = Clustering.randindex(clustering_test, clustering_true)
I = Clustering.mutualinfo(clustering_test, clustering_true)

# restore printing
redirect_stdout(console_out)

# test clusters
Test.@test round(R[1], digits = 1) == 1   # Adjusted Rand index should be equal to 1
Test.@test round(R[2], digits = 1) == 1   # Rand index should be equal to 1
Test.@test round(I, digits = 1) == 1      # Mutual information should be equal to 1

# test if output files are correct
for file in filter(endswith(".csv"), readdir(TDR_Results_true))
    Test.@test cmp_csv(joinpath(TDR_Results_test, file), joinpath(TDR_Results_true, file))
end

end # module TestTDR
