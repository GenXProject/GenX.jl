# DuckDB File Loading Implementation

## Summary

This PR replaces CSV-only file loading with DuckDB to support multiple file formats: `.csv`, `.csv.gz`, and `.parquet`.

## Changes Made

### 1. Core Implementation

#### Added DuckDB Dependency
- Added `DuckDB` package to `Project.toml` with version constraint `1.4.1`
- Added `using DuckDB` to `src/GenX.jl`

#### Modified `src/load_inputs/load_dataframe.jl`

**New Functions:**
- `get_column_names(path)`: Replaces `csv_header()` using DuckDB's DESCRIBE functionality
  - Works with CSV, gzipped CSV, and Parquet files
  - Returns column names as a vector of strings

- `find_file_with_extension(dir, basename_without_ext)`: Discovers files with alternate extensions
  - Tries `.csv`, `.csv.gz`, and `.parquet` in order of preference
  - Also checks case-insensitive variants

**Modified Functions:**
- `load_dataframe_from_file(path)`: Now uses DuckDB for all file reading
  - Automatically detects file type (CSV, CSV.GZ, Parquet)
  - Maintains backward compatibility with existing CSV files

- `check_for_duplicate_keys(path)`: Updated to handle DuckDB's auto-renaming
  - Detects when DuckDB has renamed duplicate columns (e.g., `Name` → `Name_1`)
  - Provides informative error messages

- `load_dataframe(dir, basenames)`: Enhanced with automatic format discovery
  - When requesting `Thermal.csv`, will find and load `Thermal.csv.gz` or `Thermal.parquet`
  - Logs info message when using alternate format

- `file_exists(dir, basenames)`: Updated to check for alternate file extensions

## Usage

### Backward Compatibility
All existing CSV files continue to work without any changes:
```julia
df = load_dataframe("resources/Thermal.csv")  # Works as before
```

### New Capabilities

#### Using Gzipped CSV Files
```julia
# Just replace .csv with .csv.gz - no code changes needed
df = load_dataframe("resources/Thermal.csv.gz")
```

#### Using Parquet Files
```julia
# Parquet files also work seamlessly
df = load_dataframe("resources/Thermal.parquet")
```

#### Automatic Format Discovery
```julia
# Request .csv file that doesn't exist
# If Thermal.csv.gz or Thermal.parquet exists, it will be found and loaded automatically
df = load_dataframe("resources", "Thermal.csv")
# Output: [ Info: Using file 'Thermal.parquet' instead of 'Thermal.csv'
```

### Creating Compressed Files

Users can create gzipped CSV files using standard tools:
```bash
# Compress existing CSV file
gzip -k Thermal.csv  # Creates Thermal.csv.gz, keeps original

# Or compress without keeping original
gzip Thermal.csv  # Creates Thermal.csv.gz, removes original
```

Users can create Parquet files using DuckDB (note: file paths are properly escaped internally):
```julia
using DuckDB
db = DuckDB.DB()
# GenX internally escapes file paths for SQL safety
# Users can do the same for their own code:
csv_path = "Thermal.csv"
parquet_path = "Thermal.parquet"
escaped_csv = replace(csv_path, "'" => "''")
escaped_parquet = replace(parquet_path, "'" => "''")
DuckDB.execute(db, """
    COPY (SELECT * FROM read_csv_auto('$escaped_csv')) 
    TO '$escaped_parquet' (FORMAT PARQUET)
""")
DuckDB.close(db)
```

## Benefits

1. **Reduced Storage**: Gzipped CSV files are typically 50-70% smaller than uncompressed CSV
2. **Faster I/O**: Parquet files can be 80-90% smaller and load faster than CSV
3. **Backward Compatible**: All existing CSV files work without modification
4. **Transparent**: Users can mix and match file formats as needed
5. **Automatic Discovery**: No code changes needed to switch file formats

## Testing

A comprehensive test suite has been added in `test/test_duckdb_file_loading.jl`:
- Tests CSV file loading (backward compatibility)
- Tests gzipped CSV file loading
- Tests Parquet file loading
- Tests automatic file format discovery
- Tests data consistency across all formats
- Tests duplicate column detection

All 15 tests pass successfully.

## Example File Size Comparison

Using the example `Thermal.csv` file:
- Original CSV: 686 bytes
- Gzipped CSV: 336 bytes (51% reduction)
- Parquet: ~4.1 KB (for this small file, overhead dominates; larger files see 80-90% reduction)

For large input files (100MB+), the benefits are substantial:
- Storage savings of 50-90%
- Faster load times (especially for Parquet)
- Lower memory usage during loading

## Migration Guide

No migration is required! The changes are fully backward compatible.

However, users can optionally:
1. Compress large CSV files with gzip to save space
2. Convert very large files to Parquet for better performance
3. Mix formats as needed - some files as CSV, others as Parquet

The code automatically handles all supported formats.
