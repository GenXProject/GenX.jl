# GenX
# GenX [![Build Status](https://travis-ci.com/GenXProject/GenX.svg?branch=main)](https://travis-ci.com/GenXProject/GenX)[![Coverage Status](https://coveralls.io/repos/github/GenXProject/GenX/badge.svg?branch=main)](https://coveralls.io/github/GenXProject/GenX?branch=main)[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://genxproject.github.io/GenX/stable) [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://genxproject.github.io/GenX/dev) [![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)
## Overview
GenX is a highly-configurable, [open source](https://github.com/GenXProject/GenX/blob/main/LICENSE) electricity resource capacity expansion model that incorporates several state-of-the-art practices in electricity system planning to offer improved decision support for a changing electricity landscape. 

The model was [originally developed](https://energy.mit.edu/publication/enhanced-decision-support-changing-electricity-landscape/) by [Jesse D. Jenkins](https://mae.princeton.edu/people/faculty/jenkins) and [Nestor A. Sepulveda](https://energy.mit.edu/profile/nestor-sepulveda/) at the Massachusetts Institute of Technology and is now jointly maintained by [a team of contributors](https://github.com/GenXProject/GenX#genx-team) at the MIT Energy Initiative (led by [Dharik Mallapragada](https://energy.mit.edu/profile/dharik-mallapragada/)) and the Princeton University ZERO Lab (led by Jenkins). 

GenX is a constrained linear or mixed integer linear optimization model that determines the portfolio of electricity generation, storage, transmission, and demand-side resource investments and operational decisions to meet electricity demand in one or more future planning years at lowest cost, while subject to a variety of power system operational constraints, resource availability limits, and other imposed environmental, market design, and policy constraints.

GenX features a modular and transparent code structure developed in [Julia](http://julialang.org/) + [JuMP](http://jump.dev/). The model is designed to be highly flexible and configurable for use in a variety of applications from academic research and technology evaluation to public policy and regulatory analysis and resource planning. Depending on the planning problem or question to be studied, GenX can be configured with varying levels of model resolution and scope, with regards to: (1) temporal resolution of time series data such as electricity demand and renewable energy availability; (2) power system operational detail and unit commitment constraints; and (3) geospatial resolution and transmission network representation. The model is also capable of representing a full range of conventional and novel electricity resources, including thermal generators, variable renewable resources (wind and solar), run-of-river, reservoir and pumped-storage hydroelectric generators, energy storage devices, demand-side flexibility, demand response, and several advanced technologies such as long-duration energy storage.

The 'main' branch is the current master branch of GenX. The various subdirectories are described below:

1. `src/` Contains the core GenX model code for reading inputs, model generation, solving and writing model outputs.

2. `Example_Systems/` Contains fully specified examples that users can use to test GenX and get familiar with its various features. Within this folder, we have two sets of examples:
-   `RealSystemExample/`, a detailed system representation based on ISO New England and including many different resources (upto 58)
-   `SmallNewEngland/` , a simplified system consisting of 4 different resources per zone.

3.  `docs/` Contains all the documentation pertaining to the model.

4. `GenXJulEnv` Contains the .toml files related to setting up the Julia environment with all the specified package versions in `julenv.jl`.

## Requirements

GenX currently exists in version 0.1.0 and runs only on Julia v1.6.x and v1.5.x series, where x>=0 and a minimum version of JuMP v0.21.x. There is also an older version of GenX, which is also currently maintained and runs on Julia 1.3.x and 1.4.x series (For those users who has previously cloned GenX, and has been running it successfully so far, and therefore might be unwilling to run it on the latest version of Julia: please look into the GitHub branch, [old_version](https://github.com/GenXProject/GenX/tree/old_version)). It is currently setup to use one of the following open-source freely available solvers: A) [Clp](https://github.com/jump-dev/Clp.jl) for linear programming (LP) problems and (B) [Cbc](https://github.com/jump-dev/Cbc.jl) for mixed integer linear programming (MILP) problems. We also provide the option to use one of these two commercial solvers: C) [Gurobi](https://www.gurobi.com), and D) [CPLEX](https://www.ibm.com/analytics/cplex-optimizer). Note that using Gurobi and CPLEX requires a valid license on the host machine. There are two ways to run GenX with either type of solver options (open-source free or, licensed commercial) as detailed in the section, `Running an Instance of GenX`.

The file `julenv.jl` in the parent directory lists all of the packages and their versions needed to run GenX. You can see all of the packages installed in your Julia environment and their version numbers by running `pkg> status` on the package manager command line in the Jula REPL.

## Documentation

Detailed documentation for GenX can be found [here](https://genxproject.github.io/GenX/dev). It includes details of each of GenX's methods, required and optional input files, and outputs. Interested users may also want to browse through prior publications that have used GenX to understand the various features of the tool. Full publication list is available [here](https://energy.mit.edu/genx/#publications).

## Running an Instance of GenX
Download or clone the GenX repository on your machine in a directory named 'GenX'. Create this new directory in a location where you wish to store the GenXJulEnv environment.

The Run.jl file in each of the example sub-folders within `Example_Systems/` provides an example of how to use GenX.jl for capacity expansion modeling. The following are the main steps performed in the Run.jl script:
1.	Establish path to environment setup files and GenX source files.
2.	Read in model settings `GenX_Settings.yml` from the example directory.
3.  Configure solver settings.
4.	Load the model inputs from the example directory and perform time-domain clustering if required.
5.	Generate a GenX model instance.
6.	Solve the model.
7.	Write the output files to a specified directory.

Here are step-by-step instructions for running Run.jl, following the two slightly different methods:

### Method 1: Creating the Julia environment and installing dependencies from Project.toml file

1. Start a terminal and navigate into the `GenX` folder.
2. Type `julia --project=.` to start an instance of the `julia` kernal with the `project` set to the current folder. The `.` indicates the current folder.

If it's your first time running GenX (or, if you have pulled after some major upgrades/release/version) execute steps 3-6.

3. Type `]` to bring up the package system `(GenX) pkg >` prompt. This indicates that the GenX project was detected. If you see `(@v1.6) pkg>` as the prompt, then the `project` was not successfully set.
4. Type `instantiate` from the `(GenX) pkg` prompt.
5. Type `st` to check that the dependecies have been installed.
6. Type the back key to come back to the `julia>` prompt.

Steps 3-6 can be skipped on subsequent runs.

Execution of the entire sequence of the six steps is shown in Figure 1.

![Creating the Julia environment and installing dependencies from Project.toml file from inside the GenX folder: Steps 1-6](docs/src/assets/Method1_Julia_Kernel_from_inside_GenX_Step1_Updated.png)
*Figure 1. Creating the Julia environment and installing dependencies from Project.toml file from inside the GenX folder: Steps 1-6*

7. Run the script by executing the command `julia> include(“<path to your case>/Run.jl”)`. For example, in order to run the OneZone case within the Example_Systems/SmallNewEngland folder, type `include("Example_Systems/SmallNewEngland/OneZone/Run.jl")` from the `julia>` prompt.

Execution of step 7 should look like the figure below:

![Creating the Julia environment and installing dependencies from Project.toml file from inside the GenX folder: Step 7](docs/src/assets/Method1_Julia_Kernel_from_inside_GenX_Step2_Updated.png)
*Figure 2. Creating the Julia environment and installing dependencies from Project.toml file from inside the GenX folder: Step 7*

8. After the script runs to completion, results will be written to a folder called “Results”, located in the same directory as `Run.jl`.

### Method 2: Creating the Julia environment and installing the dependencies by building the Project.toml files by running activation script

1. Start an instance of the Julia kernel.
2. Make your present working directory to be where the Run.jl is located. To do this, you can use the Julia command `julia> cd(“/path/to/directory/containing/file)`, using the actual pathname of the directory containing Run.jl. Note that all your inputs files should be in this directory in addition to Run.jl. Details about the required input files can be found in the documentation linked above or in the examples provided in the folder `Example_Systems/`. You can check your present working directory by running the command `julia> pwd()`.
3. Uncomment the following lines of code at the beginning of the `Run.jl` file (which is currently commented out):
    `environment_path = "../../../package_activate.jl"`
    `include(environment_path)`
4. Run the script by executing the command `julia> include(“Run.jl”)`.
5. After the script runs to completion, results will be written to a folder called “Results”, also located in the same directory as `Run.jl`.

Note that if you have not already installed the required Julia packages, you are using a version of JuMP other than v0.21.4, or you do not have a valid Gurobi license on your host machine, you will receive an error message and Run.jl will not run to completion.

If you want to use either of Gurobi or CPLEX solvers, instead or Clp or Cbc do the following:
1. Uncomment the relevant lines in the `[deps]` and `[compat]` in the Project.toml file within GenX/ folder
2. Uncomment the relevent `using Gurobi` and/or `using CPLEX` at the beginning of the `GenX.jl` file
3. Set the appropriate solver in the `genx_settings.yml` file
4. Make sure you have a valid license and the actual solvers for either of Gurobi or CPLEX installed on your machine

Note that if you have not already installed the required Julia packages, you are using a version of JuMP other than v0.21.4, or you do not have a valid Gurobi license on your host machine, you will receive an error message and Run.jl will not run to completion.

## Running Modeling to Generate Alternatives with GenX
GenX includes a modeling to generate alternatives (MGA) package that can be used to automatically enumerate a diverse set of near cost-optimal solutions to electricity system planning problems. To use the MGA algorithm, user will need to perform the following tasks:

1. Add a `Resource_Type` column in the `Generators_data.csv` file denoting the type of each technology.
2. Add a `MGA` column in the `Generators_data.csv` file denoting the availability of the technology.
3. Set the `ModelingToGenerateAlternatives` flag in the `GenX_Settings.yml` file to 1.
4. Set the `ModelingtoGenerateAlternativeSlack` flag in the `GenX_Settings.yml` file to the desirable level of slack.
5. Create a `Rand_mga_objective_coefficients.csv` file to provide random objective function coefficients for each MGA iteration. For each iteration, number of rows in the `Rand_mga_objective_coefficients.csv` file represents the number of distinct technology types while number of columns represent the number of model zones.
6. Solve the model using `Run.jl` file.

Results from the MGA algorithm would be saved in `MGA_max` and `MGA_min` folders in the `Example_Systems/` folder.

## pygenx: Python interface for GenX

Python users can now run GenX from a thin-python-wrapper interface, developed by [Daniel Olsen](https://github.com/danielolsen). This tool is called `pygenx` and can be cloned from the github page: [pygenx](https://github.com/danielolsen/pygenx). It needs installation of Julia 1.3 and a clone of GenX repo along with your python installation. 

## Bug and feature requests and contact info
If you would like to report a bug in the code or request a feature, please use our [Issue Tracker](https://github.com/GenXProject/GenX/issues). If you're unsure or have questions on how to use GenX that are not addressed by the above documentation, please reach out to Sambuddha Chakrabarti (sc87@princeton.edu), Jesse Jenkins (jdj2@princeton.edu) or Dharik Mallapragada (dharik@mit.edu).

## GenX Team
GenX has been developed jointly by researchers at the [MIT Energy Initiative](https://energy.mit.edu/) and the ZERO lab at Princeton University. Key contributors include [Nestor A. Sepulveda](https://energy.mit.edu/profile/nestor-sepulveda/), [Jesse D. Jenkins](https://mae.princeton.edu/people/faculty/jenkins),  [Dharik S. Mallapragada](https://energy.mit.edu/profile/dharik-mallapragada/), [Aaron M. Schwartz](https://idss.mit.edu/staff/aaron-schwartz/), [Neha S. Patankar](https://www.linkedin.com/in/nehapatankar), [Qingyu Xu](https://www.linkedin.com/in/qingyu-xu-61b3567b), [Jack Morris](https://www.linkedin.com/in/jack-morris-024b37121), [Sambuddha Chakrabarti](https://www.linkedin.com/in/sambuddha-chakrabarti-ph-d-84157318).
