## 1 Running GenX

We require several software elements to run the GenX model. To maintain consistency with the software versions, we have created an environment that will install all required packages. The list of compatible package versions is given below. An up-to-date list of Julia packages can be found in thejuliaenv.jl file in the main GenX directory on github.


 1. CSV (v0.6.0)

 2. DataFrames (v0.20.2)

 3. JuMP (v0.21.3)

 4. LinearAlgebra

 5. MathProgBase (v0.7.8)

 6. StatsBase (v0.33.0)

 7. YAML (v0.4.3)

 8. Clustering (v0.14.2)

 9. Combinatorics (v1.0.2)

 10. Distance (v0.10.2)

 11. Documenter (v0.24.7)

 12. DocumenterTools (v0.1.9)

Additionally, at least one of the below solver packages need to be installed.

 1. Gurobi (v0.7.6)

 2. CPLEX (v0.6.1)

To begin, you need to have Julia (v1.1.0 or greater) installed. Next, download or clone the GenX repository on your machine in a directory named `Genx`. Create this new directory in a location where you wish to store the environment.


### 1.1 Least cost formulation

To run the least-cost formulation in GenX, user will need to perform the following tasks:

1. Create settings file (.yml) that provides model and solver specifications.

2. Specify the `path` of the settings file and a GenX model in the `Run.jl` file.

3. From the command line: julia `Run.jl`.


### 1.2 Modeling to Generate Alternatives formulation

 To use the MGA algorithm, user will need to perform the following tasks:

 1. Add a `Resource_Type` column in the `Generators_data.csv` file denoting the type of each technology.

 2. Add a `MGA` column in the `Generators_data.csv` file denoting the availability of the technology.

 3. Activate the `ModelingToGenerateAlternatives` flag in the `GenX_settings.yml`.

 4. Set the `ModelingtoGenerateAlternativeSlack` flag in the `GenX_settings.yml` file to the desirable level of slack.

 5. Create a `Rand_mga_objective_coefficients.csv` file to provide random objective function coefficients for each MGA iteration. For each iteration, number of rows in the `Rand_mga_objective_coefficients.csv` file represents the number of distinct technology types while number of columns represent the number of model zones.

 6. Solve the model using `Run.jl` file.