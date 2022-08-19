#!/bin/bash
#SBATCH --job-name=p1              # create a short name for your job
#SBATCH --nodes=1                           # node count
#SBATCH --ntasks=1                          # total number of tasks across all nodes
#SBATCH --cpus-per-task=12                   # cpu-cores per task (>1 if multi-threaded tasks)
#SBATCH --mem-per-cpu=10G                    # memory per cpu-core
#SBATCH --time=24:00:00                     # total run time limit (HH:MM:SS)
#SBATCH --output="test.out"
#SBATCH --error="test.err"
#SBATCH --mail-type=FAIL                    # notifications for job done & fail
#SBATCH --mail-type=end                    # notifications for job done & fail
#SBATCH --mail-user=manocha@princeton.edu  # send-to address


module add julia/1.3.0
module add CPLEX
julia Run.jl

date

