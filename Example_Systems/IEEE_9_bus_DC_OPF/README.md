# IEEE 9-BUS Test case 

This examples shows the usage of DC_OPF related functions of GenX. The IEEE 9-bus system is a standard test case for power system optimization problems. In this example, there are three thermal generators and three loads. 

To run the model, first navigate to the example directory:

- Using a Julia REPL:

```bash
$ julia
julia> cd("example_systems/IEEE_9_bus_DC_OPF/")
```

- Using a terminal or command prompt:
```bash
$ cd example_systems/IEEE_9_bus_DC_OPF/
``` 

Next, ensure that your settings in `settings/genx_settings.yml` are correct (the default settings use the solver `HiGHS`).

Once the settings are confirmed, run the model with the `Run.jl` script in the example directory:

- Using a Julia REPL (recommended)
```julia
julia> include("Run.jl")
```
- Using a terminal or command prompt:
```bash
$ julia Run.jl
```

Once the model has completed, results will write to the `results` directory.
