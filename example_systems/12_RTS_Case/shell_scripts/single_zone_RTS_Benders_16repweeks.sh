#!/bin/bash                                              
#SBATCH --job-name=single_zone_RTS_Benders_16repweeks
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=32
#SBATCH --output=slurm-%j.out
#SBATCH --mem-per-cpu=3G       # memory per cpu-core
#SBATCH --time=3:00:00          # total run time limit (HH:MM:SS)
#SBATCH --mail-type=all          # send email when job ends
#SBATCH --mail-user=dc0173@princeton.edu

module purge
module load gurobi/12.0.0
module load julia/1.10.5
julia -t 32 --project=../../../ ../run_Benders_16repweeks_single_zone_RTS_speedup_strategies.jl 0 0 6
julia -t 32 --project=../../../ ../run_Benders_16repweeks_single_zone_RTS_speedup_strategies.jl 1 0 6