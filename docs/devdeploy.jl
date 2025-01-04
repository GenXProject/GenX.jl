using LiveServer

"""
Run this script to locally host the documentation.
NOTE you have to dev the package in the `docs` environment to get local changes. 

e.g. 
```julia
[~/.julia/dev/GenX/docs]
(GenX) pkg> activate .
(GenX) pkg> dev ~/.julia/dev/GenX
julia> include("devdeploy.jl")
[ Info: Precompiling GenX ...

✓ LiveServer listening on http://localhost:8000/ ...
  (use CTRL+C to shut down)
```
"""
function devbuildserve()
    rm("build", force=true, recursive=true)
    include("make.jl")
    serve(dir="build")
end

devbuildserve()