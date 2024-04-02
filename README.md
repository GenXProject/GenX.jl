# GenX 
<!---[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://genxproject.github.io/GenX/stable) -->
<!---[![Documentation Build](https://img.shields.io/badge/docs-stable-blue.svg](https://genxproject.github.io/GenX/stable) -->
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://genxproject.github.io/GenX.jl/v0.3/)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)
## Overview
GenX is a highly-configurable, [open source](https://github.com/GenXProject/GenX/blob/main/LICENSE) electricity resource capacity expansion model 
that incorporates several state-of-the-art practices in electricity system planning to offer improved decision support for a changing electricity landscape. 

The model was [originally developed](https://energy.mit.edu/publication/enhanced-decision-support-changing-electricity-landscape/) by 
[Jesse D. Jenkins](https://mae.princeton.edu/people/faculty/jenkins) and 
[Nestor A. Sepulveda](https://energy.mit.edu/profile/nestor-sepulveda/) at the Massachusetts Institute of Technology and is now jointly maintained by 
[a team of contributors](https://github.com/GenXProject/GenX#genx-team) at the MIT Energy Initiative (led by [Dharik Mallapragada](https://energy.mit.edu/profile/dharik-mallapragada/)) and the Princeton University ZERO Lab (led by Jenkins). 

GenX is a constrained linear or mixed integer linear optimization model that determines the portfolio of electricity generation, 
storage, transmission, and demand-side resource investments and operational decisions to meet electricity demand in one or more future planning years at lowest cost,
while subject to a variety of power system operational constraints, resource availability limits, and other imposed environmental, market design, and policy constraints.

GenX features a modular and transparent code structure developed in [Julia](http://julialang.org/) + [JuMP](http://jump.dev/).
The model is designed to be highly flexible and configurable for use in a variety of applications from academic research and technology evaluation to public policy and regulatory analysis and resource planning.
Depending on the planning problem or question to be studied,
GenX can be configured with varying levels of model resolution and scope, with regards to:
(1) temporal resolution of time series data such as electricity demand and renewable energy availability;
(2) power system operational detail and unit commitment constraints;
and (3) geospatial resolution and transmission network representation.
The model is also capable of representing a full range of conventional and novel electricity resources,
including thermal generators, variable renewable resources (wind and solar), run-of-river, reservoir and pumped-storage hydroelectric generators,
energy storage devices, demand-side flexibility, demand response, and several advanced technologies such as long-duration energy storage.

The 'main' branch is the current master branch of GenX. The various subdirectories are described below:

1. `src/` Contains the core GenX model code for reading inputs, model generation, solving and writing model outputs.

2. `Example_Systems/` Contains fully specified examples that users can use to test GenX and get familiar with its various features. Within this folder, we have two main sets of examples:
  - `SmallNewEngland/` , a simplified system consisting of 4 different resources per zone.
  - `RealSystemExample/`, a detailed system representation based on ISO New England and including many different resources (up to 58)

3. `docs/` Contains source files for documentation pertaining to the model.

## Requirements

GenX currently exists in version 0.3.7 and runs only on Julia v1.5.x, 1.6.x, 1.7.x, 1.8.x, and 1.9.x, where x>=0 and a minimum version of JuMP v1.1.1. We recommend the users to either stick to a particular version of Julia to run GenX. If however, the users decide to switch between versions, it's very important to delete the old Manifest.toml file and do a fresh build of GenX when switching between Julia versions.
There is also an older version of GenX, which is also currently maintained and runs on Julia 1.3.x and 1.4.x series.
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

Detailed documentation for GenX can be found [here](https://genxproject.github.io/GenX.jl/v0.3/).
It includes details of each of GenX's methods, required and optional input files, and outputs.
Interested users may also want to browse through [prior publications](https://energy.mit.edu/genx/#publications) that have used GenX to understand the various features of the tool.

## Running an Instance of GenX
1. Download or clone the GenX repository on your machine.
For this tutorial it will be assumed to be within your home directory: `/home/youruser/GenX`.
### Creating the Julia environment and installing dependencies
You could either start from a default terminal or a Julia REPL terminal. 
#### For a default terminal:
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
    
    ![Creating the Julia environment and installing dependencies: Steps 2-7](docs/src/assets/GenX_setup_tutorial_part_1.png)
    *Figure 1. Creating the Julia environment and installing dependencies from Project.toml file from inside the GenX folder: Steps 2-5*

8. Since we have already started Julia, we can run a case by executing the command `julia> include(“<path to your case>/Run.jl”)`. 

For example, in order to run the OneZone case within the `Example_Systems/SmallNewEngland` folder,
type `include("Example_Systems/SmallNewEngland/OneZone/Run.jl")` from the `julia>` prompt.

![Creating the Julia environment and installing dependencies: Steps 6-8](docs/src/assets/GenX_setup_tutorial_part_2.png)
*Figure 2. Creating the Julia environment and installing dependencies from Project.toml file from inside the GenX folder: Steps 6-8*

After the script runs to completion, results will be written to a folder called “Results”, located in the same directory as `Run.jl`.

#### For a Julia REPL terminal:
2. Open your desired version of Julia
3. In the Julia terminal, enter pkg manager mode by typing ]
Activate the project by typing activate /path/to/GenX
4. Type `instantiate` from the `(GenX) pkg` prompt.
   On Windows there is an issue with the prepopulated MUMPS_seq_jll v5.5.1 that prevents compilation of the solvers. To avoid this issue type 'add MUMPS_seq_jll@5.4.1' after running instantiate.
5. Type `st` to check that the dependecies have been installed. If there is no error, it has been successful.
6. Type the back key to come back to the `julia>` prompt.
7. Since we have already started Julia, we can run a case by executing the command `julia> include(“<path to your case>/Run.jl”)`. 

For example, in order to run the OneZone case within the `Example_Systems/SmallNewEngland` folder,
type `include("Example_Systems/SmallNewEngland/OneZone/Run.jl")` from the `julia>` prompt.


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

# Limitations of the GenX Model

While the benefits of an openly available generation and transmission expansion model are high, many approximations have been made due to missing data or to manage computational tractability.
The assumptions of the GenX model are listed below.
It serves as a caveat to the user and as an encouragement to improve the approximations.

## Time period
GenX makes the simplifying assumption that each time period contains n copies of a single, representative year.
GenX optimizes generation and transmission capacity for just this characteristic year within each time period, assuming the results for different years in the same time period are identical.
However, the GenX objective function accounts only for the cost of the final model time period.

## Cost
The GenX objective function assumes that the cost of powerplants is specified in the unit of currency per unit of capacity.
GenX also assumes that the capital cost of technologies is paid through loans.

## Market
GenX is a bottom-up (technology-explicit), partial equilibrium model that assumes perfect markets for commodities.
In other words, each commodity is produced such that the sum of producer and consumer surplus is maximized.

## Technology
Behavioral response and acceptance of new technology are often modeled simplistically as a discount rate or by externally fixing the technology capacity.
A higher, technology-specific discount rate represents consumer reluctance to accept newer technologies.

## Uncertainty
Because each model realization assumes a particular state of the world based on the input values drawn, the parameter uncertainty is propagated through the model in the case of myopic model runs

## Decision-making
GenX assumes rational decision making, with perfect information and perfect foresight, and simultaneously optimizes all decisions over the user-specified time horizon.

## Demand
GenX assumes price-elastic demand segments that are represented using piece-wise approximation rather than an inverse demand curve to keep the model linear.

# How to cite GenX

We request that users of GenX to cite it in their academic publications and patent filings.

```
MIT Energy Initiative and Princeton University ZERO lab. GenX: a configurable power system capacity expansion model for studying low-carbon energy futures n.d. https://github.com/GenXProject/GenX
```

# pygenx: Python interface for GenX

Python users can now run GenX from a thin-python-wrapper interface, developed by [Daniel Olsen](https://github.com/danielolsen).
This tool is called `pygenx` and can be cloned from the github page: [pygenx](https://github.com/danielolsen/pygenx).
It needs installation of Julia 1.3 and a clone of GenX repo along with your python installation. 

## Simple GenX Case Runner: For automated sequential batch run for GenX

It is now possible to run a list of GenX cases as separate batch jobs.
Alternatively, they can also be run locally in sequence, as one job.
It has been developed by [Jacob Schwartz](https://github.com/cfe316).
This tool is called `SimpleGenXCaseRunner` and can be cloned from the github page: [SimpleGenXCaseRunner](https://github.com/cfe316/SimpleGenXCaseRunner)

## Bug and feature requests and contact info
If you would like to report a bug in the code or request a feature, please use our [Issue Tracker](https://github.com/GenXProject/GenX/issues).
If you're unsure or have questions on how to use GenX that are not addressed by the above documentation, please reach out to Sambuddha Chakrabarti (sc87@princeton.edu), Jesse Jenkins (jdj2@princeton.edu) or Dharik Mallapragada (dharik@mit.edu).

## GenX Team
GenX has been developed jointly by researchers at the [MIT Energy Initiative](https://energy.mit.edu/) and the ZERO lab at Princeton University.
Key contributors include [Nestor A. Sepulveda](https://energy.mit.edu/profile/nestor-sepulveda/),
[Jesse D. Jenkins](https://mae.princeton.edu/people/faculty/jenkins),
[Dharik S. Mallapragada](https://energy.mit.edu/profile/dharik-mallapragada/),
[Aaron M. Schwartz](https://idss.mit.edu/staff/aaron-schwartz/),
[Neha S. Patankar](https://www.linkedin.com/in/nehapatankar),
[Qingyu Xu](https://www.linkedin.com/in/qingyu-xu-61b3567b),
[Jack Morris](https://www.linkedin.com/in/jack-morris-024b37121),
[Sambuddha Chakrabarti](https://www.linkedin.com/in/sambuddha-chakrabarti-ph-d-84157318).
