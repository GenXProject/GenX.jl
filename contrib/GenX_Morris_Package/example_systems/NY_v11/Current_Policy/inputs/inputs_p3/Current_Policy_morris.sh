#!/bin/bash
#SBATCH --job-name=Current_Policy_p3
#SBATCH --output=Current_Policy_p3_%A_%a_%j.out
#SBATCH --error=Current_Policy_p3_%A_%a_%j.err
#SBATCH --partition=normal
#SBATCH --cpus-per-task=5
#SBATCH --ntasks=1
#SBATCH --time=5-02:00:00   # maximum for your partition

echo "[$(date)] Start"
# In your Slurm script
export JULIA_PROJECT=/data/home/smenezes/GenX_045  # or wherever your Project.toml is
export GRB_LICENSE_FILE=/opt/ohpc/pub/apps/gurobi/gurobi1203/linux64/licenses/gurobi.lic

module purge
module load gurobi/12.0.3
module load julia/1.10.4

julia /data/home/smenezes/GenX_045/example_systems/NY_v11/Current_Policy/inputs/inputs_p3/Current_Policy.jl

echo "[$(date)] Done"
