#!/bin/bash

#SBATCH --job-name=3Z_5days      # create a short name for your job
#SBATCH --nodes=1                # node count
#SBATCH --ntasks=5
#SBATCH --ntasks-per-node=5
#SBATCH --cpus-per-task=1       # cpu-cores per task (>1 if multi-threaded tasks)
#SBATCH --output=slurm-%j.out
#SBATCH --mem-per-cpu=4GB       # memory per cpu-core 
#SBATCH --time=00:30:00          # total run time limit (HH:MM:SS)
#SBATCH --mail-type=all          # send email when job ends
#SBATCH --mail-user=fp0820@princeton.edu
######## #SBATCH --exclude=della-h12n16
#########SBATCH --constraint=cascade
######## #SBATCH --nodelist=della-h12n16

module purge
module load gurobi/10.0.1
module load julia/1.10.2

julia Run_benders_della.jl
