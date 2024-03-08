# Tutorial 1: Configuring Settings

[Jupyter Notebook of the tutorial](https://github.com/GenXProject/GenX-Tutorials/blob/main/Tutorials/Tutorial_1_Configuring_Settings.ipynb)

GenX is easy to customize to fit a variety of problems. In this tutorial, we show which settings are available to change, what their defaults are, and how to change them in your code.

## What settings are there?

There are 21 settings available to edit in GenX, found in the file `genx_settings.yml`. These settings are described <a href="https://genxproject.github.io/GenX/dev/data_documentation/" target="_blank">here</a> in the documentation. The file is located in the `Settings` folder in the working directory. To change the location of the file, edit the `settings_path` variable in `Run.jl` within your directory.

Most settings are set as either 0 or 1, which correspond to whether or not to include a specifc feature. For example, to use `TimeDomainReduction`, you would set its parameter to 0 within `genx_settings.yml`. If you would like to run GenX without it, you would set its parameter to 1.

Other settings, such as `CO2Cap`, have more options corresponding to integers, while some settings such as `ModelingtoGenerateAlternativeSlack` take a numerical input directly (in this case, the slack value). Two settings, `Solver` and `TimeDomainReductionFolder` take in text as input. To learn more about different solvers, read here. For `TimeDomainReductionFolder`, specify the name of the directory you wish to see the results in. For a more comprehensive description of the input options, see the documentation linked above.

To see how changing the settings affects the outputs, see Tutorials 3 and 7.

Below is the settings file for `example_systems/1_three_zones`:

```@raw html
<img src="./files/genxsettings.png" align="center"/>
```

All `genx_settings.yml` files in `Example_Systems` specify most parameters. When configuring your own settings, however, it is not necessary to input all parameters as defaults are specified for each one in `configure_settings.jl`.

```@raw html
<img src="./files/default_settings.png" align="center">
```

To open `genx_settings.yml` in Jupyter, use the function `YAML.load(open(...))` and navigate to file in the desired directory:


```julia
using YAML
genx_settings_SNE = YAML.load(open("example_systems/1_three_zones/settings/genx_settings.yml"))
```




    Dict{Any, Any} with 19 entries:
      "NetworkExpansion"                        => 1
      "ModelingToGenerateAlternativeIterations" => 3
      "ParameterScale"                          => 1
      "EnergyShareRequirement"                  => 0
      "PrintModel"                              => 0
      "TimeDomainReduction"                     => 1
      "Trans_Loss_Segments"                     => 1
      "CapacityReserveMargin"                   => 0
      "ModelingtoGenerateAlternativeSlack"      => 0.1
      "MethodofMorris"                          => 0
      "StorageLosses"                           => 1
      "MultiStage"                              => 0
      "OverwriteResults"                        => 0
      "UCommit"                                 => 2
      "ModelingToGenerateAlternatives"          => 0
      "MaxCapReq"                               => 0
      "MinCapReq"                               => 1
      "CO2Cap"                                  => 2
      "WriteShadowPrices"                       => 1



Since all settings have defaults, you only need to specify the settings you would like to change. In fact, you can leave your settings file completely blank and it will still run! Let's try editing `genx_settings` in `SmallNewEngland/OneZone` to contain no parameters:


```julia
new_params = Dict() # Empty dictionary
YAML.write_file("example_systems/1_three_zones/settings/genx_settings.yml", new_params)
```

The empty file will look like this:

```@raw html
<img src="./files/genx_settings_none.png" align="center">
```

Now, we run GenX and output the file `capacity.csv` from the `Results` folder. To do this, we use the function `include`, which takes a .jl file and runs it in jupyter notebook:


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
    CSV Files Successfully Read In From /Users/lb9239/Documents/ZERO_lab/GenX/GenX-Tutorials/Tutorials/example_systems/1_three_zones
    Generating the Optimization Model
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



```julia
using CSV
using DataFrames
results = CSV.read(open("example_systems/1_three_zones/Results/capacity.csv"),DataFrame)
```

As you can see, this runs without a problem! To try with your own parameters, edit the `new_params` dictionary with whatever parameters you'd like to try and run the cells again.

Finally, let's rewite `genx_settings.yml` to put the original settings in the example back: 


```julia
YAML.write_file("example_systems/1_three_zones/settings/genx_settings.yml", genx_settings_SNE)
```
