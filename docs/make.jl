using GenX
using Documenter

DocMeta.setdocmeta!(GenX, :DocTestSetup, :(using GenX); recursive=true)

makedocs(;
    modules=[GenX],
    authors="Jesse Jenkins, Nestor Sepulveda, Dharik Mallapragada, Aaron Schwartz, Neha Patankar, Qingyu Xu, Jack Morris, Sambuddha Chakrabarti",
    repo="https://github.com/sambuddhac/GenX.jl/blob/{commit}{path}#{line}",
    sitename="GenX.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://sambuddhac.github.io/GenX.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/sambuddhac/GenX.jl",
)
