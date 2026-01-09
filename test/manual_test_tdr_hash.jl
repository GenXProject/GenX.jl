#!/usr/bin/env julia
"""
Manual test script for TDR hash verification feature.

This script demonstrates:
1. Running TDR for the first time (no hash file exists)
2. Running again with unchanged inputs (hash check passes, skips TDR)
3. Modifying an input file
4. Running again (hash check fails, re-runs TDR)
"""

using Pkg
Pkg.activate(".")

using GenX
using YAML

println("=".repeat(70))
println("TDR Hash Verification Feature - Manual Test")
println("=".repeat(70))

# Use example system 1
case_path = joinpath(@__DIR__, "..", "example_systems", "1_three_zones")
settings_path = joinpath(case_path, "settings")
tdr_folder = "TDR_Results"
tdr_path = joinpath(case_path, tdr_folder)

# Load settings
genx_settings_file = joinpath(settings_path, "genx_settings.yml")
output_settings_file = joinpath(settings_path, "output_settings.yml")
setup = GenX.configure_settings(genx_settings_file, output_settings_file)

println("\n1. Testing initial state...")
println("-".repeat(70))

# Clean up any existing TDR results
if isdir(tdr_path)
    println("Removing existing TDR results...")
    rm(tdr_path, recursive=true)
end

println("✓ TDR results directory cleared")

# Check if hash file exists
hash_file = joinpath(tdr_path, "tdr_input_hashes.yml")
println("Hash file exists: ", isfile(hash_file))

# Check if TDR files exist
tdr_exists = GenX.time_domain_reduced_files_exist(tdr_path, case_path, setup)
println("TDR files exist (with hash check): ", tdr_exists)

println("\n2. Running TDR for the first time...")
println("-".repeat(70))

# Run TDR clustering
println("Running cluster_inputs...")
result = GenX.cluster_inputs(case_path, settings_path, setup, random=false)
println("✓ TDR clustering completed")

# Check if hash file was created
println("Hash file created: ", isfile(hash_file))

# Display hash file contents
if isfile(hash_file)
    hash_data = YAML.load_file(hash_file)
    println("\nHash file contents:")
    println("  Created at: ", hash_data["created_at"])
    println("  Number of files hashed: ", length(hash_data["file_hashes"]))
    for (key, value) in hash_data["file_hashes"]
        println("    $key: $(value[1:16])...")
    end
end

println("\n3. Testing with unchanged inputs...")
println("-".repeat(70))

# Check if inputs have changed
inputs_changed = GenX.tdr_inputs_have_changed(case_path, tdr_path, setup)
println("Input files changed: ", inputs_changed)

# Check if TDR files exist (should be true now)
tdr_exists = GenX.time_domain_reduced_files_exist(tdr_path, case_path, setup)
println("TDR files exist (with hash check): ", tdr_exists)

if !inputs_changed
    println("✓ Hash verification passed - TDR would be skipped")
else
    println("✗ Hash verification failed unexpectedly")
end

println("\n4. Testing with modified input...")
println("-".repeat(70))

# Backup original demand file
demand_file = joinpath(case_path, setup["SystemFolder"], "Demand_data.csv")
backup_file = demand_file * ".backup"
cp(demand_file, backup_file, force=true)
println("Created backup of Demand_data.csv")

# Modify the file slightly (add a comment at the end)
open(demand_file, "a") do f
    write(f, "\n# Test modification to trigger hash change\n")
end
println("Modified Demand_data.csv")

# Check if inputs have changed
inputs_changed = GenX.tdr_inputs_have_changed(case_path, tdr_path, setup)
println("Input files changed: ", inputs_changed)

# Check if TDR files exist (should be false due to hash mismatch)
tdr_exists = GenX.time_domain_reduced_files_exist(tdr_path, case_path, setup)
println("TDR files exist (with hash check): ", tdr_exists)

if inputs_changed && !tdr_exists
    println("✓ Hash verification correctly detected file change")
else
    println("✗ Hash verification failed to detect change")
end

# Restore original file
mv(backup_file, demand_file, force=true)
println("Restored original Demand_data.csv")

println("\n5. Testing TDR settings change...")
println("-".repeat(70))

# Backup TDR settings
tdr_settings_file = joinpath(settings_path, "time_domain_reduction_settings.yml")
tdr_backup = tdr_settings_file * ".backup"
cp(tdr_settings_file, tdr_backup, force=true)
println("Created backup of time_domain_reduction_settings.yml")

# Modify TDR settings
tdr_settings = YAML.load_file(tdr_settings_file)
original_minperiods = tdr_settings["MinPeriods"]
tdr_settings["MinPeriods"] = original_minperiods + 1
YAML.write_file(tdr_settings_file, tdr_settings)
println("Modified TDR settings (changed MinPeriods)")

# Check if inputs have changed
inputs_changed = GenX.tdr_inputs_have_changed(case_path, tdr_path, setup)
println("Input files changed: ", inputs_changed)

if inputs_changed
    println("✓ Hash verification correctly detected TDR settings change")
else
    println("✗ Hash verification failed to detect TDR settings change")
end

# Restore original settings
mv(tdr_backup, tdr_settings_file, force=true)
println("Restored original time_domain_reduction_settings.yml")

println("\n" * "=".repeat(70))
println("Manual test completed successfully!")
println("=".repeat(70))
