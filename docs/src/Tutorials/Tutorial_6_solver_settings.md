# Tutorial 6: Solver Settings

Though solving the model relies on the JuMP function `optimize`, there are a number of ways to change the way in which the model is optimized. This tutorial goes over solver parameters and how they affect the model solution. For more information on configuring the solver, see <a href="https://genxproject.github.io/GenX.jl/dev/User_Guide/solver_configuration/" target="_blank">here</a> in the GenX documentation.

## Table of Contents
* [The HiGHs Solver](#HiGHs)
* [Feasibility Tolerance](#Feasibility)
* [PreSolve](#PreSolve)
* [Crossover](#Crossover)


```julia
using YAML
using GenX
using JuMP
using HiGHS
using DataFrames
using Plots
using Plotly
```

    [36m[1m[ [22m[39m[36m[1mInfo: [22m[39mPrecompiling Plotly [58dd65bb-95f3-509e-9936-c39a10fdeae7]



<div style="padding: 1em; background-color: #f8d6da; border: 1px solid #f5c6cb; font-weight: bold;">
<p>The WebIO Jupyter extension was not detected. See the
<a href="https://juliagizmos.github.io/WebIO.jl/latest/providers/ijulia/" target="_blank">
    WebIO Jupyter integration documentation
</a>
for more information.
</div>




```julia
case = joinpath("example_systems/1_three_zones") 

genx_settings = GenX.get_settings_path(case, "genx_settings.yml");
writeoutput_settings = GenX.get_settings_path(case, "output_settings.yml")
setup = GenX.configure_settings(genx_settings,writeoutput_settings) 
settings_path = GenX.get_settings_path(case)
```

    Configuring Settings





    "example_systems/1_three_zones/settings"




```julia
### Create TDR_Results
if "TDR_results" in cd(readdir,case)
    rm(joinpath(case,"TDR_results"), recursive=true) 
end

TDRpath = joinpath(case, setup["TimeDomainReductionFolder"])
system_path = joinpath(case, setup["SystemFolder"])

if setup["TimeDomainReduction"] == 1
    GenX.prevent_doubled_timedomainreduction(system_path)
    if !GenX.time_domain_reduced_files_exist(TDRpath)
        println("Clustering Time Series Data (Grouped)...")
        GenX.cluster_inputs(case, settings_path, setup)
    else
        println("Time Series Data Already Clustered.")
    end
end

inputs = GenX.load_inputs(setup, case)
```

    Reading Input CSV Files
    Network.csv Successfully Read!
    Demand (load) data Successfully Read!
    Fuels_data.csv Successfully Read!


    [36m[1m[ [22m[39m[36m[1mInfo: [22m[39mThermal.csv Successfully Read.
    [36m[1m[ [22m[39m[36m[1mInfo: [22m[39mVre.csv Successfully Read.
    [36m[1m[ [22m[39m[36m[1mInfo: [22m[39mStorage.csv Successfully Read.
    [36m[1m[ [22m[39m[36m[1mInfo: [22m[39mResource_energy_share_requirement.csv Successfully Read.
    [36m[1m[ [22m[39m[36m[1mInfo: [22m[39mResource_capacity_reserve_margin.csv Successfully Read.
    [36m[1m[ [22m[39m[36m[1mInfo: [22m[39mResource_minimum_capacity_requirement.csv Successfully Read.


    
    Summary of resources loaded into the model:
    -------------------------------------------------------
    	Resource type 		Number of resources
    =======================================================
    	Thermal        		3
    	VRE            		4
    	Storage        		3
    =======================================================
    Total number of resources: 10
    -------------------------------------------------------
    Generators_variability.csv Successfully Read!
    Validating time basis
    Minimum_capacity_requirement.csv Successfully Read!
    CO2_cap.csv Successfully Read!
    CSV Files Successfully Read In From example_systems/1_three_zones





    Dict{Any, Any} with 73 entries:
      "Z"                         => 3
      "LOSS_LINES"                => [1, 2]
      "STOR_HYDRO_SHORT_DURATION" => Int64[]
      "RET_CAP_CHARGE"            => Set{Int64}()
      "pC_D_Curtail"              => [50.0, 45.0, 27.5, 10.0]
      "pTrans_Max_Possible"       => [5.9, 4.0]
      "pNet_Map"                  => [1.0 -1.0 0.0; 1.0 0.0 -1.0]
      "omega"                     => [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, …
      "pMax_Line_Reinforcement"   => [2.95, 2.0]
      "RET_CAP_ENERGY"            => Int64[]
      "RESOURCES"                 => AbstractResource[…
      "COMMIT"                    => [1, 2, 3]
      "pMax_D_Curtail"            => [1.0, 0.04, 0.024, 0.003]
      "STOR_ALL"                  => [8, 9, 10]
      "THERM_ALL"                 => [1, 2, 3]
      "dfCO2CapZones"             => [1 0 0; 0 1 0; 0 0 1]
      "REP_PERIOD"                => 1
      "MinCapReq"                 => [5.0, 10.0, 6.0]
      "PWFU_Num_Segments"         => 0
      "STOR_LONG_DURATION"        => Int64[]
      "THERM_COMMIT_PWFU"         => Int64[]
      "STOR_SYMMETRIC"            => [8, 9, 10]
      "VRE"                       => [4, 5, 6, 7]
      "RETRO"                     => Int64[]
      "THERM_COMMIT"              => [1, 2, 3]
      ⋮                           => ⋮



### The HiGHS Solver

In the example files, the solver <a href="https://highs.dev" target="_blank">HiGHS</a>. HiGHS is freely available for all to use. Other solvers, such as  <a href="https://www.gurobi.com" target="_blank">Gurobi</a>, are available for free for academics, and some <a href="https://genxproject.github.io/GenX.jl/dev/Getting_Started/commercial_solvers/" target="_blank">commercial solvers </a> such as CPLEX are also available. For the purpose of this tutorial, we will be focusing on HiGHS. 

To set the solver preferences, go into the settings folder of your case and select the YAML file of the solver you're using.




```julia
settings_folder = cd(readdir,joinpath(case,"settings")) # Print Settings folder
```




    7-element Vector{String}:
     ".DS_Store"
     "clp_settings.yml"
     "cplex_settings.yml"
     "genx_settings.yml"
     "gurobi_settings.yml"
     "highs_settings.yml"
     "time_domain_reduction_settings.yml"




```julia
highs_settings = YAML.load(open(joinpath(case,"settings/highs_settings.yml")))
```




    Dict{Any, Any} with 6 entries:
      "Method"        => "ipm"
      "Feasib_Tol"    => 1.0e-5
      "run_crossover" => "on"
      "TimeLimit"     => 1.0e23
      "Optimal_Tol"   => 1.0e-5
      "Pre_Solve"     => "choose"



The function <a href="https://genxproject.github.io/GenX/dev/solver_configuration/#Configuring-HiGHS" target="_blank">`configure_highs`</a> in `src/configure_solver` contains a list of default settings for the HiGHS solver



<img src="./files/highs_defaults.png" style="width: auto; height: 500px" align="left">



There are about 80, so we'll only focus on a few for now. In most cases, you can leave the other settings on default. 

The default settings are combined with the settings you specify in `highs_settings.yml` in `configure_highs`, which is called from `configure_solver` in `run_genx_case_simple` right before the model is generated.



### Feasibility Tolerance <a id="Feasibility"></a>

The parameters `Feasib_Tol` and `Optimal_Tol` represent the feasibility of the primal and dual functions respectively. Without going into too much detail, a  <a href="https://en.wikipedia.org/wiki/Duality_(optimization)" target="_blank">__dual function__</a> is an analagous formulation of the original ("primal") function whose objective value acts as a lower bound to the primal function. The objective value of the primal function is then the upper bound of the dual function. HiGHS will solve the dual and primal at each time step, then terminate when the solutions of the two are within a certain tolerance range. For more information on how this works specifically in HiGHS, see the  <a href="https://ergo-code.github.io/HiGHS/dev/terminology/" target="_blank">HiGHS documentaion</a>. 

If we decrease the tolerance parameters, the objective value becomes closer to the "true" optimal value. Note: The following cell will take a few minutes to run.




```julia
# Change tolerance, generate and solve model`
tols = [1e-7,1e-4,1e-2,1e-1]
OV = zeros(1,4)

for i in range(1,length(tols))
    println(" ")
    println("----------------------------------------------------")
    println("Iteration ",i)
    println("Tolerance = ",tols[i])
    println("----------------------------------------------------")
    highs_settings["Feasib_Tol"] = tols[i]
    highs_settings["Optimal_Tol"] = tols[i]
    YAML.write_file(joinpath(case,"settings/highs_settings.yml"), highs_settings)
    OPTIMIZER1 = GenX.configure_solver(settings_path,HiGHS.Optimizer)
    EP = GenX.generate_model(setup,inputs,OPTIMIZER1)
    GenX.solve_model(EP,setup)
    OV[i] = objective_value(EP)
end


```

     
    ----------------------------------------------------
    Iteration 1
    Tolerance = 1.0e-7
    ----------------------------------------------------
    Discharge Module
    Non-served Energy Module
    Investment Discharge Module
    Unit Commitment Module
    Fuel Module
    CO2 Module
    Investment Transmission Module
    Transmission Module
    Dispatchable Resources Module
    Storage Resources Module
    Storage Investment Module
    Storage Core Resources Module
    Storage Resources with Symmetric Charge/Discharge Capacity Module
    Thermal (Unit Commitment) Resources Module
    CO2 Policies Module
    Minimum Capacity Requirement Module
    Running HiGHS 1.6.0: Copyright (c) 2023 HiGHS under MIT licence terms
    Presolving model
    560114 rows, 384919 cols, 2214687 nonzeros
    526027 rows, 350832 cols, 2217597 nonzeros
    Presolve : Reductions: rows 526027(-201067); columns 350832(-218587); elements 2217597(-225929)
    Solving the presolved LP
    IPX model has 526027 rows, 350832 columns and 2217597 nonzeros
    Input
        Number of variables:                                350832
        Number of free variables:                           17520
        Number of constraints:                              526027
        Number of equality constraints:                     79793
        Number of matrix entries:                           2217597
        Matrix range:                                       [4e-07, 1e+01]
        RHS range:                                          [7e-01, 4e+03]
        Objective range:                                    [1e-04, 1e+02]
        Bounds range:                                       [2e-03, 2e+01]
    Preprocessing
        Dualized model:                                     no
        Number of dense columns:                            15
        Range of scaling factors:                           [5.00e-01, 8.00e+00]
    IPX version 1.0
    Interior Point Solve
     Iter     P.res    D.res            P.obj           D.obj        mu     Time
       0   8.11e+02 4.65e+01   2.48759248e+06 -1.16216867e+06  3.71e+04       1s
       1   5.42e+02 1.59e+01  -2.51664442e+08 -4.88235776e+06  2.32e+04       4s
       2   5.05e+02 1.16e+01  -2.54402441e+08 -1.71582474e+07  2.49e+04       8s
       3   1.93e+02 4.97e+00  -1.40306689e+08 -1.94745370e+07  1.00e+04      15s
     Constructing starting basis...
     11441 fixed variables remaining
     11024 fixed variables remaining
     10658 fixed variables remaining
     10190 fixed variables remaining
     9870 fixed variables remaining
     9386 fixed variables remaining
     9054 fixed variables remaining
     8555 fixed variables remaining
     8162 fixed variables remaining
     7657 fixed variables remaining
     7132 fixed variables remaining
     6015 fixed variables remaining
     4415 fixed variables remaining
     2458 fixed variables remaining
     188 fixed variables remaining
       4   1.36e+02 2.63e+00  -9.91313916e+07 -2.08192662e+07  6.44e+03     225s
       5   1.28e+02 2.51e+00  -9.55594133e+07 -2.13479845e+07  6.31e+03     273s
       6   3.73e+01 1.37e+00  -4.97640122e+06 -2.10230284e+07  2.58e+03     313s
       7   5.39e+00 3.92e-01   6.22302513e+06 -2.00936638e+07  6.50e+02     358s
       8   4.99e-01 1.26e-01   7.24805156e+06 -1.53496992e+07  2.00e+02     385s
       9   2.88e-01 9.32e-02   7.57184846e+06 -1.53420160e+07  1.72e+02     412s
      10   1.63e-01 6.63e-02   7.73553146e+06 -1.46046840e+07  1.41e+02     436s
      11   9.52e-02 5.23e-02   7.80383229e+06 -1.38263298e+07  1.23e+02     460s
      12   5.21e-02 4.00e-02   7.64086129e+06 -1.25528286e+07  1.02e+02     484s
      13   2.95e-02 2.85e-02   7.46644720e+06 -1.11290279e+07  8.01e+01     508s
      14   1.60e-02 2.12e-02   7.17421828e+06 -9.91514082e+06  6.46e+01     540s
      15   8.02e-03 1.44e-02   6.69903541e+06 -8.33798469e+06  4.78e+01     577s
      16   3.95e-03 1.01e-02   5.96540068e+06 -6.89650069e+06  3.53e+01     612s
      17   1.56e-03 7.03e-03   5.11283407e+06 -5.71119333e+06  2.58e+01     714s
      18   7.23e-04 4.96e-03   4.03231618e+06 -4.45112785e+06  1.79e+01     751s
      19   2.30e-04 2.69e-03   2.68751504e+06 -2.77243754e+06  9.63e+00     771s
      20   1.43e-04 1.04e-03   2.00999235e+06 -1.19092619e+06  4.70e+00     792s
      21   7.63e-05 6.53e-04   1.32009176e+06 -8.17697954e+05  2.89e+00     818s
      22   1.08e-05 5.12e-05   2.91371295e+05 -6.76605581e+04  4.17e-01     838s
      23   3.52e-06 1.06e-05   1.06979104e+05 -2.11866029e+04  1.46e-01     858s
      24   1.95e-06 4.28e-06   7.71181023e+04 -1.56836561e+04  1.05e-01     877s
      25   7.98e-07 2.64e-06   4.74559754e+04 -1.11193285e+04  6.63e-02     906s
      26   6.34e-07 1.76e-06   4.27324490e+04 -8.13243109e+03  5.75e-02     937s
      27   3.97e-07 1.00e-06   3.36237195e+04 -3.98285468e+03  4.25e-02     962s
      28   3.18e-07 8.09e-07   3.14871994e+04 -3.35409326e+03  3.94e-02    1003s
      29   1.98e-07 4.79e-07   2.48797002e+04 -1.32205441e+02  2.83e-02    1032s
      30   1.46e-07 3.00e-07   2.25309853e+04  1.36809877e+03  2.39e-02    1100s
      31   9.82e-08 1.94e-07   1.95360763e+04  2.89697881e+03  1.88e-02    1150s
      32   8.95e-08 1.53e-07   1.89781388e+04  3.55801812e+03  1.74e-02    1223s
      33   8.57e-08 1.12e-07   1.86969812e+04  4.31723205e+03  1.63e-02    1247s
      34   6.47e-08 8.10e-08   1.68679518e+04  5.15239075e+03  1.32e-02    1267s
      35   5.48e-08 5.59e-08   1.61203420e+04  5.68572363e+03  1.18e-02    1313s
      36   4.64e-08 4.50e-08   1.53923146e+04  6.03038864e+03  1.06e-02    1348s
      37   2.87e-08 2.75e-08   1.40346823e+04  6.47210117e+03  8.55e-03    1411s
      38   2.23e-08 2.29e-08   1.33444423e+04  6.72601072e+03  7.48e-03    1520s
      39   2.00e-08 1.64e-08   1.30985294e+04  7.07611497e+03  6.81e-03    1583s
      40   1.73e-08 1.31e-08   1.27680335e+04  7.31625978e+03  6.16e-03    1623s
      41   1.44e-08 9.87e-09   1.24139017e+04  7.55726763e+03  5.49e-03    1660s
      42   1.22e-08 7.24e-09   1.21911414e+04  7.71398971e+03  5.06e-03    1695s
      43   1.14e-08 6.68e-09   1.20971954e+04  7.76091415e+03  4.90e-03    1735s
      44   7.61e-09 4.49e-09   1.15802896e+04  8.02091818e+03  4.02e-03    1765s
      45   5.27e-09 3.38e-09   1.12119638e+04  8.21659598e+03  3.39e-03    1810s
      46   4.74e-09 3.23e-09   1.11391059e+04  8.24174635e+03  3.28e-03    1859s
      47   4.57e-09 2.64e-09   1.11126636e+04  8.35498106e+03  3.12e-03    1897s
      48   3.76e-09 2.41e-09   1.09666979e+04  8.40725506e+03  2.89e-03    1931s
      49   2.34e-09 1.81e-09   1.06106911e+04  8.63154248e+03  2.24e-03    1962s
      50   2.09e-09 1.74e-09   1.05818880e+04  8.64755500e+03  2.19e-03    2012s
      51   2.01e-09 1.61e-09   1.05763705e+04  8.66683728e+03  2.16e-03    2039s
      52   1.98e-09 1.43e-09   1.05718769e+04  8.70725614e+03  2.11e-03    2056s
      53   1.78e-09 1.37e-09   1.05371910e+04  8.72487885e+03  2.05e-03    2074s
      54   1.58e-09 1.22e-09   1.04901182e+04  8.78376413e+03  1.93e-03    2093s
      55   1.51e-09 1.12e-09   1.04796139e+04  8.80961634e+03  1.89e-03    2110s
      56   1.42e-09 1.03e-09   1.04604194e+04  8.84331799e+03  1.83e-03    2126s
      57   1.19e-09 8.09e-10   1.04335000e+04  8.87893751e+03  1.76e-03    2142s
      58   9.48e-10 6.78e-10   1.03684264e+04  8.94121266e+03  1.61e-03    2160s
      59   8.16e-10 5.54e-10   1.03285920e+04  9.00754251e+03  1.49e-03    2181s
      60   6.39e-10 4.80e-10   1.02716250e+04  9.05052250e+03  1.38e-03    2212s
      61   5.54e-10 3.83e-10   1.02289724e+04  9.09735100e+03  1.28e-03    2244s
      62   5.40e-10 3.47e-10   1.02096462e+04  9.12421353e+03  1.23e-03    2264s
      63   2.37e-10 2.59e-10   1.00971029e+04  9.20224535e+03  1.01e-03    2288s
      64   1.93e-10 2.33e-10   1.00846196e+04  9.22793342e+03  9.68e-04    2316s
      65   1.90e-10 2.05e-10   1.00826696e+04  9.25511076e+03  9.35e-04    2343s
      66   1.83e-10 1.81e-10   1.00786235e+04  9.27896087e+03  9.04e-04    2363s
      67   1.57e-10 1.58e-10   1.00607359e+04  9.30390225e+03  8.56e-04    2385s
      68   4.06e-10 1.23e-10   1.00251777e+04  9.34791627e+03  7.66e-04    2400s
      69   1.17e-10 9.54e-11   9.99610267e+03  9.40054524e+03  6.73e-04    2421s
      70   7.30e-10 8.68e-11   9.98340190e+03  9.40994716e+03  6.48e-04    2447s
      71   8.52e-11 6.73e-11   9.95720979e+03  9.46627820e+03  5.55e-04    2466s
      72   3.59e-10 6.43e-11   9.95146868e+03  9.46816641e+03  5.46e-04    2480s
      73   7.57e-11 4.52e-11   9.92633439e+03  9.52290479e+03  4.56e-04    2492s
      74   2.00e-10 4.05e-11   9.91599082e+03  9.52951028e+03  4.37e-04    2505s
      75   4.37e-10 3.00e-11   9.88217144e+03  9.55862813e+03  3.66e-04    2520s
      76   1.85e-10 2.55e-11   9.87746680e+03  9.57366363e+03  3.43e-04    2540s
      77   2.19e-10 2.31e-11   9.87505143e+03  9.57774339e+03  3.36e-04    2558s
      78   7.56e-11 1.90e-11   9.85388345e+03  9.60110155e+03  2.86e-04    2577s
      79   5.69e-10 1.34e-11   9.84712905e+03  9.62675868e+03  2.49e-04    2595s
      80   2.74e-10 8.61e-12   9.83650621e+03  9.64762624e+03  2.14e-04    2619s
      81   2.94e-10 8.44e-12   9.83026104e+03  9.65130133e+03  2.02e-04    2640s
      82   2.57e-10 5.54e-12   9.81311564e+03  9.67265891e+03  1.59e-04    2650s
      83   4.18e-10 5.31e-12   9.81102650e+03  9.67489246e+03  1.54e-04    2663s
      84   4.73e-10 4.12e-12   9.79593420e+03  9.68638952e+03  1.24e-04    2672s
      85   1.77e-10 3.03e-12   9.79405908e+03  9.69475900e+03  1.12e-04    2685s
      86   2.23e-10 2.27e-12   9.78800260e+03  9.71201800e+03  8.59e-05    2696s
      87   4.96e-10 1.66e-12   9.78778377e+03  9.71487741e+03  8.24e-05    2706s
      88   1.08e-10 1.85e-12   9.78398158e+03  9.71901673e+03  7.34e-05    2715s
      89   5.02e-10 1.10e-12   9.78337445e+03  9.72375826e+03  6.74e-05    2726s
      90   1.27e-10 1.17e-12   9.77736326e+03  9.73354552e+03  4.95e-05    2734s
      91   9.00e-11 9.38e-13   9.77512191e+03  9.73752658e+03  4.25e-05    2748s
      92   6.31e-11 4.26e-13   9.77103532e+03  9.74405874e+03  3.05e-05    2759s
      93   2.05e-09 5.90e-13   9.76961724e+03  9.74735298e+03  2.52e-05    2771s
      94   4.21e-09 8.81e-13   9.76788907e+03  9.75109834e+03  1.90e-05    2781s
      95   1.62e-09 1.19e-12   9.76716151e+03  9.75395650e+03  1.49e-05    2792s
      96   2.72e-09 6.82e-13   9.76603492e+03  9.75527391e+03  1.22e-05    2802s
      97   2.04e-09 5.40e-13   9.76535302e+03  9.75722758e+03  9.18e-06    2810s
      98   5.17e-09 3.69e-13   9.76470022e+03  9.75753839e+03  8.10e-06    2819s
      99   5.46e-10 1.73e-12   9.76412209e+03  9.75921450e+03  5.55e-06    2826s
     100   4.66e-09 4.55e-13   9.76376806e+03  9.75947960e+03  4.85e-06    2834s
     101   8.68e-10 6.82e-13   9.76348975e+03  9.76028015e+03  3.63e-06    2841s
     102   6.87e-09 4.83e-13   9.76322229e+03  9.76103329e+03  2.47e-06    2848s
     103   1.80e-09 4.83e-13   9.76304417e+03  9.76115161e+03  2.14e-06    2856s
     104   7.78e-09 5.40e-13   9.76301308e+03  9.76126585e+03  1.98e-06    2864s
     105   1.70e-08 7.39e-13   9.76274488e+03  9.76155953e+03  1.34e-06    2872s
     106   1.52e-09 6.25e-13   9.76271595e+03  9.76166866e+03  1.18e-06    2881s
     107   1.80e-09 4.55e-13   9.76262785e+03  9.76198378e+03  7.28e-07    2889s
     108   4.26e-09 8.81e-13   9.76259558e+03  9.76205747e+03  6.08e-07    2899s
     109   2.80e-09 9.95e-13   9.76255188e+03  9.76219281e+03  4.06e-07    2907s
     110   1.43e-09 1.19e-12   9.76251174e+03  9.76234638e+03  1.87e-07    2916s
     111   1.53e-08 1.81e-12   9.76247806e+03  9.76239595e+03  9.28e-08    2928s
     112   3.58e-09 3.19e-12   9.76246937e+03  9.76239982e+03  7.86e-08    2940s
     113   2.67e-08 1.75e-12   9.76246448e+03  9.76240389e+03  6.85e-08    2947s
     114   3.74e-09 7.34e-12   9.76244989e+03  9.76241737e+03  3.68e-08    2955s
     115   2.49e-08 3.42e-12   9.76244709e+03  9.76242530e+03  2.46e-08    2963s
     116   1.43e-08 1.02e-11   9.76244319e+03  9.76242949e+03  1.55e-08    2971s
     117   2.21e-08 1.61e-11   9.76244276e+03  9.76242971e+03  1.48e-08    2979s
     118   4.86e-08 1.00e-11   9.76243856e+03  9.76243103e+03  8.51e-09    2986s
     119   4.37e-09 1.38e-11   9.76243759e+03  9.76243267e+03  5.55e-09    2993s
     120   5.22e-08 3.55e-11   9.76243681e+03  9.76243503e+03  2.01e-09    3001s
     121   3.88e-08 3.24e-12   9.76243664e+03  9.76243621e+03  4.84e-10    3010s
     122   5.24e-09 3.08e-11   9.76243661e+03  9.76243649e+03  1.38e-10    3037s
     123*  1.87e-09 2.14e-11   9.76243659e+03  9.76243656e+03  3.42e-11    3076s
     124*  9.49e-09 3.20e-11   9.76243659e+03  9.76243659e+03  4.77e-12    3090s
     125*  4.15e-09 2.95e-11   9.76243659e+03  9.76243659e+03  6.91e-13    3099s
    Running crossover as requested
        Primal residual before push phase:                  3.73e-06
        Dual residual before push phase:                    4.36e-07
        Number of dual pushes required:                     119652
        97225 dual pushes remaining (    320 pivots)
        Number of primal pushes required:                   17699
        16474 primal pushes remaining (    100 pivots)
        15092 primal pushes remaining (    532 pivots)
        13584 primal pushes remaining (   1102 pivots)
        12247 primal pushes remaining (   1483 pivots)
        11093 primal pushes remaining (   1957 pivots)
         9838 primal pushes remaining (   2384 pivots)
         8773 primal pushes remaining (   2657 pivots)
         7599 primal pushes remaining (   2905 pivots)
         6163 primal pushes remaining (   3439 pivots)
         4924 primal pushes remaining (   4120 pivots)
         3778 primal pushes remaining (   4563 pivots)
         2554 primal pushes remaining (   5185 pivots)
         1345 primal pushes remaining (   5816 pivots)
           87 primal pushes remaining (   6504 pivots)
    Summary
        Runtime:                                            3177.04s
        Status interior point solve:                        optimal
        Status crossover:                                   optimal
        objective value:                                    9.76243659e+03
        interior solution primal residual (abs/rel):        2.27e-08 / 5.51e-12
        interior solution dual residual (abs/rel):          2.88e-09 / 2.04e-11
        interior solution objective gap (abs/rel):          6.44e-07 / 6.60e-11
        basic solution primal infeasibility:                1.04e-11
        basic solution dual infeasibility:                  2.02e-15
    Ipx: IPM       optimal
    Ipx: Crossover optimal
    Solving the original LP from the solution after postsolve
    Model   status      : Optimal
    IPM       iterations: 125
    Crossover iterations: 14577
    Objective value     :  9.7624365896e+03
    HiGHS run time      :       3179.83
    LP solved for primal
     
    ----------------------------------------------------
    Iteration 2
    Tolerance = 0.0001
    ----------------------------------------------------
    Discharge Module
    Non-served Energy Module
    Investment Discharge Module
    Unit Commitment Module
    Fuel Module
    CO2 Module
    Investment Transmission Module
    Transmission Module
    Dispatchable Resources Module
    Storage Resources Module
    Storage Investment Module
    Storage Core Resources Module
    Storage Resources with Symmetric Charge/Discharge Capacity Module
    Thermal (Unit Commitment) Resources Module
    CO2 Policies Module
    Minimum Capacity Requirement Module
    Running HiGHS 1.6.0: Copyright (c) 2023 HiGHS under MIT licence terms
    Presolving model
    560114 rows, 384919 cols, 2214687 nonzeros
    526027 rows, 350832 cols, 2217597 nonzeros
    Presolve : Reductions: rows 526027(-201067); columns 350832(-218587); elements 2217597(-225929)
    Solving the presolved LP
    IPX model has 526027 rows, 350832 columns and 2217597 nonzeros
    Input
        Number of variables:                                350832
        Number of free variables:                           17520
        Number of constraints:                              526027
        Number of equality constraints:                     79793
        Number of matrix entries:                           2217597
        Matrix range:                                       [4e-07, 1e+01]
        RHS range:                                          [7e-01, 4e+03]
        Objective range:                                    [1e-04, 1e+02]
        Bounds range:                                       [2e-03, 2e+01]
    Preprocessing
        Dualized model:                                     no
        Number of dense columns:                            15
        Range of scaling factors:                           [5.00e-01, 8.00e+00]
    IPX version 1.0
    Interior Point Solve
     Iter     P.res    D.res            P.obj           D.obj        mu     Time
       0   8.11e+02 4.65e+01   2.48759248e+06 -1.16216867e+06  3.71e+04       0s
       1   5.42e+02 1.59e+01  -2.51664442e+08 -4.88235776e+06  2.32e+04       2s
       2   5.05e+02 1.16e+01  -2.54402441e+08 -1.71582474e+07  2.49e+04       4s
       3   1.93e+02 4.97e+00  -1.40306689e+08 -1.94745370e+07  1.00e+04       7s
     Constructing starting basis...
     11424 fixed variables remaining
     10707 fixed variables remaining
     10125 fixed variables remaining
     9543 fixed variables remaining
     8957 fixed variables remaining
     8367 fixed variables remaining
     7657 fixed variables remaining
     6854 fixed variables remaining
     4942 fixed variables remaining
     2883 fixed variables remaining
     521 fixed variables remaining
       4   1.36e+02 2.63e+00  -9.91313916e+07 -2.08192662e+07  6.44e+03     150s
       5   1.28e+02 2.51e+00  -9.55594133e+07 -2.13479845e+07  6.31e+03     177s
       6   3.73e+01 1.37e+00  -4.97640122e+06 -2.10230284e+07  2.58e+03     204s
       7   5.39e+00 3.92e-01   6.22302513e+06 -2.00936638e+07  6.50e+02     228s
       8   4.99e-01 1.26e-01   7.24805156e+06 -1.53496992e+07  2.00e+02     254s
       9   2.88e-01 9.32e-02   7.57184846e+06 -1.53420160e+07  1.72e+02     281s
      10   1.63e-01 6.63e-02   7.73553146e+06 -1.46046840e+07  1.41e+02     304s
      11   9.52e-02 5.23e-02   7.80383229e+06 -1.38263298e+07  1.23e+02     327s
      12   5.21e-02 4.00e-02   7.64086129e+06 -1.25528286e+07  1.02e+02     349s
      13   2.95e-02 2.85e-02   7.46644720e+06 -1.11290279e+07  8.01e+01     372s
      14   1.60e-02 2.12e-02   7.17421828e+06 -9.91514082e+06  6.46e+01     391s
      15   8.02e-03 1.44e-02   6.69903541e+06 -8.33798469e+06  4.78e+01     414s
      16   3.95e-03 1.01e-02   5.96540068e+06 -6.89650069e+06  3.53e+01     444s
      17   1.56e-03 7.03e-03   5.11283407e+06 -5.71119333e+06  2.58e+01     504s
      18   7.23e-04 4.96e-03   4.03231618e+06 -4.45112785e+06  1.79e+01     531s
      19   2.30e-04 2.69e-03   2.68751504e+06 -2.77243754e+06  9.63e+00     552s
      20   1.43e-04 1.04e-03   2.00999235e+06 -1.19092619e+06  4.70e+00     572s
      21   7.63e-05 6.53e-04   1.32009176e+06 -8.17697954e+05  2.89e+00     596s
      22   1.08e-05 5.12e-05   2.91371295e+05 -6.76605581e+04  4.17e-01     616s
      23   3.52e-06 1.06e-05   1.06979104e+05 -2.11866029e+04  1.46e-01     635s
      24   1.95e-06 4.28e-06   7.71181023e+04 -1.56836561e+04  1.05e-01     654s
      25   7.98e-07 2.64e-06   4.74559754e+04 -1.11193285e+04  6.63e-02     718s
      26   6.34e-07 1.76e-06   4.27324490e+04 -8.13243109e+03  5.75e-02     737s
      27   3.97e-07 1.00e-06   3.36237195e+04 -3.98285468e+03  4.25e-02     759s
      28   3.18e-07 8.09e-07   3.14871994e+04 -3.35409326e+03  3.94e-02     792s
      29   1.98e-07 4.79e-07   2.48797002e+04 -1.32205441e+02  2.83e-02     814s
      30   1.46e-07 3.00e-07   2.25309853e+04  1.36809877e+03  2.39e-02     856s
      31   9.82e-08 1.94e-07   1.95360763e+04  2.89697881e+03  1.88e-02     883s
      32   8.95e-08 1.53e-07   1.89781388e+04  3.55801812e+03  1.74e-02     951s
      33   8.57e-08 1.12e-07   1.86969812e+04  4.31723205e+03  1.63e-02     975s
      34   6.47e-08 8.10e-08   1.68679518e+04  5.15239075e+03  1.32e-02     995s
      35   5.48e-08 5.59e-08   1.61203420e+04  5.68572363e+03  1.18e-02    1041s
      36   4.64e-08 4.50e-08   1.53923146e+04  6.03038864e+03  1.06e-02    1075s
      37   2.87e-08 2.75e-08   1.40346823e+04  6.47210117e+03  8.55e-03    1117s
      38   2.23e-08 2.29e-08   1.33444423e+04  6.72601072e+03  7.48e-03    1186s
      39   2.00e-08 1.64e-08   1.30985294e+04  7.07611497e+03  6.81e-03    1248s
      40   1.73e-08 1.31e-08   1.27680335e+04  7.31625978e+03  6.16e-03    1285s
      41   1.44e-08 9.87e-09   1.24139017e+04  7.55726763e+03  5.49e-03    1318s
      42   1.22e-08 7.24e-09   1.21911414e+04  7.71398971e+03  5.06e-03    1347s
      43   1.14e-08 6.68e-09   1.20971954e+04  7.76091415e+03  4.90e-03    1368s
      44   7.61e-09 4.49e-09   1.15802896e+04  8.02091818e+03  4.02e-03    1391s
      45   5.27e-09 3.38e-09   1.12119638e+04  8.21659598e+03  3.39e-03    1430s
      46   4.74e-09 3.23e-09   1.11391059e+04  8.24174635e+03  3.28e-03    1463s
      47   4.57e-09 2.64e-09   1.11126636e+04  8.35498106e+03  3.12e-03    1484s
      48   3.76e-09 2.41e-09   1.09666979e+04  8.40725506e+03  2.89e-03    1503s
      49   2.34e-09 1.81e-09   1.06106911e+04  8.63154248e+03  2.24e-03    1524s
      50   2.09e-09 1.74e-09   1.05818880e+04  8.64755500e+03  2.19e-03    1572s
      51   2.01e-09 1.61e-09   1.05763705e+04  8.66683728e+03  2.16e-03    1598s
      52   1.98e-09 1.43e-09   1.05718769e+04  8.70725614e+03  2.11e-03    1614s
      53   1.78e-09 1.37e-09   1.05371910e+04  8.72487885e+03  2.05e-03    1632s
      54   1.58e-09 1.22e-09   1.04901182e+04  8.78376413e+03  1.93e-03    1649s
      55   1.51e-09 1.12e-09   1.04796139e+04  8.80961634e+03  1.89e-03    1665s
      56   1.42e-09 1.03e-09   1.04604194e+04  8.84331799e+03  1.83e-03    1678s
      57   1.19e-09 8.09e-10   1.04335000e+04  8.87893751e+03  1.76e-03    1692s
      58   9.48e-10 6.78e-10   1.03684264e+04  8.94121266e+03  1.61e-03    1707s
      59   8.16e-10 5.54e-10   1.03285920e+04  9.00754251e+03  1.49e-03    1723s
      60   6.39e-10 4.80e-10   1.02716250e+04  9.05052250e+03  1.38e-03    1738s
      61   5.54e-10 3.83e-10   1.02289724e+04  9.09735100e+03  1.28e-03    1755s
      62   5.40e-10 3.47e-10   1.02096462e+04  9.12421353e+03  1.23e-03    1773s
      63   2.37e-10 2.59e-10   1.00971029e+04  9.20224535e+03  1.01e-03    1791s
      64   1.93e-10 2.33e-10   1.00846196e+04  9.22793342e+03  9.68e-04    1814s
      65   1.90e-10 2.05e-10   1.00826696e+04  9.25511076e+03  9.35e-04    1829s
      66   1.83e-10 1.81e-10   1.00786235e+04  9.27896087e+03  9.04e-04    1842s
      67   1.57e-10 1.58e-10   1.00607359e+04  9.30390225e+03  8.56e-04    1854s
      68   4.06e-10 1.23e-10   1.00251777e+04  9.34791627e+03  7.66e-04    1865s
      69   1.17e-10 9.54e-11   9.99610267e+03  9.40054524e+03  6.73e-04    1878s
      70   7.30e-10 8.68e-11   9.98340190e+03  9.40994716e+03  6.48e-04    1891s
      71   8.52e-11 6.73e-11   9.95720979e+03  9.46627820e+03  5.55e-04    1903s
      72   3.59e-10 6.43e-11   9.95146868e+03  9.46816641e+03  5.46e-04    1916s
      73   7.57e-11 4.52e-11   9.92633439e+03  9.52290479e+03  4.56e-04    1927s
      74   2.00e-10 4.05e-11   9.91599082e+03  9.52951028e+03  4.37e-04    1940s
      75   4.37e-10 3.00e-11   9.88217144e+03  9.55862813e+03  3.66e-04    1952s
      76   1.85e-10 2.55e-11   9.87746680e+03  9.57366363e+03  3.43e-04    1964s
      77   2.19e-10 2.31e-11   9.87505143e+03  9.57774339e+03  3.36e-04    1975s
      78   7.56e-11 1.90e-11   9.85388345e+03  9.60110155e+03  2.86e-04    1984s
      79   5.69e-10 1.34e-11   9.84712905e+03  9.62675868e+03  2.49e-04    1996s
      80   2.74e-10 8.61e-12   9.83650621e+03  9.64762624e+03  2.14e-04    2008s
      81   2.94e-10 8.44e-12   9.83026104e+03  9.65130133e+03  2.02e-04    2020s
      82   2.57e-10 5.54e-12   9.81311564e+03  9.67265891e+03  1.59e-04    2030s
      83   4.18e-10 5.31e-12   9.81102650e+03  9.67489246e+03  1.54e-04    2042s
      84   4.73e-10 4.12e-12   9.79593420e+03  9.68638952e+03  1.24e-04    2051s
      85   1.77e-10 3.03e-12   9.79405908e+03  9.69475900e+03  1.12e-04    2064s
      86   2.23e-10 2.27e-12   9.78800260e+03  9.71201800e+03  8.59e-05    2075s
      87   4.96e-10 1.66e-12   9.78778377e+03  9.71487741e+03  8.24e-05    2085s
      88   1.08e-10 1.85e-12   9.78398158e+03  9.71901673e+03  7.34e-05    2094s
      89   5.02e-10 1.10e-12   9.78337445e+03  9.72375826e+03  6.74e-05    2105s
      90   1.27e-10 1.17e-12   9.77736326e+03  9.73354552e+03  4.95e-05    2114s
      91   9.00e-11 9.38e-13   9.77512191e+03  9.73752658e+03  4.25e-05    2128s
      92   6.31e-11 4.26e-13   9.77103532e+03  9.74405874e+03  3.05e-05    2138s
      93   2.05e-09 5.90e-13   9.76961724e+03  9.74735298e+03  2.52e-05    2151s
      94   4.21e-09 8.81e-13   9.76788907e+03  9.75109834e+03  1.90e-05    2162s
      95   1.62e-09 1.19e-12   9.76716151e+03  9.75395650e+03  1.49e-05    2172s
      96   2.72e-09 6.82e-13   9.76603492e+03  9.75527391e+03  1.22e-05    2182s
      97   2.04e-09 5.40e-13   9.76535302e+03  9.75722758e+03  9.18e-06    2191s
      98   5.17e-09 3.69e-13   9.76470022e+03  9.75753839e+03  8.10e-06    2200s
      99   5.46e-10 1.73e-12   9.76412209e+03  9.75921450e+03  5.55e-06    2207s
     100   4.66e-09 4.55e-13   9.76376806e+03  9.75947960e+03  4.85e-06    2214s
     101   8.68e-10 6.82e-13   9.76348975e+03  9.76028015e+03  3.63e-06    2222s
     102   6.87e-09 4.83e-13   9.76322229e+03  9.76103329e+03  2.47e-06    2229s
     103   1.80e-09 4.83e-13   9.76304417e+03  9.76115161e+03  2.14e-06    2237s
     104   7.78e-09 5.40e-13   9.76301308e+03  9.76126585e+03  1.98e-06    2245s
     105   1.70e-08 7.39e-13   9.76274488e+03  9.76155953e+03  1.34e-06    2253s
     106   1.52e-09 6.25e-13   9.76271595e+03  9.76166866e+03  1.18e-06    2263s
     107   1.80e-09 4.55e-13   9.76262785e+03  9.76198378e+03  7.28e-07    2271s
     108   4.26e-09 8.81e-13   9.76259558e+03  9.76205747e+03  6.08e-07    2280s
     109   2.80e-09 9.95e-13   9.76255188e+03  9.76219281e+03  4.06e-07    2289s
     110   1.43e-09 1.19e-12   9.76251174e+03  9.76234638e+03  1.87e-07    2298s
     111   1.53e-08 1.81e-12   9.76247806e+03  9.76239595e+03  9.28e-08    2309s
     112   3.58e-09 3.19e-12   9.76246937e+03  9.76239982e+03  7.86e-08    2321s
     113   2.67e-08 1.75e-12   9.76246448e+03  9.76240389e+03  6.85e-08    2329s
     114   3.74e-09 7.34e-12   9.76244989e+03  9.76241737e+03  3.68e-08    2337s
     115   2.49e-08 3.42e-12   9.76244709e+03  9.76242530e+03  2.46e-08    2345s
     116   1.43e-08 1.02e-11   9.76244319e+03  9.76242949e+03  1.55e-08    2353s
     117   2.21e-08 1.61e-11   9.76244276e+03  9.76242971e+03  1.48e-08    2361s
     118   4.86e-08 1.00e-11   9.76243856e+03  9.76243103e+03  8.51e-09    2368s
     119   4.37e-09 1.38e-11   9.76243759e+03  9.76243267e+03  5.55e-09    2375s
     120   5.22e-08 3.55e-11   9.76243681e+03  9.76243503e+03  2.01e-09    2383s
     121   3.88e-08 3.24e-12   9.76243664e+03  9.76243621e+03  4.84e-10    2392s
     122   5.24e-09 3.08e-11   9.76243661e+03  9.76243649e+03  1.38e-10    2421s
     123*  1.87e-09 2.14e-11   9.76243659e+03  9.76243656e+03  3.42e-11    2461s
     124*  9.49e-09 3.20e-11   9.76243659e+03  9.76243659e+03  4.77e-12    2476s
     125*  4.15e-09 2.95e-11   9.76243659e+03  9.76243659e+03  6.91e-13    2485s
    Running crossover as requested
        Primal residual before push phase:                  3.73e-06
        Dual residual before push phase:                    4.36e-07
        Number of dual pushes required:                     119652
        97338 dual pushes remaining (    320 pivots)
        Number of primal pushes required:                   17699
        16518 primal pushes remaining (     94 pivots)
        15210 primal pushes remaining (    470 pivots)
        13722 primal pushes remaining (   1070 pivots)
        12413 primal pushes remaining (   1416 pivots)
        11234 primal pushes remaining (   1895 pivots)
         9984 primal pushes remaining (   2321 pivots)
         9070 primal pushes remaining (   2591 pivots)
         7820 primal pushes remaining (   2867 pivots)
         6521 primal pushes remaining (   3285 pivots)
         5414 primal pushes remaining (   3883 pivots)
         4305 primal pushes remaining (   4325 pivots)
         3129 primal pushes remaining (   4876 pivots)
         1854 primal pushes remaining (   5548 pivots)
          551 primal pushes remaining (   6269 pivots)
    Summary
        Runtime:                                            2565.87s
        Status interior point solve:                        optimal
        Status crossover:                                   optimal
        objective value:                                    9.76243659e+03
        interior solution primal residual (abs/rel):        2.27e-08 / 5.51e-12
        interior solution dual residual (abs/rel):          2.88e-09 / 2.04e-11
        interior solution objective gap (abs/rel):          6.44e-07 / 6.60e-11
        basic solution primal infeasibility:                1.04e-11
        basic solution dual infeasibility:                  2.02e-15
    Ipx: IPM       optimal
    Ipx: Crossover optimal
    Solving the original LP from the solution after postsolve
    Model   status      : Optimal
    IPM       iterations: 125
    Crossover iterations: 14577
    Objective value     :  9.7624365896e+03
    HiGHS run time      :       2567.64
    LP solved for primal
     
    ----------------------------------------------------
    Iteration 3
    Tolerance = 0.01
    ----------------------------------------------------
    Discharge Module
    Non-served Energy Module
    Investment Discharge Module
    Unit Commitment Module
    Fuel Module
    CO2 Module
    Investment Transmission Module
    Transmission Module
    Dispatchable Resources Module
    Storage Resources Module
    Storage Investment Module
    Storage Core Resources Module
    Storage Resources with Symmetric Charge/Discharge Capacity Module
    Thermal (Unit Commitment) Resources Module
    CO2 Policies Module


Using the smallest tolerance as our base, we can see the error as the tolerance increases:




```julia
DataFrame([tols[2:end] abs.(OV[2:end] .- OV[1])],["Tolerance", "Error"])
```


```julia
using Plots
using Plotly
```


```julia
# Plot the error as a function of the tolerance
plotlyjs()
Plots.scatter(tols[2:end], abs.(OV[2:end] .- OV[1]),legend=:topleft,
                ylabel="Error", xlabel="Tolerance",size=(920,400),label=:"Error",title="Tolerance of Solver vs Error")
ygrid!(:on, :dashdot, 0.1)
```

### PreSolve <a id="PreSolve"></a>

In optimization, presolve is a stage at the beginning of the solver in which the problem is simplified to remove redunant constraints and otherwise streamline the problem before the optimization itself begins. The default for presolve in GenX is "choose", allowing the solver to use presolve only if it will reduce computation time. 

Let's try setting presolve to off and on, then compare computation times.




```julia
# First, set tolerances back to original
highs_settings["Feasib_Tol"] = 1e-5
highs_settings["Optimal_Tol"] = 1e-5
YAML.write_file(joinpath(case,"settings/highs_settings.yml"), highs_settings)    
```


```julia
highs_settings["Pre_Solve"] = "off"
YAML.write_file(joinpath(case,"settings/highs_settings.yml"), highs_settings)
OPTIMIZER2 = GenX.configure_solver(settings_path, HiGHS.Optimizer);
EP2 = GenX.generate_model(setup, inputs, OPTIMIZER2)
```


```julia
solution2 = @elapsed GenX.solve_model(EP2,setup)
```


```julia
highs_settings["Pre_Solve"] = "on"
YAML.write_file(joinpath(case,"settings/highs_settings.yml"), highs_settings)
OPTIMIZER3 = GenX.configure_solver(settings_path,HiGHS.Optimizer);
EP3 = GenX.generate_model(setup,inputs,OPTIMIZER3)
```


```julia
solution3 = @elapsed GenX.solve_model(EP3,setup)
```

As we can see, the runtime with PreSolve is shorter, and would be even shorter for a larger system. However, PreSolve can sometimes introduce numerical inaccuracies. If you find the model is struggling to converge, try turning PreSolve off.




```julia
# Write PreSolve back to choose
highs_settings["Pre_Solve"] = "choose"
YAML.write_file(joinpath(case,"settings/highs_settings.yml"), highs_settings)
```

### Crossover <a id="Crossover"></a>

Crossover is a method in which, at each step of the optimization algorithm, the solution is pushed to the boundary of the solution space. This allows for a potentially more accurate solution, but can be computationally intensive. The default for `1_three_zones` is "on". Let's try turning crossover on and off and see what solutions we get:


```julia
highs_settings["run_crossover"] = "off"
YAML.write_file(joinpath(case,"settings/highs_settings.yml"), highs_settings)
OPTIMIZER4 = GenX.configure_solver(settings_path,HiGHS.Optimizer);
EP4 = GenX.generate_model(setup,inputs,OPTIMIZER4)
```


```julia
solution4 = @elapsed GenX.solve_model(EP4,setup)
```


```julia
highs_settings["run_crossover"] = "on"
YAML.write_file(joinpath(case,"settings/highs_settings.yml"), highs_settings)
OPTIMIZER5 =  GenX.configure_solver(settings_path,HiGHS.Optimizer);
EP5 = GenX.generate_model(setup,inputs,OPTIMIZER5)
```


```julia
solution5 = @elapsed GenX.solve_model(EP5,setup)
```


```julia

```
