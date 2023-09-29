"""
	path = choose_output_dir(pathinit)

Avoid overwriting (potentially important) existing results by appending to the directory name\n
Checks if the suggested output directory already exists. While yes, it appends _1, _2, etc till an unused name is found
"""
function choose_output_dir(pathinit::String)
    path = pathinit
    counter = 1
    while isdir(path)
        path = string(pathinit, "_", counter)
        counter += 1
    end
    return path
end
