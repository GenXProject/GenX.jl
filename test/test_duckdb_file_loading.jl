"""
Test DuckDB-based file loading functionality for CSV, CSV.GZ, and Parquet formats
"""

using Test
using GenX
using DataFrames
using DuckDB

@testset "DuckDB File Loading Tests" begin
    # Setup test directory
    test_dir = mktempdir()
    
    # Use an existing CSV file as reference
    reference_csv = joinpath(@__DIR__, "..", "example_systems", "10_IEEE_9_bus_DC_OPF", "resources", "Thermal.csv")
    
    @testset "Load CSV file" begin
        df = GenX.load_dataframe(reference_csv)
        @test size(df)[1] > 0
        @test size(df)[2] > 0
        @test "Resource" in names(df)
    end
    
    @testset "Load gzipped CSV file" begin
        # Create gzipped CSV
        test_csv = joinpath(test_dir, "test.csv")
        test_csv_gz = joinpath(test_dir, "test.csv.gz")
        cp(reference_csv, test_csv)
        run(`gzip -f $test_csv`)
        
        # Load gzipped file
        df_gz = GenX.load_dataframe(test_csv_gz)
        @test size(df_gz)[1] > 0
        @test size(df_gz)[2] > 0
        @test "Resource" in names(df_gz)
    end
    
    @testset "Load Parquet file" begin
        # Create Parquet file using DuckDB
        test_parquet = joinpath(test_dir, "test.parquet")
        db = DuckDB.DB()
        DuckDB.execute(db, "COPY (SELECT * FROM read_csv_auto('$reference_csv')) TO '$test_parquet' (FORMAT PARQUET)")
        DuckDB.close(db)
        
        # Load Parquet file
        df_pq = GenX.load_dataframe(test_parquet)
        @test size(df_pq)[1] > 0
        @test size(df_pq)[2] > 0
        @test "Resource" in names(df_pq)
    end
    
    @testset "Automatic file format discovery" begin
        # Create only a parquet file
        test_parquet = joinpath(test_dir, "auto_test.parquet")
        db = DuckDB.DB()
        DuckDB.execute(db, "COPY (SELECT * FROM read_csv_auto('$reference_csv')) TO '$test_parquet' (FORMAT PARQUET)")
        DuckDB.close(db)
        
        # Request .csv but it should find .parquet
        df = GenX.load_dataframe(test_dir, "auto_test.csv")
        @test size(df)[1] > 0
        @test "Resource" in names(df)
    end
    
    @testset "Data consistency across formats" begin
        # Create all three formats
        test_csv = joinpath(test_dir, "consistency_test.csv")
        test_csv_gz = joinpath(test_dir, "consistency_test2.csv.gz")
        test_parquet = joinpath(test_dir, "consistency_test3.parquet")
        
        # Copy and create files
        cp(reference_csv, test_csv)
        cp(reference_csv, joinpath(test_dir, "consistency_test2.csv"))
        run(`gzip -f $(joinpath(test_dir, "consistency_test2.csv"))`)
        
        db = DuckDB.DB()
        DuckDB.execute(db, "COPY (SELECT * FROM read_csv_auto('$reference_csv')) TO '$test_parquet' (FORMAT PARQUET)")
        DuckDB.close(db)
        
        # Load all formats
        df_csv = GenX.load_dataframe(test_csv)
        df_gz = GenX.load_dataframe(test_csv_gz)
        df_pq = GenX.load_dataframe(test_parquet)
        
        # Verify consistency
        @test size(df_csv) == size(df_gz) == size(df_pq)
        @test names(df_csv) == names(df_gz) == names(df_pq)
    end
    
    @testset "Duplicate column detection" begin
        # Create a CSV with duplicate columns
        dup_csv = joinpath(test_dir, "duplicate.csv")
        write(dup_csv, """Name,Age,Name,Value
Alice,30,Bob,100
Charlie,25,Dave,200
""")
        
        # Load the file - should log an error but not fail
        df = GenX.load_dataframe(dup_csv)
        
        # DuckDB renames duplicates to Name_1
        @test "Name" in names(df)
        @test "Name_1" in names(df)
    end
    
    # Cleanup
    rm(test_dir, recursive=true)
end
