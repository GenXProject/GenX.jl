module TestTDR


import GenX
import Test 
import JLD2, Clustering

# suppress printing
console_out = stdout
redirect_stdout(devnull)

test_folder = settings_path = "TDR"

if isdir(joinpath(test_folder, "TDR_Results"))
    rm(joinpath(test_folder, "TDR_Results"), recursive=true)
end

# Inputs for cluster_inputs function
genx_setup = Dict(
    "NetworkExpansion" => 0,
    "TimeDomainReduction" => 1,
    "TimeDomainReductionFolder" => "TDR_Results",
    "MultiStage" => 0,
    "UCommit" => 2,
    "CapacityReserveMargin" => 1,
    "Reserves" => 0,
    "MinCapReq" => 1,
    "MaxCapReq" => 1,
    "EnergyShareRequirement" => 1,
    "CO2Cap" => 2,
)

clustering_test = GenX.cluster_inputs(test_folder, settings_path, genx_setup)["ClusterObject"]

# Load true clustering
clustering_true = JLD2.load(joinpath(test_folder,"clusters_true.jld2"))["ClusterObject"]

# Clustering validation
R = Clustering.randindex(clustering_test, clustering_true)[2]
I = Clustering.mutualinfo(clustering_test, clustering_true)

# restore printing
redirect_stdout(console_out)

Test.@test round(R, digits=1) ≥ 0.9   # Rand index should be close to 1
Test.@test round(I, digits=1) ≥ 0.8   # Mutual information should be close to 1

end # module TestTDR