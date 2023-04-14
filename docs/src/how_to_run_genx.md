# Requirements

GenX currently exists in version 0.3.3 and runs only on Julia v1.5.x, 1.6.x, 1.7.x, 1.8.x, and 1.9.x, where x>=0 and a minimum version of JuMP v1.1.1. We recommend the users to either stick to a particular version of Julia to run GenX. If however, the users decide to switch between versions, it's very important to delete the old Manifest.toml file and do a fresh build of GenX when switching between Julia versions.
For those users who has previously cloned GenX, and has been running it successfully so far,
and therefore might be unwilling to run it on the latest version of Julia:
please look into the GitHub branch, [old_version](https://github.com/GenXProject/GenX/tree/old_version).
It is currently setup to use one of the following open-source freely available solvers:
(A) the default solver: [HiGHS](https://github.com/jump-dev/HiGHS.jl) for linear programming and MILP,
(B) [Clp](https://github.com/jump-dev/Clp.jl) for linear programming (LP) problems,
(C) [Cbc](https://github.com/jump-dev/Cbc.jl) for mixed integer linear programming (MILP) problems
We also provide the option to use one of these two commercial solvers: 
(D) [Gurobi](https://www.gurobi.com), or 
(E) [CPLEX](https://www.ibm.com/analytics/cplex-optimizer).
Note that using Gurobi and CPLEX requires a valid license on the host machine.
There are two ways to run GenX with either type of solver options (open-source free or, licensed commercial) as detailed in the section, `Running an Instance of GenX`.

The file `Project.toml` in the parent directory lists all of the packages and their versions needed to run GenX.
You can see all of the packages installed in your Julia environment and their version numbers by running `pkg> status` on the package manager command line in the Jula REPL.

## Documentation

Detailed documentation for GenX can be found [here](https://genxproject.github.io/GenX/dev).
It includes details of each of GenX's methods, required and optional input files, and outputs.
Interested users may also want to browse through [prior publications](https://energy.mit.edu/genx/#publications) that have used GenX to understand the various features of the tool.

## Running an Instance of GenX
1. Download or clone the GenX repository on your machine.
For this tutorial it will be assumed to be within your home directory: `/home/youruser/GenX`.

### Creating the Julia environment and installing dependencies

2. Start a terminal and navigate into the `GenX` folder.
3. Type `julia --project=.` to start an instance of the `julia` kernel with the `project` set to the current folder.
The `.` indicates the current folder. On Windows the location of Julia can also be specified as e.g., 'C:\julia-1.6.0\bin\julia.exe --project=.'

If it's your first time running GenX (or, if you have pulled after some major upgrades/release/version) execute steps 3-6.

4. Type `]` to bring up the package system `(GenX) pkg >` prompt. This indicates that the GenX project was detected. If you see `(@v1.6) pkg>` as the prompt, then the `project` was not successfully set.
5. Type `instantiate` from the `(GenX) pkg` prompt.
   On Windows there is an issue with the prepopulated MUMPS_seq_jll v5.5.1 that prevents compilation of the solvers. To avoid this issue type 'add MUMPS_seq_jll@5.4.1' after running instantiate.
6. Type `st` to check that the dependecies have been installed. If there is no error, it has been successful.
7. Type the back key to come back to the `julia>` prompt.

These steps can be skipped on subsequent runs.
Steps 2-5 are shown in Figure 1 and Steps 6-8 are shown in Figure 2.

![Creating the Julia environment and installing dependencies: Steps 2-7](assets/GenX_setup_tutorial_part_1.png)
*Figure 1. Creating the Julia environment and installing dependencies from Project.toml file from inside the GenX folder: Steps 2-5*

8. Since we have already started Julia, we can run a case by executing the command `julia> include(“<path to your case>/Run.jl”)`. 

For example, in order to run the OneZone case within the `Example_Systems/SmallNewEngland` folder,
type `include("Example_Systems/SmallNewEngland/OneZone/Run.jl")` from the `julia>` prompt.

![Creating the Julia environment and installing dependencies: Steps 6-8](assets/GenX_setup_tutorial_part_2.png)
*Figure 2. Creating the Julia environment and installing dependencies from Project.toml file from inside the GenX folder: Steps 6-8*

After the script runs to completion, results will be written to a folder called “Results”, located in the same directory as `Run.jl`.

### Running a case

Once Steps 1-6 have been performed, a case can be run from the terminal in a single line.
There's no need to be in a certain folder to run a case, but it is required to point `julia` to the project that you created.

For example, from inside the `GenX` folder:
`/home/youruser/GenX > julia --project=. /home/youruser/GenX/Example_Systems/SmallNewEngland/OneZone/Run.jl`

Or from another folder

`/arbitrary/location > julia --project="/home/youruser/GenX" /home/youruser/GenX/Example_Systems/SmallNewEngland/OneZone/Run.jl`

In fact, a best practice is to place your cases outside of the GenX repository:

`/arbitrary/location > julia --project="/home/youruser/GenX" /your/custom/case/Run.jl`

### What happens when you run a case

The Run.jl file in each of the example systems calls a function `run_genx_case!("path/to/case")` which is suitable for capacity expansion modeling of several varieties.
The following are the main steps performed in that function:

1. Establish path to environment setup files and GenX source files.
2. Read in model settings `genx_settings.yml` from the example directory.
3. Configure solver settings.
4. Load the model inputs from the example directory and perform time-domain clustering if required.
5. Generate a GenX model instance.
6. Solve the model.
7. Write the output files to a specified directory.

If your needs are more complex, it is possible to use a customized run script in place of simply calling `run_genx_case!`; the contents of that function could be a starting point. 

### Using commercial solvers: Gurobi or CPLEX
If you want to use the commercial solvers Gurobi or CPLEX:

1. Make sure you have a valid license and the actual solvers for either of Gurobi or CPLEX installed on your machine
2. Add Gurobi or CPLEX to the Julia Project.

```
> julia --project=/home/youruser/GenX

julia> <press close-bracket ] to access the package manager>
(GenX) pkg> add Gurobi
-or-
(GenX) pkg> add CPLEX
```
3. At the beginning of the `GenX/src/GenX.jl` file, uncomment `using Gurobi` and/or `using CPLEX`.
4. Set the appropriate solver in the `genx_settings.yml` file of your case

Note that if you have not already installed the required Julia packages or you do not have a valid Gurobi license on your host machine, you will receive an error message and Run.jl will not run to completion.


## Running Modeling to Generate Alternatives with GenX
GenX includes a modeling to generate alternatives (MGA) package that can be used to automatically enumerate a diverse set of near cost-optimal solutions to electricity system planning problems. To use the MGA algorithm, user will need to perform the following tasks:

1. Add a `Resource_Type` column in the `Generators_data.csv` file denoting the type of each technology.
2. Add a `MGA` column in the `Generators_data.csv` file denoting the availability of the technology.
3. Set the `ModelingToGenerateAlternatives` flag in the `GenX_Settings.yml` file to 1.
4. Set the `ModelingtoGenerateAlternativeSlack` flag in the `GenX_Settings.yml` file to the desirable level of slack.
5. Create a `Rand_mga_objective_coefficients.csv` file to provide random objective function coefficients for each MGA iteration.
  For each iteration, number of rows in the `Rand_mga_objective_coefficients.csv` file represents the number of distinct technology types while number of columns represent the number of model zones.
6. Solve the model using `Run.jl` file.

Results from the MGA algorithm would be saved in `MGA_max` and `MGA_min` folders in the `Example_Systems/` folder.
