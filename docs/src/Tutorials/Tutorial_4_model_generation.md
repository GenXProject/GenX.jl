# Tutorial 4: Model Generation

[Jupyter Notebook of the tutorial](https://github.com/GenXProject/GenX-Tutorials/blob/main/Tutorials/Tutorial_4_Model_Generation.ipynb)

To run GenX, we use the file `Run.jl`. This file will solve the optimization problem and generate the output files as described in the documentation and previous tutorial. It does so by first generating the model, then solving the model, both according to settings described in `genx_settings.yml`. However, `Run.jl` only contains one commmand, `run_genx_case!(dirname(@__FILE__))`. This can be confusing for users viewing the files for the first time. In reality, this function signals many more functions to run, generating and solving the model. This tutorial explains how the model in GenX is generated. The next tutorial will then describe how it is solved.

We'll start by explaining JuMP, the optimization package that GenX uses to generate and solve the model.

### Table of Contents
* [JuMP](#JuMP)
* [Generate Model](#GenerateModel)
    * [Arguments](#Arguments)
    * [Run generate_model](#Run)


```@raw html
<img src="./files/jump_logo.png" style="width: 450px; height: auto" >
```

JuMP is a modeling language for Julia. It allows users to create models for optimization problems, define variables and constraints, and apply a variety of solvers for the model. 

GenX is a __Linear Program (LP)__, which is a form of optimization problem in which a linear objective is minimized (or maximized) according to a set of linear constraints. For more information on LPs, see the <a href="https://en.wikipedia.org/wiki/Linear_programming" target="_blank">Wikipedia</a>. 


```julia
using JuMP
using HiGHS
```

Let's say we want to build a power grid consisting of and coal and wind plants. We want to decrease the cost of producing energy while still meeting a certain emissions threshold and full grid demand. Coal plants are cheaper to build and run but have higher emissions than wind farms. To find the minimum cost of a power grid meeting these constraints, we construct an LP using JuMP.

```math
\begin{aligned}
& \min 10 x + 15 y &\text{Objective function (cost)}\\ 
& \text{s.t.} & \\
& x + y \geq 10 &\text{Grid Demand}\\
& 55x + 70y \leq \ 1000 &\text{Construction constraint}\\
& 40 x + 5 y \leq 200 &\text{Emissions constraint} \\
& x, y \geq 0 &\text{Non-negativity constraints}\\
\end{aligned}
```

The core of the JuMP model is the function `Model()`, which creates the structure of our LP. `Model()` takes an optimizer as its input.


```julia
power = Model(HiGHS.Optimizer)
```

    A JuMP Model
    Feasibility problem with:
    Variables: 0
    Model mode: AUTOMATIC
    CachingOptimizer state: EMPTY_OPTIMIZER
    Solver name: HiGHS

The model needs variables, defined using the JuMP function `@variable`:


```julia
@variable(power,x) # Coal
@variable(power,y) # Wind
```


Using the JuMP function `@constraint`, we can add the constraints of the model:


```julia
@constraint(power, non_neg_x, x >= 0) # Non-negativity constraint (can't have negative power plants!)
@constraint(power, non_neg_y, y >= 0) # Non-negativity constraint

@constraint(power, emissions, 40x + 5y <= 200) # Emisisons constraint
@constraint(power, construction_costs, 55x + 70y <= 1000) # Cost of constructing a new plant

@constraint(power, demand, x + y >= 10) # Grid demand
```

`` x + y \geq 10 ``

Next, the function `@expression` defines an expression that can be used in either a constraint or objective function. In GenX, expressions are defined throughout the model generation and put into constraints and the objective function later.


```julia
@expression(power,objective,10x+15y)
```
$ 10 x + 15 y $

Finally, we define the objective function itself:


```julia
@objective(power, Min, objective)
```

`` 10 x + 15 y ``

Our model is now set up! 


```julia
print(power)
```

```math
\begin{aligned}
\min\quad & 10 x + 15 y\\
\text{Subject to} \quad & x \geq 0\\
 & y \geq 0\\
 & x + y \geq 10\\
 & 40 x + 5 y \leq 200\\
 & 55 x + 70 y \leq 1000\\
\end{aligned} 
```


In the next Tutorial, we go over how to use JuMP to solve the model we've constructed.

When `Run.jl` is called, the model for GenX is constructed in a similar way, but with many more factors to consider. The next section goes over how the GenX model is constructed before it is solved.

### Generate Model 

The basic structure of the way `Run.jl` generates and solves the model is as follows:

```@raw html
<img src="./files/LatexHierarchy.png" style="width: 650px; height: auto">
```

The function `run_genx_case(case)` takes the "case" as its input. The case is all of the input files and settings found in the same folder as `Run.jl`. For example, in `SmallNewEngland/OneZone`, the case is:

```@raw html
<img src="./files/OneZoneCase.png" style="width: auto; height: 500px" >
```

`Run_genx_case` defines the __setup__, which are the settings in `genx_settings.yml`. From there, either `run_genx_case_simple(case, mysetup)` or`run_genx_case_multistage(case, mysetup)` is called. Both of these define the __inputs__ and __optimizer__. The optimizer is the solver as specified in `genx_settings.yml`, and the inputs are a variety of parameters specified by the settings and csv files found in the folder. Both of these functions then call `generate_model(mysetup, myinputs, OPTIMIZER)`, which is the main subject of this tutorial.

As in the above example, `generate_model` utilizes the JuMP functions `Model()`, `@expression`, `@variable`, and `@constraints` to form a model. This section goes through `generate_model` and explains how the expressions are formed to create the model.

#### Arguments 

`Generate_model` takes three arguments: setup, inputs, and optimizer:

To generate the arguments, we have to set a case path (this is set automatically when `Run.jl` is called):


```julia
using GenX
```


```julia
case = joinpath("Example_Systems_Tutorials/SmallNewEngland/OneZone") 
```

"Example_Systems_Tutorials/SmallNewEngland/OneZone"

Setup includes the settings from `genx_settings.yml` along with the default settings found in `configure_settings.jl`. The function `configure_settings` combines the two.

```julia
genx_settings = GenX.get_settings_path(case, "genx_settings.yml") # Settings YAML file path
setup = GenX.configure_settings(genx_settings) # Combines genx_settings with defaults not specified in the file
```

    Configuring Settings
    Dict{Any, Any} with 24 entries:
      "NetworkExpansion"                        => 0
      "TimeDomainReductionFolder"               => "TDR_Results"
      "EnableJuMPStringNames"                   => false
      "Trans_Loss_Segments"                     => 1
      "ModelingtoGenerateAlternativeSlack"      => 0.1
      "Solver"                                  => "HiGHS"
      "Reserves"                                => 0
      "MultiStage"                              => 0
      "OverwriteResults"                        => 0
      "ModelingToGenerateAlternatives"          => 0
      "MaxCapReq"                               => 1
      "MinCapReq"                               => 1
      "CO2Cap"                                  => 2
      "WriteShadowPrices"                       => 1
      "ModelingToGenerateAlternativeIterations" => 3
      "ParameterScale"                          => 1
      "EnergyShareRequirement"                  => 1
      "PrintModel"                              => 0
      "TimeDomainReduction"                     => 1
      "CapacityReserveMargin"                   => 1
      "MethodofMorris"                          => 0
      "StorageLosses"                           => 1
      "IncludeLossesInESR"                      => 0
      "UCommit"                                 => 2

It's here that we create the folder `TDR_Results` before generating the model. This occurs if TimeDomainReduction is set to 1 in the setup.


```julia
TDRpath = joinpath(case, setup["TimeDomainReductionFolder"])
settings_path = GenX.get_settings_path(case)

if setup["TimeDomainReduction"] == 1
    GenX.prevent_doubled_timedomainreduction(case)
    if !GenX.time_domain_reduced_files_exist(TDRpath)
        println("Clustering Time Series Data (Grouped)...")
        GenX.cluster_inputs(case, settings_path, setup)
    else
        println("Time Series Data Already Clustered.")
    end
end
```

    Clustering Time Series Data (Grouped)...
    Reading Input CSV Files
    Network.csv Successfully Read!
    Load_data.csv Successfully Read!
    Fuels_data.csv Successfully Read!
    Generators_data.csv Successfully Read!
    Generators_variability.csv Successfully Read!
    Validating time basis
    Capacity_reserve_margin.csv Successfully Read!
    Minimum_capacity_requirement.csv Successfully Read!
    Maximum_capacity_requirement.csv Successfully Read!
    Energy_share_requirement.csv Successfully Read!
    CO2_cap.csv Successfully Read!
    CSV Files Successfully Read In From Example_Systems_Tutorials/SmallNewEngland/OneZone

    Dict{String, Any} with 9 entries:
      "RMSE"          => Dict("Load_MW_z1"=>1100.54, "NG"=>0.312319, "onshore_wind_…
      "OutputDF"      => [1m1848×9 DataFrame[0m[0m…
      "ColToZoneMap"  => Dict("Load_MW_z1"=>1, "battery_z1"=>1, "natural_gas_combin…
      "ClusterObject" => KmeansResult{Matrix{Float64}, Float64, Int64}([-1.38728 -1…
      "TDRsetup"      => Dict{Any, Any}("IterativelyAddPeriods"=>1, "ExtremePeriods…
      "Assignments"   => [1, 1, 1, 1, 2, 2, 2, 2, 2, 3  …  6, 4, 3, 5, 5, 9, 10, 10…
      "InputDF"       => [1m672×49 DataFrame[0m[0m…
      "Weights"       => [673.846, 1010.77, 673.846, 842.308, 842.308, 1853.08, 185…
      "Centers"       => Any[1, 7, 12, 15, 23, 24, 28, 29, 48, 50, 51]



The optimizer argument is taken from setup:


```julia
OPTIMIZER =  GenX.configure_solver(setup["Solver"], settings_path);
```

The function `configure_solver` converts the string from "Solver" to a <a href="https://jump.dev/MathOptInterface.jl/stable/" target="_blank">MathOptInterface</a> optimizer so it can be used in the JuMP model as the optimizer. It also goes into the settings file for the specified solver (in this case HiGHS, so `OneZone/Settings/highs_settings.yml`) and uses the settings to configure the solver to be used later.


```julia
typeof(OPTIMIZER)
```

    MathOptInterface.OptimizerWithAttributes

The "inputs" argument is generated by the function `load_inputs` from the case in `run_genx_case_simple` (or multistage). If TDR is set to 1 in the settings file, then `load_inputs` will draw some of the files from the `TDR_Results` folder. `TDR_Results` is produced when the case is run. 


```julia
inputs = GenX.load_inputs(setup, case)
```

    Reading Input CSV Files
    Network.csv Successfully Read!
    Load_data.csv Successfully Read!
    Fuels_data.csv Successfully Read!
    Generators_data.csv Successfully Read!
    Generators_variability.csv Successfully Read!
    Validating time basis
    Capacity_reserve_margin.csv Successfully Read!
    Minimum_capacity_requirement.csv Successfully Read!
    Maximum_capacity_requirement.csv Successfully Read!
    Energy_share_requirement.csv Successfully Read!
    CO2_cap.csv Successfully Read!
    CSV Files Successfully Read In From Example_Systems_Tutorials/SmallNewEngland/OneZone

    Dict{Any, Any} with 66 entries:
      "Z"                   => 1
      "LOSS_LINES"          => [1]
      "RET_CAP_CHARGE"      => Int64[]
      "pC_D_Curtail"        => [50.0]
      "dfGen"               => [1m4×68 DataFrame[0m[0m…
      "pTrans_Max_Possible" => [2.95]
      "pNet_Map"            => [1.0;;]
      "omega"               => [4.01099, 4.01099, 4.01099, 4.01099, 4.01099, 4.0109…
      "RET_CAP_ENERGY"      => [4]
      "RESOURCES"           => String31["natural_gas_combined_cycle", "solar_pv", "…
      "COMMIT"              => [1]
      "pMax_D_Curtail"      => [1]
      "STOR_ALL"            => [4]
      "THERM_ALL"           => [1]
      "dfCO2CapZones"       => [1;;]
      "REP_PERIOD"          => 11
      "MinCapReq"           => [5.0, 10.0, 6.0]
      "STOR_LONG_DURATION"  => Int64[]
      "dfCapRes"            => [0.156;;]
      "STOR_SYMMETRIC"      => [4]
      "VRE"                 => [2, 3]
      "RETRO"               => Int64[]
      "THERM_COMMIT"        => [1]
      "TRANS_LOSS_SEGS"     => 1
      "H"                   => 168
      ⋮                     => ⋮


Now that we have our arguments, we're ready to generate the model itself.

#### Run generate_model

This subsection replicates the arguments in the function `generate_model`. __Note:__ Running some of these cells for a second time will throw an error as the code will attempt to define a new expression with the name of an existing expression. To run the Tutorial again, clear and restart the kernel.

 First, we initialize a model and define the time step and zone variables


```julia
EP = Model(OPTIMIZER)  # From JuMP
```

    A JuMP Model
    Feasibility problem with:
    Variables: 0
    Model mode: AUTOMATIC
    CachingOptimizer state: EMPTY_OPTIMIZER
    Solver name: HiGHS

```julia
T = inputs["T"];   # Number of time steps (hours)
Z = inputs["Z"];   # Number of zones
```

Next, the dummy variable vZERO, the objective function, the power balance expression, and zone generation expression are all initialized to zero:


```julia
# Introduce dummy variable fixed to zero to ensure that expressions like eTotalCap,
# eTotalCapCharge, eTotalCapEnergy and eAvail_Trans_Cap all have a JuMP variable
@variable(EP, vZERO == 0);

# Initialize Power Balance Expression
# Expression for "baseline" power balance constraint
@expression(EP, ePowerBalance[t=1:T, z=1:Z], 0)

# Initialize Objective Function Expression
@expression(EP, eObj, 0)

# Initialize Total Generation per Zone
@expression(EP, eGenerationByZone[z=1:Z, t=1:T], 0)
```

    1×1848 Matrix{Int64}:
     0  0  0  0  0  0  0  0  0  0  0  0  0  …  0  0  0  0  0  0  0  0  0  0  0  0

Next, we go through some of the settings in setup and, if they've been set to be utilized (i.e. have a nonzero value), define expressions from their corresponding input files:


```julia
if setup["CapacityReserveMargin"] > 0
    @expression(EP, eCapResMarBalance[res=1:inputs["NCapacityReserveMargin"], t=1:T], 0)
end

if setup["EnergyShareRequirement"] >= 1
    @expression(EP, eESR[ESR=1:inputs["nESR"]], 0)
end

if setup["MinCapReq"] == 1
    @expression(EP, eMinCapRes[mincap = 1:inputs["NumberOfMinCapReqs"]], 0)
end

if setup["MaxCapReq"] == 1
    @expression(EP, eMaxCapRes[maxcap = 1:inputs["NumberOfMaxCapReqs"]], 0)
end
```
    3-element Vector{Int64}:
     0
     0
     0


The other settings will be used later on.

Next, we define the model infrastructure using functions found in `src/core`. These take entries from inputs and setup to create more expressions in our model (EP). To see what the functions do in more detail, see the source code and <a href="https://genxproject.github.io/GenX/dev/core/#Discharge" target="_blank">core documentation</a>.


```julia
# Infrastructure
GenX.discharge!(EP, inputs, setup)

GenX.non_served_energy!(EP, inputs, setup)

GenX.investment_discharge!(EP, inputs, setup)

if setup["UCommit"] > 0
    GenX.ucommit!(EP, inputs, setup)
end

GenX.emissions!(EP, inputs)

if setup["Reserves"] > 0
    GenX.reserves!(EP, inputs, setup)
end

if Z > 1
    GenX.transmission!(EP, inputs, setup)
end
```

    Discharge Module
    Non-served Energy Module
    Investment Discharge Module
    Unit Commitment Module
    Emissions Module (for CO2 Policy modularization


We then define variables and expressions based on the resources in the inputs and setup arguments. The details of these can be found in the `src/resources` folder and the "Resources" folder under Model Function Reference in the documentation:


```julia
# Technologies
# Model constraints, variables, expression related to dispatchable renewable resources

if !isempty(inputs["VRE"])
    GenX.curtailable_variable_renewable!(EP, inputs, setup)
end

# Model constraints, variables, expression related to non-dispatchable renewable resources
if !isempty(inputs["MUST_RUN"])
    GenX/must_run!(EP, inputs, setup)
end

# Model constraints, variables, expression related to energy storage modeling
if !isempty(inputs["STOR_ALL"])
    GenX.storage!(EP, inputs, setup)
end

# Model constraints, variables, expression related to reservoir hydropower resources
if !isempty(inputs["HYDRO_RES"])
    GenX.hydro_res!(EP, inputs, setup)
end

# Model constraints, variables, expression related to reservoir hydropower resources with long duration storage
if inputs["REP_PERIOD"] > 1 && !isempty(inputs["STOR_HYDRO_LONG_DURATION"])
    GenX.hydro_inter_period_linkage!(EP, inputs)
end

# Model constraints, variables, expression related to demand flexibility resources
if !isempty(inputs["FLEX"])
    GenX.flexible_demand!(EP, inputs, setup)
end

# Model constraints, variables, expression related to thermal resource technologies
if !isempty(inputs["THERM_ALL"])
    GenX.thermal!(EP, inputs, setup)
end

# Model constraints, variables, expression related to retrofit technologies
if !isempty(inputs["RETRO"])
    EP = GenX.retrofit(EP, inputs)
end

```

Finally, we define expressions and variables using policies outlined in the inputs. These functions can be found in `src/policies` and in the <a href="https://genxproject.github.io/GenX/dev/policies/" target="_blank">policies documentation</a>:


```julia
# Policies
# CO2 emissions limits
#if setup["CO2Cap"] > 0
 #   GenX.co2_cap!(EP, inputs, setup)
#end

# Endogenous Retirements
if setup["MultiStage"] > 0
    GenX.endogenous_retirement!(EP, inputs, setup)
end

# Energy Share Requirement
if setup["EnergyShareRequirement"] >= 1
    GenX.energy_share_requirement!(EP, inputs, setup)
end

#Capacity Reserve Margin
if setup["CapacityReserveMargin"] > 0
    GenX.cap_reserve_margin!(EP, inputs, setup)
end

if (setup["MinCapReq"] == 1)
    GenX.minimum_capacity_requirement!(EP, inputs, setup)
end

if setup["MaxCapReq"] == 1
    GenX.maximum_capacity_requirement!(EP, inputs, setup)
end

```

    Energy Share Requirement Policies Module
    Capacity Reserve Margin Policies Module
    Minimum Capacity Requirement Module
    Maximum Capacity Requirement Module

    3-element Vector{ConstraintRef{Model, MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.LessThan{Float64}}, ScalarShape}}:
     cZoneMaxCapReq[1] : -vRETCAP[2] + vCAP[2] ≤ 50
     cZoneMaxCapReq[2] : -vRETCAP[3] + vCAP[3] ≤ 100
     cZoneMaxCapReq[3] : -vRETCAP[4] + vCAP[4] ≤ 60



The expressions and variables for the model have all been defined! All that's left to do is define the constraints and objective function.

The [Objective Function](@ref) here is to minimize 


```julia
@objective(EP,Min,EP[:eObj])
```

```
0.17159171428571432 vP_{1,1} + 0.0004010989010989012 vP_{3,1} + 0.0006016483516483517 vP_{4,1} + 0.17159171428571432 vP_{1,2} + 0.0004010989010989012 vP_{3,2} + 0.0006016483516483517 vP_{4,2} + 0.17159171428571432 vP_{1,3} + 0.0004010989010989012 vP_{3,3} + 0.0006016483516483517 vP_{4,3} + 0.17159171428571432 vP_{1,4} + 0.0004010989010989012 vP_{3,4} + 0.0006016483516483517 vP_{4,4} + 0.17159171428571432 vP_{1,5} + 0.0004010989010989012 vP_{3,5} + 0.0006016483516483517 vP_{4,5} + 0.17159171428571432 vP_{1,6} + 0.0004010989010989012 vP_{3,6} + 0.0006016483516483517 vP_{4,6} + 0.17159171428571432 vP_{1,7} + 0.0004010989010989012 vP_{3,7} + 0.0006016483516483517 vP_{4,7} + 0.17159171428571432 vP_{1,8} + 0.0004010989010989012 vP_{3,8} + 0.0006016483516483517 vP_{4,8} + 0.17159171428571432 vP_{1,9} + 0.0004010989010989012 vP_{3,9} + 0.0006016483516483517 vP_{4,9} + 0.17159171428571432 vP_{1,10} + 0.0004010989010989012 vP_{3,10} + 0.0006016483516483517 vP_{4,10} + [[\ldots\text{11038 terms omitted}\ldots]] + 0.00015041208791208792 vCHARGE_{4,1819} + 0.00015041208791208792 vCHARGE_{4,1820} + 0.00015041208791208792 vCHARGE_{4,1821} + 0.00015041208791208792 vCHARGE_{4,1822} + 0.00015041208791208792 vCHARGE_{4,1823} + 0.00015041208791208792 vCHARGE_{4,1824} + 0.00015041208791208792 vCHARGE_{4,1825} + 0.00015041208791208792 vCHARGE_{4,1826} + 0.00015041208791208792 vCHARGE_{4,1827} + 0.00015041208791208792 vCHARGE_{4,1828} + 0.00015041208791208792 vCHARGE_{4,1829} + 0.00015041208791208792 vCHARGE_{4,1830} + 0.00015041208791208792 vCHARGE_{4,1831} + 0.00015041208791208792 vCHARGE_{4,1832} + 0.00015041208791208792 vCHARGE_{4,1833} + 0.00015041208791208792 vCHARGE_{4,1834} + 0.00015041208791208792 vCHARGE_{4,1835} + 0.00015041208791208792 vCHARGE_{4,1836} + 0.00015041208791208792 vCHARGE_{4,1837} + 0.00015041208791208792 vCHARGE_{4,1838} + 0.00015041208791208792 vCHARGE_{4,1839} + 0.00015041208791208792 vCHARGE_{4,1840} + 0.00015041208791208792 vCHARGE_{4,1841} + 0.00015041208791208792 vCHARGE_{4,1842} + 0.00015041208791208792 vCHARGE_{4,1843} + 0.00015041208791208792 vCHARGE_{4,1844} + 0.00015041208791208792 vCHARGE_{4,1845} + 0.00015041208791208792 vCHARGE_{4,1846} + 0.00015041208791208792 vCHARGE_{4,1847} + 0.00015041208791208792 vCHARGE_{4,1848} $
```

Our constraint is the [Power Balance](@ref), which is set here to have to meet the demand of the network. The demand is outlined in the last columns of `Load_data.csv`, and is set to inputs in from the `load_load_data` function within `load_inputs`, used in `run_genx_case`.


```julia
## Power balance constraints
# demand = generation + storage discharge - storage charge - demand deferral + deferred demand satisfaction - demand curtailment (NSE)
#          + incoming power flows - outgoing power flows - flow losses - charge of heat storage + generation from NACC
@constraint(EP, cPowerBalance[t=1:T, z=1:Z], EP[:ePowerBalance][t,z] == inputs["pD"][t,z])

```

    1848×1 Matrix{ConstraintRef{Model, MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.EqualTo{Float64}}, ScalarShape}}:
     cPowerBalance[1,1] : vP[2,1] + vP[3,1] + vP[4,1] + vNSE[1,1,1] - vCHARGE[4,1] = 11.162
     cPowerBalance[2,1] : vP[2,2] + vP[3,2] + vP[4,2] + vNSE[1,2,1] - vCHARGE[4,2] = 10.556
     cPowerBalance[3,1] : vP[2,3] + vP[3,3] + vP[4,3] + vNSE[1,3,1] - vCHARGE[4,3] = 10.105
     cPowerBalance[4,1] : vP[2,4] + vP[3,4] + vP[4,4] + vNSE[1,4,1] - vCHARGE[4,4] = 9.878
     cPowerBalance[5,1] : vP[2,5] + vP[3,5] + vP[4,5] + vNSE[1,5,1] - vCHARGE[4,5] = 9.843
     cPowerBalance[6,1] : vP[2,6] + vP[3,6] + vP[4,6] + vNSE[1,6,1] - vCHARGE[4,6] = 10.017
     cPowerBalance[7,1] : vP[2,7] + vP[3,7] + vP[4,7] + vNSE[1,7,1] - vCHARGE[4,7] = 10.39
     cPowerBalance[8,1] : vP[2,8] + vP[3,8] + vP[4,8] + vNSE[1,8,1] - vCHARGE[4,8] = 10.727
     cPowerBalance[9,1] : vP[2,9] + vP[3,9] + vP[4,9] + vNSE[1,9,1] - vCHARGE[4,9] = 11.298
     cPowerBalance[10,1] : vP[2,10] + vP[3,10] + vP[4,10] + vNSE[1,10,1] - vCHARGE[4,10] = 11.859
     cPowerBalance[11,1] : vP[2,11] + vP[3,11] + vP[4,11] + vNSE[1,11,1] - vCHARGE[4,11] = 12.196
     cPowerBalance[12,1] : vP[2,12] + vP[3,12] + vP[4,12] + vNSE[1,12,1] - vCHARGE[4,12] = 12.321
     cPowerBalance[13,1] : vP[2,13] + vP[3,13] + vP[4,13] + vNSE[1,13,1] - vCHARGE[4,13] = 12.381
     ⋮
     cPowerBalance[1837,1] : vP[2,1837] + vP[3,1837] + vP[4,1837] + vNSE[1,1837,1] - vCHARGE[4,1837] = 13.911
     cPowerBalance[1838,1] : vP[2,1838] + vP[3,1838] + vP[4,1838] + vNSE[1,1838,1] - vCHARGE[4,1838] = 13.818
     cPowerBalance[1839,1] : vP[2,1839] + vP[3,1839] + vP[4,1839] + vNSE[1,1839,1] - vCHARGE[4,1839] = 13.71
     cPowerBalance[1840,1] : vP[2,1840] + vP[3,1840] + vP[4,1840] + vNSE[1,1840,1] - vCHARGE[4,1840] = 13.796
     cPowerBalance[1841,1] : vP[2,1841] + vP[3,1841] + vP[4,1841] + vNSE[1,1841,1] - vCHARGE[4,1841] = 15.038
     cPowerBalance[1842,1] : vP[2,1842] + vP[3,1842] + vP[4,1842] + vNSE[1,1842,1] - vCHARGE[4,1842] = 16.088
     cPowerBalance[1843,1] : vP[2,1843] + vP[3,1843] + vP[4,1843] + vNSE[1,1843,1] - vCHARGE[4,1843] = 16.076
     cPowerBalance[1844,1] : vP[2,1844] + vP[3,1844] + vP[4,1844] + vNSE[1,1844,1] - vCHARGE[4,1844] = 15.782
     cPowerBalance[1845,1] : vP[2,1845] + vP[3,1845] + vP[4,1845] + vNSE[1,1845,1] - vCHARGE[4,1845] = 15.392
     cPowerBalance[1846,1] : vP[2,1846] + vP[3,1846] + vP[4,1846] + vNSE[1,1846,1] - vCHARGE[4,1846] = 14.663
     cPowerBalance[1847,1] : vP[2,1847] + vP[3,1847] + vP[4,1847] + vNSE[1,1847,1] - vCHARGE[4,1847] = 13.62
     cPowerBalance[1848,1] : vP[2,1848] + vP[3,1848] + vP[4,1848] + vNSE[1,1848,1] - vCHARGE[4,1848] = 12.388



After this final constraint is defined, `generate_model` finishes compiling the EP, and `run_genx_simple` (or multistage) uses `solve_model` to solve the EP. This will be described in Tutorial 5.
