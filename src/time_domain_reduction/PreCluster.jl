"""
GenX: An Configurable Capacity Expansion Model
Copyright (C) 2021,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

###############
#
#  Pre-Cluster
#
#  Clustering will run within GenX automatically if using the TimeDomainReduction parameter
#  in the settings file and if there are no pre-existing clustered inputs in the
#  directory, but you can use this to cluster independently beforehand or to
#  investigate the clustering process and results.
#
#  Run with the following:
#    include("PreCluster.jl")
#
#  Beforehand, set the following parameters in this file:
#    REQUIRED
#    1) inpath -- The directory where the input data is stored
#    OPTIONAL
#    2) v -- True or False, verbosity
#
#  Jack Morris (3/5/2021)
#
###############

working_path = pwd()
src_path = cd(pwd, "..") # pwd() parent
genx_path = cd(pwd, "..\\..") # pwd() grandparent

push!(LOAD_PATH, working_path)
push!(LOAD_PATH, src_path)
push!(LOAD_PATH, genx_path)

using GenX
using DataFrames
using YAML

# Input Data Directory
#inpath = "$working_path/Example_Clustering_SE"
#inpath = "$genx_path/input_data/Inputs/RealSystemExample/ISONE_Trizone_FullTimeseries"
inpath = "$genx_path\\Example_Systems\\SmallNewEngland\\ThreeZones"

# Verbosity and Plot Choices
v = false

# Settings
settings_path = joinpath(inpath, "Settings")
mysetup = YAML.load(open(joinpath(settings_path, "genx_settings.yml")))
TDRpath = joinpath(inpath, mysetup["TimeDomainReductionFolder"])

if (isfile(TDRpath*"/Load_data.csv")) || (isfile(TDRpath*"/Generators_variability.csv")) || (isfile(TDRpath*"/Fuels_data.csv"))
    println("Data is already clustered. Delete '*_clustered.csv' files and retry: ")
    println(inpath)
elseif mysetup["TimeDomainReduction"] == 0
    println("Trying to pre-cluster the inputs, but the TimeDomainReduction setting is set to 0. Set to 1 and try again.")
    println(settings_path)
else
    Rep_Period, Weights, RMSE, TDRsetup, col_to_zone_map = cluster_inputs(inpath, settings_path, mysetup, v)
    if v
        for res in RMSE
            println(res)
        end
    end
end
