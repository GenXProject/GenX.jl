This example requires an experimental feature which is *deactivated* because it is under development.
To reactivate the feature, comment out the relevant line in load_generators_data!.

Multi-Stage Retrofit Example
----------------------------

Description: One zone, few technologies, retrofit options include CCS, H2, SMR, and TES.

All changes necessary in the inputs in enable retrofit modeling are located in the resource `.csv` files.

New fields:

 - RETRO: Indicates that this resource is a retrofit option.
 - Num_RETRO_Sources: Indicates number of source technologies that can have capacity transferred to this retrofit resource type.
For i in 1:n source technologies,
 - Retro[i]_Source: Resource name of source technology i.
 - Retro[i]_Efficiency: Ratio of incoming retrofit capacity to retiring source capacity (e.g., 0.93 could mean that retiring 100 MW of NGCC result in 93 MW added of Retro_NGCC_CCS).
 - Retro[i]_Inv_Cost_per_MWyr: Annualized investment cost ($/MWyr) of retrofitting capacity from source technology i to this retrofit technology.
