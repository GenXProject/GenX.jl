#!/bin/bash
#SBATCH --job-name=p12_4              # create a short name for your job
#SBATCH --nodes=1                           # node count
#SBATCH --ntasks=1                          # total number of tasks across all nodes
#SBATCH --cpus-per-task=12                   # cpu-cores per task (>1 if multi-threaded tasks)
#SBATCH --mem-per-cpu=10G                    # memory per cpu-core
#SBATCH --time=24:00:00                     # total run time limit (HH:MM:SS)
#SBATCH --error="test.err"
#SBATCH --output="test.out"
#SBATCH --mail-type=FAIL                    # notifications for job done & fail
#SBATCH --mail-user=patankar@princeton.edu  # send-to address


module add julia/1.6.1
module add CPLEX
julia Run.jl

date