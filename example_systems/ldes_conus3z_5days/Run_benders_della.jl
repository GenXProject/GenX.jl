using Pkg

case = dirname(@__FILE__)

Pkg.activate("/home/fp0820/GenX")

using GenX

genx_settings = GenX.get_settings_path(case, "genx_settings.yml") # Settings YAML file path
writeoutput_settings = GenX.get_settings_path(case, "output_settings.yml") # Write-output settings YAML file path
setup = GenX.configure_settings(genx_settings, writeoutput_settings) # mysetup dictionary stores settings and GenX-specific parameters

using Distributed,ClusterManagers
ntasks = parse(Int, ENV["SLURM_NTASKS"]);
cpus_per_task = parse(Int, ENV["SLURM_CPUS_PER_TASK"]);
addprocs(SlurmManager(ntasks);exeflags=["-t $cpus_per_task"])

@everywhere begin
    import Pkg
    Pkg.activate("/home/fp0820/GenX")
    using GenX
end

println("Number of procs: ", nprocs())
println("Number of workers: ", nworkers())

setup["Benders"] = 1;
benders_settings_path = GenX.get_settings_path(case, "benders_settings.yml")
setup_benders = GenX.configure_benders(benders_settings_path) 
setup = merge(setup,setup_benders);

setup["BD_StabParam"] = 0.0;
setup["BD_Stab_Method"]="off";
GenX.run_genx_case_benders!(case, setup)

setup["BD_StabParam"] = 0.5;
setup["BD_Stab_Method"]="int_level_set";
GenX.run_genx_case_benders!(case, setup)
