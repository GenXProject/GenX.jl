import Pkg

# Activate the GenX environment explicitly
Pkg.activate("/data/home/smenezes/GenX_045")   # Replace with absolute path

# Optional: ensure your local copy is used
#Pkg.develop(path="/data/home/smenezes/GenX_045")

ENV["GENX_PRECOMPILE"] = "false"  # optional, skip precompile messages

# Now run your actual code
include("/data/home/smenezes/GenX_045/example_systems/NY_v11/Current_Policy/inputs/inputs_p3_ESR_CapResMar/Run.jl")
