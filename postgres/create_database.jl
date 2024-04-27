using CSV
using DataFrames
using LibPQ
using RegistryInstances

const DB_PASSWORD = ENV["DB_PASSWORD"]

"""
Load data into postgres and ignore duplicates
"""
function load!(conn, schema, table, duplicate_cols, df)
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

conn_str = "host=localhost port=5432 dbname=postgres user=postgres password=$DB_PASSWORD"
conn = LibPQ.Connection(conn_str)

###########################################################
# Create schema and mapping table
###########################################################
# juliapkgstats schema
sql = "CREATE SCHEMA IF NOT EXISTS juliapkgstats;"
execute(conn, sql)


# UUID -> Package Name
sql = """
    CREATE TABLE IF NOT EXISTS juliapkgstats.uuid_name (
        package_id SERIAL PRIMARY KEY not null,
        package_uuid VARCHAR(36) not null,
        package_name VARCHAR(100) not null,
        CONSTRAINT uq_uuid_name_uuid UNIQUE (package_uuid)
    );
"""
execute(conn, sql)

###########################################################
# Create data tables
###########################################################

sql = """
    CREATE TABLE IF NOT EXISTS juliapkgstats.client_types (
        client_type_id smallint PRIMARY KEY not null,
        client_type VARCHAR(20) not null,
        CONSTRAINT unique_client_type UNIQUE (client_type)
    );
"""
execute(conn, sql)

# package_requests_by_date
sql = """
    CREATE TABLE IF NOT EXISTS juliapkgstats.package_requests_by_date (
        package_id INTEGER REFERENCES juliapkgstats.uuid_name(package_id) not null,
        client_type_id smallint REFERENCES juliapkgstats.client_types(client_type_id) not null,
        date DATE not null,
        request_count INTEGER not null,
        CONSTRAINT unique_package_id_date UNIQUE (package_id, client_type_id, date)
    );
"""
execute(conn, sql)

# package_requests_by_region_by_date
sql = """
    CREATE TABLE IF NOT EXISTS juliapkgstats.package_requests_by_region_by_date (
        package_id INTEGER REFERENCES juliapkgstats.uuid_name(package_id) not null,
        client_type_id smallint REFERENCES juliapkgstats.client_types(client_type_id) not null,
        region VARCHAR(10) not null,
        date DATE not null,
        request_count INTEGER not null,
        CONSTRAINT uq_pkg_req_region_pkg_id_client_date UNIQUE (package_id, client_type_id, region, date)
    );
"""
execute(conn, sql)

# julia_systems_by_date
sql = """
    CREATE TABLE IF NOT EXISTS juliapkgstats.julia_systems_by_date (
        system VARCHAR(17) not null,
        client_type_id smallint REFERENCES juliapkgstats.client_types(client_type_id) not null,
        date DATE not null,
        request_count INTEGER not null,
        CONSTRAINT uq_julia_sys_system_client_date UNIQUE (system, client_type_id, date)
    );
"""
execute(conn, sql)


# julia_versions_by_date
sql = """
    CREATE TABLE IF NOT EXISTS juliapkgstats.julia_versions_by_date (
        version VARCHAR(4) not null,
        client_type_id smallint REFERENCES juliapkgstats.client_types(client_type_id) not null,
        date DATE not null,
        request_count INTEGER not null,
        CONSTRAINT uq_julia_ver_version_client_date UNIQUE (version, client_type_id, date)
    );
"""
execute(conn, sql)

###########################################################
# Create materialized views
###########################################################
#TODO: Create materialized views for efficiently pulling recent data

sql = """
CREATE MATERIALIZED VIEW IF NOT EXISTS juliapkgstats.mv_package_requests_summary_last_month AS
SELECT 
    package_id, 
    client_type_id,
    SUM(request_count) AS total_requests
FROM 
    juliapkgstats.package_requests_by_date
WHERE 
    date > (
        SELECT MAX(date) - INTERVAL '1 month'
        FROM juliapkgstats.package_requests_by_date
    )
GROUP BY 
    package_id,
    client_type_id;
"""
execute(conn, sql)

###########################################################
# Truncate tables and restart identities
###########################################################
tables = [
"juliapkgstats.package_requests_by_date",
"juliapkgstats.package_requests_by_region_by_date",
"juliapkgstats.julia_systems_by_date",
"juliapkgstats.julia_versions_by_date",
"juliapkgstats.uuid_name"
]

"""
for table in tables
    sql_truncate = "TRUNCATE TABLE $table RESTART IDENTITY CASCADE;"
    execute(conn, sql_truncate)
end
"""

close(conn)
