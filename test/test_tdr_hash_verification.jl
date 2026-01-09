module TestTDRHashVerification

import GenX
import Test
import YAML

include(joinpath(@__DIR__, "utilities.jl"))

# suppress printing
console_out = stdout
redirect_stdout(devnull)

# Test setup
test_folder = "TDR"
test_system_path = joinpath(test_folder, "system")
test_settings_path = test_folder

# Create a temporary test case directory
temp_test_dir = mktempdir()
temp_system_dir = joinpath(temp_test_dir, "system")
temp_settings_dir = joinpath(temp_test_dir, "settings")
temp_tdr_results = joinpath(temp_test_dir, "TDR_Results")

# Setup test environment
mkpath(temp_system_dir)
mkpath(temp_settings_dir)
mkpath(temp_tdr_results)

# Copy test files
cp(joinpath(test_system_path, "Demand_data.csv"), joinpath(temp_system_dir, "Demand_data.csv"))
cp(joinpath(test_system_path, "Generators_variability.csv"), joinpath(temp_system_dir, "Generators_variability.csv"))
cp(joinpath(test_system_path, "Fuels_data.csv"), joinpath(temp_system_dir, "Fuels_data.csv"))
cp(joinpath(test_settings_path, "time_domain_reduction_settings.yml"), joinpath(temp_settings_dir, "time_domain_reduction_settings.yml"))

# Create test setup dictionary
test_setup = Dict(
    "SystemFolder" => "system",
    "TimeDomainReductionFolder" => "TDR_Results"
)

# restore printing
redirect_stdout(console_out)

# Test 1: compute_file_hash function
Test.@testset "compute_file_hash" begin
    demand_file = joinpath(temp_system_dir, "Demand_data.csv")
    hash1 = GenX.compute_file_hash(demand_file)
    
    # Hash should be a 64-character hex string (SHA256)
    Test.@test length(hash1) == 64
    Test.@test all(c -> c in "0123456789abcdef", hash1)
    
    # Computing hash twice should give same result
    hash2 = GenX.compute_file_hash(demand_file)
    Test.@test hash1 == hash2
    
    # Non-existent file should return nothing
    Test.@test isnothing(GenX.compute_file_hash("nonexistent_file.csv"))
end

# Test 2: get_tdr_input_files function
Test.@testset "get_tdr_input_files" begin
    files = GenX.get_tdr_input_files(temp_test_dir, test_setup)
    
    # Should find all required files
    Test.@test haskey(files, "Demand_data")
    Test.@test haskey(files, "Generators_variability")
    Test.@test haskey(files, "Fuels_data")
    Test.@test haskey(files, "TDR_settings")
    
    # File paths should exist
    Test.@test isfile(files["Demand_data"])
    Test.@test isfile(files["Generators_variability"])
    Test.@test isfile(files["Fuels_data"])
    Test.@test isfile(files["TDR_settings"])
end

# Test 3: compute_tdr_input_hashes function
Test.@testset "compute_tdr_input_hashes" begin
    hashes = GenX.compute_tdr_input_hashes(temp_test_dir, test_setup)
    
    # Should have hashes for all files
    Test.@test haskey(hashes, "Demand_data")
    Test.@test haskey(hashes, "Generators_variability")
    Test.@test haskey(hashes, "Fuels_data")
    Test.@test haskey(hashes, "TDR_settings")
    
    # All hashes should be 64-character hex strings
    for (key, hash) in hashes
        Test.@test length(hash) == 64
        Test.@test all(c -> c in "0123456789abcdef", hash)
    end
end

# Test 4: save_tdr_hash_file and load_tdr_hash_file functions
Test.@testset "save and load hash file" begin
    # Compute and save hashes
    hashes = GenX.compute_tdr_input_hashes(temp_test_dir, test_setup)
    hash_file_path = GenX.save_tdr_hash_file(temp_tdr_results, hashes)
    
    # Hash file should exist
    Test.@test isfile(hash_file_path)
    Test.@test isfile(joinpath(temp_tdr_results, "tdr_input_hashes.yml"))
    
    # Load hashes back
    loaded_hashes = GenX.load_tdr_hash_file(temp_tdr_results)
    Test.@test !isnothing(loaded_hashes)
    
    # Loaded hashes should match saved hashes
    for (key, value) in hashes
        Test.@test haskey(loaded_hashes, key)
        Test.@test loaded_hashes[key] == value
    end
    
    # Test loading from non-existent directory
    Test.@test isnothing(GenX.load_tdr_hash_file("/nonexistent/path"))
end

# Test 5: tdr_inputs_have_changed function
Test.@testset "tdr_inputs_have_changed" begin
    # First time: no hash file exists, should return true
    Test.@test GenX.tdr_inputs_have_changed(temp_test_dir, temp_tdr_results, test_setup) == true
    
    # Save hashes
    hashes = GenX.compute_tdr_input_hashes(temp_test_dir, test_setup)
    GenX.save_tdr_hash_file(temp_tdr_results, hashes)
    
    # Now hash file exists and matches, should return false
    Test.@test GenX.tdr_inputs_have_changed(temp_test_dir, temp_tdr_results, test_setup) == false
    
    # Modify a file
    demand_file = joinpath(temp_system_dir, "Demand_data.csv")
    open(demand_file, "a") do f
        write(f, "\n# Modified for testing")
    end
    
    # Should now detect change
    Test.@test GenX.tdr_inputs_have_changed(temp_test_dir, temp_tdr_results, test_setup) == true
end

# Clean up
rm(temp_test_dir, recursive=true)

println("All TDR hash verification tests passed!")

end # module TestTDRHashVerification
