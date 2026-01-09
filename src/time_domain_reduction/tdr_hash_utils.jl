"""
    tdr_hash_utils.jl

Utilities for computing and verifying hashes of time series input files
used in Time Domain Reduction (TDR) to detect when input data has changed.
"""

using SHA

@doc raw"""
    compute_file_hash(filepath::AbstractString)

Compute SHA256 hash of a file.

# Arguments
- `filepath::AbstractString`: Path to the file to hash

# Returns
- String: Hexadecimal representation of the SHA256 hash

# Example
```julia
hash = compute_file_hash("path/to/file.csv")
```
"""
function compute_file_hash(filepath::AbstractString)
    if !isfile(filepath)
        return nothing
    end
    open(filepath, "r") do file
        return bytes2hex(sha256(file))
    end
end

@doc raw"""
    get_tdr_input_files(case_path::AbstractString, setup::Dict)

Get list of time series input files that should be hashed for TDR validation.

# Arguments
- `case_path::AbstractString`: Path to the case directory
- `setup::Dict`: GenX settings dictionary

# Returns
- Dict{String, String}: Dictionary mapping file keys to their full paths

# Example
```julia
files = get_tdr_input_files("/path/to/case", setup)
```
"""
function get_tdr_input_files(case_path::AbstractString, setup::Dict)
    system_path = joinpath(case_path, setup["SystemFolder"])
    settings_path = joinpath(case_path, "settings")
    
    files = Dict{String, String}()
    
    # Add demand data file (either Demand_data.csv or Load_data.csv)
    demand_file = joinpath(system_path, "Demand_data.csv")
    if isfile(demand_file)
        files["Demand_data"] = demand_file
    else
        load_file = joinpath(system_path, "Load_data.csv")
        if isfile(load_file)
            files["Load_data"] = load_file
        end
    end
    
    # Add generator variability file
    genvar_file = joinpath(system_path, "Generators_variability.csv")
    if isfile(genvar_file)
        files["Generators_variability"] = genvar_file
    end
    
    # Add fuels data file
    fuels_file = joinpath(system_path, "Fuels_data.csv")
    if isfile(fuels_file)
        files["Fuels_data"] = fuels_file
    end
    
    # Add TDR settings file
    tdr_settings_file = joinpath(settings_path, "time_domain_reduction_settings.yml")
    if isfile(tdr_settings_file)
        files["TDR_settings"] = tdr_settings_file
    end
    
    return files
end

@doc raw"""
    get_tdr_input_files_multistage(case_path::AbstractString, setup::Dict, stage_id::Int)

Get list of time series input files for a specific multi-stage planning stage.

# Arguments
- `case_path::AbstractString`: Path to the case directory
- `setup::Dict`: GenX settings dictionary
- `stage_id::Int`: Stage identifier for multi-stage problems

# Returns
- Dict{String, String}: Dictionary mapping file keys to their full paths
"""
function get_tdr_input_files_multistage(case_path::AbstractString, 
                                        setup::Dict, 
                                        stage_id::Int)
    input_stage_path = joinpath(case_path, "inputs", "inputs_p$(stage_id)")
    system_path = joinpath(input_stage_path, setup["SystemFolder"])
    settings_path = joinpath(case_path, "settings")
    
    files = Dict{String, String}()
    
    # Add demand data file
    demand_file = joinpath(system_path, "Demand_data.csv")
    if isfile(demand_file)
        files["Demand_data_p$(stage_id)"] = demand_file
    else
        load_file = joinpath(system_path, "Load_data.csv")
        if isfile(load_file)
            files["Load_data_p$(stage_id)"] = load_file
        end
    end
    
    # Add generator variability file
    genvar_file = joinpath(system_path, "Generators_variability.csv")
    if isfile(genvar_file)
        files["Generators_variability_p$(stage_id)"] = genvar_file
    end
    
    # Add fuels data file
    fuels_file = joinpath(system_path, "Fuels_data.csv")
    if isfile(fuels_file)
        files["Fuels_data_p$(stage_id)"] = fuels_file
    end
    
    # Add TDR settings file (shared across stages)
    tdr_settings_file = joinpath(settings_path, "time_domain_reduction_settings.yml")
    if isfile(tdr_settings_file)
        files["TDR_settings"] = tdr_settings_file
    end
    
    return files
end

@doc raw"""
    compute_tdr_input_hashes(case_path::AbstractString, setup::Dict)

Compute hashes for all TDR input files.

# Arguments
- `case_path::AbstractString`: Path to the case directory
- `setup::Dict`: GenX settings dictionary

# Returns
- Dict{String, String}: Dictionary mapping file keys to their hash values

# Example
```julia
hashes = compute_tdr_input_hashes("/path/to/case", setup)
```
"""
function compute_tdr_input_hashes(case_path::AbstractString, setup::Dict)
    files = get_tdr_input_files(case_path, setup)
    hashes = Dict{String, String}()
    
    for (key, filepath) in files
        hash = compute_file_hash(filepath)
        if !isnothing(hash)
            hashes[key] = hash
        end
    end
    
    return hashes
end

@doc raw"""
    save_tdr_hash_file(tdr_results_path::AbstractString, hashes::Dict)

Save computed hashes to a YAML file in the TDR_Results folder.

# Arguments
- `tdr_results_path::AbstractString`: Path to the TDR_Results directory
- `hashes::Dict`: Dictionary of file hashes to save

# Example
```julia
save_tdr_hash_file("/path/to/TDR_Results", hashes)
```
"""
function save_tdr_hash_file(tdr_results_path::AbstractString, hashes::Dict)
    # Ensure the directory exists
    if !isdir(tdr_results_path)
        mkpath(tdr_results_path)
    end
    
    hash_file_path = joinpath(tdr_results_path, "tdr_input_hashes.yml")
    
    # Add metadata
    hash_data = Dict(
        "created_at" => string(Dates.now()),
        "file_hashes" => hashes
    )
    
    YAML.write_file(hash_file_path, hash_data)
    
    return hash_file_path
end

@doc raw"""
    load_tdr_hash_file(tdr_results_path::AbstractString)

Load previously saved hashes from the TDR_Results folder.

# Arguments
- `tdr_results_path::AbstractString`: Path to the TDR_Results directory

# Returns
- Union{Dict, Nothing}: Dictionary of file hashes, or nothing if file doesn't exist

# Example
```julia
stored_hashes = load_tdr_hash_file("/path/to/TDR_Results")
```
"""
function load_tdr_hash_file(tdr_results_path::AbstractString)
    hash_file_path = joinpath(tdr_results_path, "tdr_input_hashes.yml")
    
    if !isfile(hash_file_path)
        return nothing
    end
    
    try
        hash_data = YAML.load_file(hash_file_path)
        return hash_data["file_hashes"]
    catch e
        @warn "Failed to load TDR hash file: $e"
        return nothing
    end
end

@doc raw"""
    tdr_inputs_have_changed(case_path::AbstractString, tdr_results_path::AbstractString, setup::Dict)

Check if TDR input files have changed since the last clustering.

# Arguments
- `case_path::AbstractString`: Path to the case directory
- `tdr_results_path::AbstractString`: Path to the TDR_Results directory
- `setup::Dict`: GenX settings dictionary

# Returns
- Bool: true if inputs have changed or hash file doesn't exist, false otherwise

# Example
```julia
if tdr_inputs_have_changed(case, tdr_path, setup)
    println("Input files have changed, need to re-run TDR")
end
```
"""
function tdr_inputs_have_changed(case_path::AbstractString, 
                                  tdr_results_path::AbstractString, 
                                  setup::Dict)
    # Load stored hashes
    stored_hashes = load_tdr_hash_file(tdr_results_path)
    
    # If no hash file exists, assume files have changed
    if isnothing(stored_hashes)
        return true
    end
    
    # Compute current hashes
    current_hashes = compute_tdr_input_hashes(case_path, setup)
    
    # Check if any hash has changed
    for (key, current_hash) in current_hashes
        if !haskey(stored_hashes, key) || stored_hashes[key] != current_hash
            return true
        end
    end
    
    # Check if any stored file is missing from current files
    for key in keys(stored_hashes)
        if !haskey(current_hashes, key)
            return true
        end
    end
    
    return false
end
