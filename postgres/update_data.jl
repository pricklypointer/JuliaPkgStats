using DataFrames: DataFrame, dropmissing, innerjoin, select!, groupby, combine
using LibPQ: LibPQ
using RegistryInstances: reachable_registries
using TidierFiles: read_csv

const DB_PASSWORD = ENV["DB_PASSWORD"]

"""
Load data into postgres and ignore duplicates
"""
function load!(
    conn::LibPQ.Connection,
    schema::String,
    table::String,
    duplicate_cols::Vector{String},
    df::DataFrame,
)
    try
        LibPQ.execute(conn, "BEGIN;")
        col_names = join(names(df), ", ")
        col_vals = "\$" * join(collect(1:1:length(names(df))), ", \$")
        duplicate_cols = join(duplicate_cols, ", ")
        sql = "INSERT INTO $schema.$table ($col_names) VALUES($col_vals) ON CONFLICT ($duplicate_cols) DO NOTHING"
        println("SQL statement:")
        println(sql)
        LibPQ.load!(df, conn, sql)
    finally
        LibPQ.execute(conn, "COMMIT;")
    end
end

function load!(
    conn::LibPQ.Connection,
    schema::String,
    table::String,
    duplicate_cols::Vector{String},
    update_cols::Vector{String},
    df::DataFrame,
)
    try
        LibPQ.execute(conn, "BEGIN;")
        col_names = join(names(df), ", ")
        col_vals = "\$" * join(collect(1:1:length(names(df))), ", \$")
        duplicate_cols = join(duplicate_cols, ", ")
        update_cols = join(["$col = EXCLUDED.$col" for col in update_cols], ", ")
        sql = "INSERT INTO $schema.$table ($col_names) VALUES($col_vals) ON CONFLICT ($duplicate_cols) DO UPDATE SET $update_cols"
        println("SQL statement:")
        println(sql)
        LibPQ.load!(df, conn, sql)
    finally
        LibPQ.execute(conn, "COMMIT;")
    end
end

conn_str = "host=localhost port=5432 dbname=postgres user=postgres password=$DB_PASSWORD"
conn = LibPQ.Connection(conn_str)

###########################################################
# Mapping tables
###########################################################
registries = reachable_registries()
df_uuid_name = DataFrame(; package_uuid = String[], package_name = String[])
for rego in registries
    for (pkg_uuid, pkg_entry) in rego.pkgs
        push!(df_uuid_name, ("$pkg_uuid", pkg_entry.name))
    end
end
load!(conn, "juliapkgstats", "uuid_name", ["package_uuid"], df_uuid_name)

df_client_types =
    DataFrame(; client_type = ["user", "ci", "missing"], client_type_id = [1, 2, 3])
load!(conn, "juliapkgstats", "client_types", ["client_type"], df_client_types)

###########################################################
# Load data
###########################################################

df_uuid_name = DataFrame(LibPQ.execute(conn, "select * from juliapkgstats.uuid_name"))
df_client_types = DataFrame(LibPQ.execute(conn, "select * from juliapkgstats.client_types"))

# package_requests
df_package_requests = read_csv("input/package_requests.csv")
df_package_requests = df_package_requests[df_package_requests.status.<400, :]
df_package_requests = combine(
    groupby(df_package_requests, [:package_uuid, :client_type]),
    :request_addrs => sum => :request_addrs,
    :request_count => sum => :request_count,
)
df_package_requests =
    innerjoin(df_package_requests, df_uuid_name; on = :package_uuid => :package_uuid)
df_package_requests[ismissing.(df_package_requests.client_type), :client_type] .= "missing"
df_package_requests =
    innerjoin(df_package_requests, df_client_types; on = :client_type => :client_type)
select!(df_package_requests, [:package_id, :client_type_id, :request_count])
load!(
    conn,
    "juliapkgstats",
    "package_requests",
    ["package_id", "client_type_id"],
    ["request_count"],
    df_package_requests,
)

# package_requests_by_date
df_package_requests_by_date = read_csv("input/package_requests_by_date.csv")
df_package_requests_by_date =
    df_package_requests_by_date[df_package_requests_by_date.status.<400, :]
df_package_requests_by_date = combine(
    groupby(df_package_requests_by_date, [:package_uuid, :client_type, :date]),
    :request_count => sum => :request_count,
)
df_package_requests_by_date = innerjoin(
    df_package_requests_by_date,
    df_uuid_name;
    on = :package_uuid => :package_uuid,
)
df_package_requests_by_date[
    ismissing.(df_package_requests_by_date.client_type),
    :client_type,
] .= "missing"
df_package_requests_by_date = innerjoin(
    df_package_requests_by_date,
    df_client_types;
    on = :client_type => :client_type,
)
select!(df_package_requests_by_date, [:package_id, :client_type_id, :date, :request_count])
load!(
    conn,
    "juliapkgstats",
    "package_requests_by_date",
    ["package_id", "client_type_id", "date"],
    ["request_count"],
    df_package_requests_by_date,
)

# package_requests_by_region_by_date
df_package_requests_by_region_by_date =
    read_csv("input/package_requests_by_region_by_date.csv")
df_package_requests_by_region_by_date = df_package_requests_by_region_by_date[
    df_package_requests_by_region_by_date.status.<400,
    :,
]
df_package_requests_by_region_by_date = combine(
    groupby(df_package_requests_by_region_by_date, [:package_uuid, :client_type, :region, :date]),
    :request_count => sum => :request_count,
)
df_package_requests_by_region_by_date = innerjoin(
    df_package_requests_by_region_by_date,
    df_uuid_name;
    on = :package_uuid => :package_uuid,
)
df_package_requests_by_region_by_date[
    ismissing.(df_package_requests_by_region_by_date.client_type),
    :client_type,
] .= "missing"
df_package_requests_by_region_by_date = innerjoin(
    df_package_requests_by_region_by_date,
    df_client_types;
    on = :client_type => :client_type,
)
select!(
    df_package_requests_by_region_by_date,
    [:package_id, :client_type_id, :region, :date, :request_count],
)
load!(
    conn,
    "juliapkgstats",
    "package_requests_by_region_by_date",
    ["package_id", "client_type_id", "region", "date"],
    ["request_count"],
    df_package_requests_by_region_by_date,
)

# julia_systems_by_date
df_julia_systems_by_date = dropmissing(read_csv("input/julia_systems_by_date.csv"))
df_julia_systems_by_date.system = map(
    julia_system -> join(split(julia_system, "-")[1:2], "-"),
    df_julia_systems_by_date.julia_system,
)
df_julia_systems_by_date[
    ismissing.(df_julia_systems_by_date.client_type),
    :client_type,
] .= "missing"
df_julia_systems_by_date =
    innerjoin(df_julia_systems_by_date, df_client_types; on = :client_type => :client_type)
select!(df_julia_systems_by_date, [:system, :client_type_id, :date, :request_count])
load!(
    conn,
    "juliapkgstats",
    "julia_systems_by_date",
    ["system", "client_type_id", "date"],
    ["request_count"],
    df_julia_systems_by_date,
)

# julia_versions_by_date
df_julia_versions_by_date = dropmissing(read_csv("input/julia_versions_by_date.csv"))
df_julia_versions_by_date.version = map(
    version -> join(split(version, ".")[1:2], "."),
    df_julia_versions_by_date.julia_version_prefix,
)
df_julia_versions_by_date[
    ismissing.(df_julia_versions_by_date.client_type),
    :client_type,
] .= "missing"
df_julia_versions_by_date =
    innerjoin(df_julia_versions_by_date, df_client_types; on = :client_type => :client_type)
select!(df_julia_versions_by_date, [:version, :client_type_id, :date, :request_count])
load!(
    conn,
    "juliapkgstats",
    "julia_versions_by_date",
    ["version", "client_type_id", "date"],
    ["request_count"],
    df_julia_versions_by_date,
)

###########################################################
# Refresh materialized views
###########################################################
sql_refresh = """
    REFRESH MATERIALIZED VIEW juliapkgstats.mv_package_requests_summary_last_month;
"""
LibPQ.execute(conn, sql_refresh)

LibPQ.close(conn)
