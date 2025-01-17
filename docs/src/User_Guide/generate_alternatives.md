## Running Modeling to Generate Alternatives with GenX

GenX includes a modeling to generate alternatives (MGA) package that can be used to automatically enumerate a diverse set of near cost-optimal solutions to electricity system planning problems. To use the MGA algorithm, user will need to perform the following tasks:

1. Add a `Resource_Type` column in all the resource `.csv` files denoting the type of each technology.
2. Add a `MGA` column in all the resource `.csv` files denoting the availability of the technology.
3. Set the `ModelingToGenerateAlternatives` flag in the `genx_settings.yml` file to 1.
4. Set the `ModelingtoGenerateAlternativeSlack` flag in the `genx_settings.yml` file to the desirable level of slack.
5. Set the `ModelingToGenerateAlternativesIterations` flag to half the total number of desired solutions, as each iteration provides 2 solutions.
6. Set the `MGAAnnualGeneration` flag in the `genx_settings.yml` file to the desired MGA formulation.
7. Solve the model using `Run.jl` file.

Results from the MGA algorithm would be saved in MGA\_max and MGA\_min folders in the case folder.