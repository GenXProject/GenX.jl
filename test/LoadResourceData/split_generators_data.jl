using CSV, DataFrames


folder_to_split = "test/Electrolyzer"
file_to_split = CSV.read(joinpath(folder_to_split, "Generators_data.csv"), DataFrame)

reference_folder = "test/Inputfiles"
resource_files = ("electrolyzer.csv",
                    "flex_demand.csv",
                    "hydro.csv",
                    "must_run.csv",
                    "storage.csv",
                    "thermal.csv",
                    "vre.csv")

policy_files = ("cap_res.csv",
                "esr.csv",
                "min_cap.csv",
                "max_cap.csv")

resource_types = (:electrolyzer,
                    :flex,
                    :hydro,
                    :must_run,
                    :stor,
                    :therm,
                    :vre)

all_cols = lowercase.(names(file_to_split))
rename!(file_to_split, all_cols)

# resources
for (resource_type,file) in zip(resource_types, resource_files)
    # select rows for a specific resource type
    rows_to_keep = file_to_split[!, resource_type] .== 1
    # select columns from the reference file
    df = CSV.read(joinpath(reference_folder, "resources/", file), DataFrame)
    columns = lowercase.(names(df))
    cols_to_keep = intersect(all_cols, columns)
    # write the new file
    df_out = file_to_split[rows_to_keep, cols_to_keep]
    rename!(df_out, titlecase.(cols_to_keep))
    CSV.write(joinpath(folder_to_split, "resources", file), df_out)
end

# policies


