# Tutorial 0: Getting Started

Welcome to the GenX tutorials! In the following tutorials, we outline some important features of GenX and how to run them.

Running these notebooks follows similar steps to those in the GenX documentation <a href="https://genxproject.github.io/GenX.jl/dev/installation/" target="_blank">here</a>. In this tutorial, we go through setting up GenX on Jupyter and navigating to the `Tutorials` file from there.

First, as in the documentation, open a terminal window on your computer and navigate to GenX. Then, navigate to Julia and open a project using the command `julia --project=.`.


<img src="./files/Julia.png" style="width: 625px; height: auto" align="left">

If you don't already have the package IJulia, add it here using `import(Pkg); Pkg.add("IJulia")`:

<img src="./files/addIJulia.png" style="width: 625px; height: auto" align="left">

Next, add the GenX package by  typing `Pkg.add("GenX")`

<img src="./files/addGenX.png" style="width: 625px; height: auto" align="left">

After IJulia is added, open a Jupyter notebook with `using IJulia; notebook()`:

<img src="./files/opennotebook.png" style="width: 625px; height: auto" align="left">

This will open a notebook in your default browser. From there, navigate through the directory to the `Tutorials` folder and you're good to go!

<img src="./files/jupyter_screen.png" style="width: 825px; height: auto" align="left">

**For a more detailed explanation of IJulia, Jupyter, and downloading packages, see <a href="https://docs.google.com/document/d/1Qb9yQL1McZGCiFb8yoO4Evrh8oATE2Fias_FvuuEirs/edit" target="_blank">here</a>.**
