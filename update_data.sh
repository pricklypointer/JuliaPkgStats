# wget -O - https://julialang-logs.s3.amazonaws.com/public_outputs/current/client_types.csv.gz | gunzip > input/client_types.csv
# wget -O - https://julialang-logs.s3.amazonaws.com/public_outputs/current/julia_systems.csv.gz | gunzip > input/julia_systems.csv
wget -O - https://julialang-logs.s3.amazonaws.com/public_outputs/current/julia_systems_by_date.csv.gz | gunzip > input/julia_systems_by_date.csv
# wget -O - https://julialang-logs.s3.amazonaws.com/public_outputs/current/julia_versions.csv.gz | gunzip > input/julia_versions.csv
wget -O - https://julialang-logs.s3.amazonaws.com/public_outputs/current/julia_versions_by_date.csv.gz | gunzip > input/julia_versions_by_date.csv
# wget -O - https://julialang-logs.s3.amazonaws.com/public_outputs/current/julia_versions_by_region_by_date.csv.gz | gunzip > input/julia_versions_by_region_by_date.csv
# wget -O - https://julialang-logs.s3.amazonaws.com/public_outputs/current/resource_types.csv.gz | gunzip > input/resource_types.csv
# wget -O - https://julialang-logs.s3.amazonaws.com/public_outputs/current/resource_types_by_date.csv.gz | gunzip > input/resource_types_by_date.csv
wget -O - https://julialang-logs.s3.amazonaws.com/public_outputs/current/package_requests.csv.gz | gunzip > input/package_requests.csv
wget -O - https://julialang-logs.s3.amazonaws.com/public_outputs/current/package_requests_by_date.csv.gz | gunzip > input/package_requests_by_date.csv
wget -O - https://julialang-logs.s3.amazonaws.com/public_outputs/current/package_requests_by_region_by_date.csv.gz | gunzip > input/package_requests_by_region_by_date.csv
julia --project=postgres ./postgres/update_data.jl