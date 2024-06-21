function __init__()
    print_genx_version()
end

function print_genx_version()
    v = pkgversion(GenX)
    ascii_art = raw"""  ____           __  __   _ _
    / ___| ___ _ __ \ \/ /  (_) |
   | |  _ / _ \ '_ \ \  /   | | |
   | |_| |  __/ | | |/  \ _ | | |
    \____|\___|_| |_/_/\_(_)/ |_|
                          |__/
    """
    ascii_art *= "Version: $(v)"
    println(ascii_art)
    return nothing
end
