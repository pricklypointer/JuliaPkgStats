module App

using GenieFramework
@appname JuliaPkgStats

include("AllPackageRequests.jl")
include("API.jl")
include("Home.jl")
include("TopPackageRequests.jl")
include("PackageRequests.jl")

end
