# Tutorial 1: Configuring Settings

GenX is easy to customize to fit a variety of problems. In this tutorial, we show which settings are available to change, what their defaults are, and how to change them in your code.

## What settings are there?

There are 21 settings available to edit in GenX, found in the file `genx_settings.yml`. These settings are described <a href="https://genxproject.github.io/GenX.jl/dev/User_Guide/model_configuration/#Model-settings-parameters" target="_blank">here</a> in the documentation. The file is located in the `Settings` folder in the working directory. To change the location of the file, edit the `settings_path` variable in `Run.jl` within your directory.

Most settings are set as either 0 or 1, which correspond to whether or not to include a specifc feature. For example, to use `TimeDomainReduction`, you would set its parameter to 1 within `genx_settings.yml`. If you would like to run GenX without it, you would set its parameter to 0.

Other settings, such as `CO2Cap`, have more options corresponding to integers, while some settings such as `ModelingtoGenerateAlternativeSlack` take a numerical input directly (in this case, the slack value). Two settings, `Solver` and `TimeDomainReductionFolder` take in text as input. To learn more about different solvers, read here. For `TimeDomainReductionFolder`, specify the name of the directory you wish to see the results in. For a more comprehensive description of the input options, see the documentation linked above.

To see how changing the settings affects the outputs, see Tutorials 3 and 7.

Below is the settings file for `example_systems/1_three_zones`:

<img src="./files/genxsettings.png" align="center"/>

All `genx_settings.yml` files in `Example_Systems` specify most parameters. When configuring your own settings, however, it is not necessary to input all parameters as defaults are specified for each one in `configure_settings.jl`.

<img src="./files/default_settings.png" align="center">

To open `genx_settings.yml` in Jupyter, use the function `YAML.load(open(...))` and navigate to file in the desired directory:


```julia
using YAML
using GenX
genx_settings_TZ = YAML.load(open("example_systems/1_three_zones/settings/genx_settings.yml"))
```




    Dict{Any, Any} with 13 entries:
      "NetworkExpansion"       => 1
      "ParameterScale"         => 1
      "EnergyShareRequirement" => 0
      "TimeDomainReduction"    => 1
      "Trans_Loss_Segments"    => 1
      "CapacityReserveMargin"  => 0
      "StorageLosses"          => 1
      "ComputeConflicts"       => 1
      "UCommit"                => 2
      "MaxCapReq"              => 0
      "MinCapReq"              => 1
      "CO2Cap"                 => 2
      "WriteShadowPrices"      => 1



Since all settings have defaults, you only need to specify the settings you would like to change. In fact, you can leave your settings file completely blank and it will still run! Let's try editing `genx_settings` in `example_systems/1_three_zones` to contain no parameters:


```julia
new_params = Dict() # Empty dictionary
YAML.write_file("example_systems/1_three_zones/settings/genx_settings.yml", new_params)
```

The empty file will look like this:

<img src="./files/genx_settings_none.png" align="center">

Now, we run GenX and output the file `capacity.csv` from the `results` folder. To do this, we use the function `include`, which takes a .jl file and runs it in Jupyter:


```julia
include("example_systems/1_three_zones/Run.jl")
```

    Configuring Settings
    Configuring Solver
    Loading Inputs
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
    CSV Files Successfully Read In From /Users/mayamutic/Desktop/GenX-Tutorials/Tutorials/example_systems/1_three_zones
    Generating the Optimization Model
    Set parameter Username
    Academic license - for non-commercial use only - expires 2024-09-14
    Set parameter FeasibilityTol to value 1e-05
    Set parameter PreDual to value 0
    Set parameter Method to value 4
    Set parameter TimeLimit to value 110000
    Set parameter MIPGap to value 0.001
    Set parameter OptimalityTol to value 1e-05
    Set parameter AggFill to value 10
    Set parameter Presolve to value 1
    Discharge Module
    Non-served Energy Module
    Investment Discharge Module
    Fuel Module
    CO2 Module
    Investment Transmission Module
    Transmission Module
    Dispatchable Resources Module
    Storage Resources Module
    Storage Investment Module
    Storage Core Resources Module
    Storage Resources with Symmetric Charge/Discharge Capacity Module
    Thermal (No Unit Commitment) Resources Module
    Time elapsed for model building is
    6.70277325
    Solving Model
    Set parameter FeasibilityTol to value 1e-05
    Set parameter PreDual to value 0
    Set parameter Method to value 4
    Set parameter TimeLimit to value 110000
    Set parameter MIPGap to value 0.001
    Set parameter OptimalityTol to value 1e-05
    Set parameter AggFill to value 10
    Set parameter Presolve to value 1
    Gurobi Optimizer version 10.0.3 build v10.0.3rc0 (mac64[arm])
    
    CPU model: Apple M2
    Thread count: 8 physical cores, 8 logical processors, using up to 8 threads
    
    Optimize a model with 543126 rows, 490574 columns and 1444876 nonzeros
    Model fingerprint: 0x9e68a46f
    Coefficient statistics:
      Matrix range     [4e-07, 1e+01]
      Objective range  [1e-01, 1e+05]
      Bounds range     [0e+00, 0e+00]
      RHS range        [2e+00, 2e+04]
    Presolve time: 0.43s
    Presolved: 328846 rows, 267533 columns, 1237068 nonzeros
    
    Deterministic concurrent LP optimizer: primal simplex, dual simplex, and barrier
    Showing barrier log only...
    
    Ordering time: 0.05s
    
    Barrier statistics:
     Dense cols : 13
     AA' NZ     : 1.634e+06
     Factor NZ  : 5.991e+06 (roughly 300 MB of memory)
     Factor Ops : 1.408e+08 (less than 1 second per iteration)
     Threads    : 6
    
                      Objective                Residual
    Iter       Primal          Dual         Primal    Dual     Compl     Time
       0   6.09150067e+13 -1.90135915e+14  5.19e+05 9.09e-13  1.97e+10     1s
       1   3.46550604e+13 -2.38128758e+14  3.07e+05 6.91e+04  1.07e+10     1s
       2   1.40609618e+13 -2.42855391e+14  1.23e+05 4.48e+04  5.41e+09     1s
       3   3.86925485e+12 -1.67604263e+14  1.63e+04 8.37e+03  1.04e+09     1s
       4   2.38428501e+12 -2.18305438e+13  1.21e+03 2.69e+02  6.68e+07     1s
       5   9.02408818e+11 -1.05811520e+13  5.18e+01 1.18e+02  2.47e+07     1s
       6   5.38178458e+11 -2.81878818e+12  1.23e+01 3.11e+01  6.94e+06     2s
       7   2.31783371e+11 -2.77221501e+11  1.76e+00 3.22e+00  9.52e+05     2s
       8   8.06477798e+10 -7.76109635e+10  3.10e-01 7.67e-01  2.75e+05     2s
       9   4.76893954e+10 -9.81966950e+09  1.42e-01 9.17e-02  8.65e+04     2s
      10   1.68698153e+10 -3.95661637e+08  3.67e-02 3.95e-03  2.50e+04     2s
      11   1.13288096e+10  2.42664626e+09  2.03e-02 1.40e-08  1.27e+04     2s
      12   1.05358477e+10  2.56817349e+09  1.79e-02 2.00e-08  1.14e+04     2s
      13   9.98541698e+09  2.80466974e+09  1.62e-02 4.66e-09  1.03e+04     2s
      14   9.26702483e+09  2.98602154e+09  1.37e-02 5.53e-10  8.99e+03     2s
      15   8.06247479e+09  3.02612307e+09  1.01e-02 6.69e-10  7.21e+03     2s
      16   6.73977443e+09  3.93389093e+09  6.02e-03 3.64e-12  4.01e+03     3s
      17   6.53816363e+09  4.17792212e+09  5.44e-03 2.56e-09  3.37e+03     3s
      18   6.35472650e+09  4.21080982e+09  4.93e-03 5.12e-09  3.06e+03     3s
      19   6.31835616e+09  4.27586369e+09  4.82e-03 3.73e-09  2.91e+03     3s
      20   6.13630938e+09  4.29483709e+09  4.32e-03 5.59e-09  2.63e+03     3s
      21   5.89526253e+09  4.33581522e+09  3.63e-03 5.12e-09  2.23e+03     3s
      22   5.76234018e+09  4.39443547e+09  3.24e-03 1.02e-08  1.95e+03     3s
      23   5.59630385e+09  4.54833891e+09  2.53e-03 3.49e-10  1.49e+03     4s
      24   5.57228715e+09  4.59623131e+09  2.45e-03 7.45e-09  1.39e+03     4s
      25   5.43697791e+09  4.64798132e+09  2.00e-03 1.16e-10  1.12e+03     4s
      26   5.40058655e+09  4.67440849e+09  1.86e-03 3.26e-09  1.03e+03     4s
      27   5.35526927e+09  4.69812654e+09  1.72e-03 3.64e-12  9.36e+02     4s
      28   5.33809266e+09  4.72515598e+09  1.66e-03 1.40e-09  8.73e+02     4s
      29   5.28663591e+09  4.75066952e+09  1.47e-03 6.75e-09  7.63e+02     4s
      30   5.13312972e+09  4.82122741e+09  9.29e-04 7.92e-09  4.43e+02     4s
      31   5.11445293e+09  4.83932397e+09  8.63e-04 7.92e-09  3.91e+02     5s
      32   5.07633942e+09  4.84240137e+09  7.25e-04 5.59e-09  3.32e+02     5s
      33   5.04792615e+09  4.85419546e+09  6.09e-04 1.16e-08  2.75e+02     5s
      34   5.01545138e+09  4.86546698e+09  4.91e-04 4.19e-09  2.13e+02     5s
      35   4.99762716e+09  4.87199562e+09  4.22e-04 1.35e-08  1.78e+02     5s
      36   4.97220725e+09  4.88173490e+09  3.24e-04 4.66e-10  1.28e+02     5s
      37   4.95616459e+09  4.88361068e+09  2.64e-04 5.82e-10  1.03e+02     5s
      38   4.94025882e+09  4.88799189e+09  1.98e-04 3.64e-12  7.42e+01     5s
      39   4.93698651e+09  4.88819726e+09  1.84e-04 1.40e-09  6.92e+01     6s
      40   4.93341549e+09  4.88871219e+09  1.69e-04 1.40e-09  6.34e+01     6s
      41   4.91918580e+09  4.89110812e+09  3.23e-04 8.38e-09  3.98e+01     6s
      42   4.91329837e+09  4.89226670e+09  1.09e-04 3.64e-12  2.98e+01     6s
      43   4.91226209e+09  4.89259935e+09  1.03e-04 5.46e-12  2.79e+01     6s
      44   4.90589229e+09  4.89315286e+09  9.11e-05 3.64e-12  1.81e+01     6s
      45   4.90504039e+09  4.89342038e+09  7.64e-05 3.64e-12  1.65e+01     6s
      46   4.90458084e+09  4.89373130e+09  7.30e-05 5.46e-12  1.54e+01     7s
      47   4.90270422e+09  4.89415404e+09  5.90e-05 3.26e-09  1.21e+01     7s
      48   4.90083605e+09  4.89444559e+09  7.48e-05 3.73e-09  9.07e+00     7s
      49   4.89973544e+09  4.89461106e+09  6.43e-05 4.66e-09  7.27e+00     7s
      50   4.89764178e+09  4.89473413e+09  3.84e-05 5.59e-09  4.13e+00     7s
      51   4.89690009e+09  4.89486913e+09  2.80e-05 3.73e-09  2.88e+00     8s
      52   4.89634914e+09  4.89493103e+09  1.99e-05 1.75e-10  2.01e+00     8s
      53   4.89604297e+09  4.89496198e+09  1.58e-05 9.31e-10  1.53e+00     8s
      54   4.89590140e+09  4.89498000e+09  1.38e-05 3.49e-09  1.31e+00     8s
      55   4.89580605e+09  4.89498862e+09  1.22e-05 1.40e-09  1.16e+00     8s
      56   4.89573111e+09  4.89499435e+09  1.10e-05 8.85e-09  1.05e+00     8s
      57   4.89545242e+09  4.89499895e+09  6.55e-06 3.26e-09  6.43e-01     8s
      58   4.89527003e+09  4.89500193e+09  3.75e-06 2.79e-09  3.80e-01     9s
      59   4.89513726e+09  4.89502761e+09  5.24e-06 6.40e-10  1.56e-01     9s
      60   4.89508333e+09  4.89503040e+09  4.39e-06 1.86e-09  7.51e-02     9s
      61   4.89506188e+09  4.89503311e+09  2.87e-06 5.24e-10  4.08e-02     9s
      62   4.89506145e+09  4.89503409e+09  2.84e-06 9.31e-09  3.88e-02     9s
      63   4.89504567e+09  4.89503487e+09  1.35e-06 2.33e-10  1.53e-02     9s
      64   4.89504159e+09  4.89503560e+09  8.38e-07 3.49e-09  8.50e-03    10s
      65   4.89503930e+09  4.89503623e+09  4.84e-07 4.19e-09  4.36e-03    10s
      66   4.89503757e+09  4.89503643e+09  3.01e-07 7.92e-09  1.61e-03    10s
      67   4.89503685e+09  4.89503648e+09  1.06e-07 1.86e-09  5.14e-04    10s
      68   4.89503655e+09  4.89503651e+09  2.11e-08 1.16e-08  6.10e-05    10s
      69   4.89503652e+09  4.89503652e+09  1.31e-06 1.69e-08  6.23e-07    10s
      70   4.89503652e+09  4.89503652e+09  1.79e-08 7.45e-09  3.60e-10    11s
    
    Barrier solved model in 70 iterations and 10.57 seconds (13.45 work units)
    Optimal objective 4.89503652e+09
    
    Crossover log...
    
       88397 DPushes remaining with DInf 2.3999402e+00                11s
           0 DPushes remaining with DInf 9.1624902e-01                12s
    
        7563 PPushes remaining with PInf 6.4626510e-05                12s
           0 PPushes remaining with PInf 0.0000000e+00                12s
    
      Push phase complete: Pinf 0.0000000e+00, Dinf 9.6736077e-01     12s
    
    Iteration    Objective       Primal Inf.    Dual Inf.      Time
       65604    4.8950365e+09   0.000000e+00   9.673608e-01     12s
    Concurrent spin time: 0.03s
    
    Solved with barrier
       65617    4.8950365e+09   0.000000e+00   0.000000e+00     12s
    
    Solved in 65617 iterations and 12.26 seconds (21.13 work units)
    Optimal objective  4.895036517e+09
    
    User-callback calls 97574, time in user-callback 0.01 sec
    LP solved for primal
    Writing Output
    Time elapsed for writing costs is
    1.249053375
    Time elapsed for writing capacity is
    0.314214583
    Time elapsed for writing power is
    0.721455625
    Time elapsed for writing charge is
    0.301870125
    Time elapsed for writing capacity factor is
    0.262774208
    Time elapsed for writing storage is
    0.1514105
    Time elapsed for writing curtailment is
    0.277159375
    Time elapsed for writing nse is
    0.666789417
    Time elapsed for writing power balance is
    0.525124583
    Time elapsed for writing transmission flows is
    0.116008625
    Time elapsed for writing transmission losses is
    0.141389292
    Time elapsed for writing emissions is
    0.27816775
    Time elapsed for writing reliability is
    0.155919333
    Time elapsed for writing storage duals is
    0.36908825
    Time elapsed for writing fuel consumption is
    0.567007833
    Time elapsed for writing co2 is
    0.131601083
    Time elapsed for writing price is
    0.0821955
    Time elapsed for writing energy revenue is
    0.294228875
    Time elapsed for writing charging cost is
    0.174773958
    Time elapsed for writing subsidy is
    0.176685375
    Time elapsed for writing time weights is
    0.048361209
    Time elapsed for writing net revenue is
    0.710684458
    Wrote outputs to /Users/mayamutic/Desktop/GenX-Tutorials/Tutorials/example_systems/1_three_zones/results_1
    Time elapsed for writing is
    8.160016916


The function `Run.jl` will build and then solve the model according to the specified parameters. These results will then be output into a `results` folder in the same directory. Note that the results folders are __not__ overwritten with each run.


```julia
using CSV
using DataFrames
results = CSV.read(open("example_systems/1_three_zones/results/capacity.csv"),DataFrame)
```




<div><div style = "float: left;"><span>11×15 DataFrame</span></div><div style = "clear: both;"></div></div><div class = "data-frame" style = "overflow-x: scroll;"><table class = "data-frame" style = "margin-bottom: 6px;"><thead><tr class = "header"><th class = "rowNumber" style = "font-weight: bold; text-align: right;">Row</th><th style = "text-align: left;">Resource</th><th style = "text-align: left;">Zone</th><th style = "text-align: left;">StartCap</th><th style = "text-align: left;">RetCap</th><th style = "text-align: left;">NewCap</th><th style = "text-align: left;">EndCap</th><th style = "text-align: left;">CapacityConstraintDual</th><th style = "text-align: left;">StartEnergyCap</th><th style = "text-align: left;">RetEnergyCap</th><th style = "text-align: left;">NewEnergyCap</th><th style = "text-align: left;">EndEnergyCap</th><th style = "text-align: left;">StartChargeCap</th><th style = "text-align: left;">RetChargeCap</th><th style = "text-align: left;">NewChargeCap</th><th style = "text-align: left;">EndChargeCap</th></tr><tr class = "subheader headerLastRow"><th class = "rowNumber" style = "font-weight: bold; text-align: right;"></th><th title = "String31" style = "text-align: left;">String31</th><th title = "String3" style = "text-align: left;">String3</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "String3" style = "text-align: left;">String3</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Float64" style = "text-align: left;">Float64</th></tr></thead><tbody><tr><td class = "rowNumber" style = "font-weight: bold; text-align: right;">1</td><td style = "text-align: left;">MA_natural_gas_combined_cycle</td><td style = "text-align: left;">1</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">7394.75</td><td style = "text-align: right;">7394.75</td><td style = "text-align: left;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td></tr><tr><td class = "rowNumber" style = "font-weight: bold; text-align: right;">2</td><td style = "text-align: left;">CT_natural_gas_combined_cycle</td><td style = "text-align: left;">2</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">2305.82</td><td style = "text-align: right;">2305.82</td><td style = "text-align: left;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td></tr><tr><td class = "rowNumber" style = "font-weight: bold; text-align: right;">3</td><td style = "text-align: left;">ME_natural_gas_combined_cycle</td><td style = "text-align: left;">3</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">716.666</td><td style = "text-align: right;">716.666</td><td style = "text-align: left;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td></tr><tr><td class = "rowNumber" style = "font-weight: bold; text-align: right;">4</td><td style = "text-align: left;">MA_solar_pv</td><td style = "text-align: left;">1</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">21186.5</td><td style = "text-align: right;">21186.5</td><td style = "text-align: left;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td></tr><tr><td class = "rowNumber" style = "font-weight: bold; text-align: right;">5</td><td style = "text-align: left;">CT_onshore_wind</td><td style = "text-align: left;">2</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">11905.5</td><td style = "text-align: right;">11905.5</td><td style = "text-align: left;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td></tr><tr><td class = "rowNumber" style = "font-weight: bold; text-align: right;">6</td><td style = "text-align: left;">CT_solar_pv</td><td style = "text-align: left;">2</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">16578.8</td><td style = "text-align: right;">16578.8</td><td style = "text-align: left;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td></tr><tr><td class = "rowNumber" style = "font-weight: bold; text-align: right;">7</td><td style = "text-align: left;">ME_onshore_wind</td><td style = "text-align: left;">3</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">12767.3</td><td style = "text-align: right;">12767.3</td><td style = "text-align: left;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td></tr><tr><td class = "rowNumber" style = "font-weight: bold; text-align: right;">8</td><td style = "text-align: left;">MA_battery</td><td style = "text-align: left;">1</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">3362.3</td><td style = "text-align: right;">3362.3</td><td style = "text-align: left;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">19427.7</td><td style = "text-align: right;">19427.7</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td></tr><tr><td class = "rowNumber" style = "font-weight: bold; text-align: right;">9</td><td style = "text-align: left;">CT_battery</td><td style = "text-align: left;">2</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">5318.36</td><td style = "text-align: right;">5318.36</td><td style = "text-align: left;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">27274.1</td><td style = "text-align: right;">27274.1</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td></tr><tr><td class = "rowNumber" style = "font-weight: bold; text-align: right;">10</td><td style = "text-align: left;">ME_battery</td><td style = "text-align: left;">3</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">2095.3</td><td style = "text-align: right;">2095.3</td><td style = "text-align: left;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">7096.27</td><td style = "text-align: right;">7096.27</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td></tr><tr><td class = "rowNumber" style = "font-weight: bold; text-align: right;">11</td><td style = "text-align: left;">Total</td><td style = "text-align: left;">n/a</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">83631.3</td><td style = "text-align: right;">83631.3</td><td style = "text-align: left;">n/a</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">53798.1</td><td style = "text-align: right;">53798.1</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td><td style = "text-align: right;">0.0</td></tr></tbody></table></div>



As you can see, this runs without a problem! To try with your own parameters, edit the `new_params` dictionary with whatever parameters you'd like to try and run the cells again. Note: to output the results, you'll have to either delete the previous `results` folder, or input the name of the new results folder (e.g. `results_1`) when calling `CSV.read` as above.

Finally, let's rewite `genx_settings.yml` to put the original settings in the example back: 


```julia
YAML.write_file("example_systems/1_three_zones/settings/genx_settings.yml", genx_settings_TZ)
```


```julia

```
