module TestTDR

import Test, GenX, JLD2, Clustering

# suppress printing
console_out = stdout
redirect_stdout(devnull)

test_folder = settings_path = "TDR"

if isdir(joinpath(test_folder, "TDR_Results"))
    rm(joinpath(test_folder, "TDR_Results"), recursive=true)
end

# Inputs for cluster_inputs function
genx_setup = Dict()
genx_setup["NetworkExpansion"] = 0
genx_setup["TimeDomainReduction"] = 1
genx_setup["TimeDomainReductionFolder"] = "TDR_Results"
genx_setup["MultiStage"] = 0
genx_setup["UCommit"] = 2
genx_setup["CapacityReserveMargin"] = 1
genx_setup["Reserves"] = 0
genx_setup["MinCapReq"] = 1
genx_setup["MaxCapReq"] = 1
genx_setup["EnergyShareRequirement"] = 1
genx_setup["CO2Cap"] = 2

clustering_test = GenX.cluster_inputs(test_folder, settings_path, genx_setup)["ClusterObject"]

# Load true clustering
clustering_true = JLD2.load(joinpath(test_folder,"clusters_true.jld2"))["ClusterObject"]

# Clustering validation
R = Clustering.randindex(clustering_test, clustering_true)[2]
I = Clustering.mutualinfo(clustering_test, clustering_true)

# restore printing
redirect_stdout(console_out)
Test.@test R > 0.9   # Rand index should be close to 1
Test.@test I > 0.8   # Mutual information should be close to 1

end # module TestTDR