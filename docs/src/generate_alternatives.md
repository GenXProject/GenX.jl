## Running Modeling to Generate Alternatives with GenX

GenX includes a modeling to generate alternatives (MGA) package that can be used to automatically enumerate a diverse set of near cost-optimal solutions to electricity system planning problems. To use the MGA algorithm, user will need to perform the following tasks:

1. Add a `Resource_Type` column in all the resource `.csv` files denoting the type of each technology.
2. Add a `MGA` column in all the resource `.csv` files denoting the availability of the technology.
3. Set the `ModelingToGenerateAlternatives` flag in the `GenX_Settings.yml` file to 1.
4. Set the `ModelingtoGenerateAlternativeSlack` flag in the `GenX_Settings.yml` file to the desirable level of slack.
5. Create a `Rand_mga_objective_coefficients.csv` file to provide random objective function coefficients for each MGA iteration.

For each iteration, number of rows in the `Rand_mga_objective_coefficients`.csv file represents the number of distinct technology types while number of columns represent the number of model zones.

Solve the model using `Run.jl` file.

Results from the MGA algorithm would be saved in MGA_max and MGA_min folders in the `Example_Systems/` folder.