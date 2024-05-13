module TopPackageRequests

using DataFrames
using Dates
using Format: format
using GenieFramework
using LibPQ
include("layout_shared.jl")
include("utils.jl")

const N_PACKAGES_TOP = 100
const N_PACKAGES_TRENDING = 10

function get_request_count(
    conn, time_interval, limit; user_data=true, ci_data=false, missing_data=false
)
    conditions = generate_sql_conditions(user_data, ci_data, missing_data)
    sql = """
        WITH max_date AS (
            SELECT MAX(date) AS max_date
            FROM juliapkgstats.package_requests_by_date
        )
        SELECT package_name, SUM(request_count) AS total_requests
            FROM juliapkgstats.package_requests_by_date
        INNER JOIN juliapkgstats.uuid_name ON juliapkgstats.package_requests_by_date.package_id = juliapkgstats.uuid_name.package_id
        CROSS JOIN max_date
        WHERE (date > max_date - INTERVAL '$time_interval') $conditions
        GROUP BY package_name
        ORDER BY total_requests DESC
        LIMIT $limit;
    """
    df = DataFrame(LibPQ.execute(conn, sql))
    df[!, :total_requests] = format.(df.total_requests, commas=true)
    return df
end

function get_trending_requests(
    conn, limit; user_data=true, ci_data=false, missing_data=false, daily_minimum=5
)
    conditions = generate_sql_conditions(user_data, ci_data, missing_data)
    sql = """
    with max_date AS(
        SELECT MAX(date) AS max_date
        FROM juliapkgstats.package_requests_by_date
    ),
    last_period_requests AS (
        SELECT package_name, SUM(request_count) AS total_requests, count(date) as n_days
        FROM juliapkgstats.package_requests_by_date
        INNER JOIN juliapkgstats.uuid_name ON juliapkgstats.package_requests_by_date.package_id = juliapkgstats.uuid_name.package_id
        CROSS JOIN max_date
        WHERE (date BETWEEN max_date - INTERVAL '14 days' and max_date) $conditions
            AND request_count > $daily_minimum
            AND package_name not like '%_jll'
        GROUP BY package_name
        HAVING count(date) > 12
        ORDER BY total_requests DESC
    ),
    previous_period_requests AS (
        SELECT package_name, SUM(request_count) AS total_requests
        FROM juliapkgstats.package_requests_by_date
        INNER JOIN juliapkgstats.uuid_name ON juliapkgstats.package_requests_by_date.package_id = juliapkgstats.uuid_name.package_id
        CROSS JOIN max_date
        WHERE (date BETWEEN max_date - INTERVAL '27 days' and max_date - INTERVAL '14 days') $conditions
            AND request_count > $daily_minimum
            AND package_name not like '%_jll'
        GROUP BY package_name
        HAVING count(date) > 12
        ORDER BY total_requests DESC
    )
    select lpr.package_name,
            ROUND(100.0 * (lpr.total_requests - ppr.total_requests) / ppr.total_requests, 2) AS percent_change
    from last_period_requests lpr
    INNER JOIN previous_period_requests ppr
        ON lpr.package_name = ppr.package_name
    WHERE lpr.total_requests > ppr.total_requests
    ORDER BY percent_change DESC
    limit $limit
    """
    df = DataFrame(LibPQ.execute(conn, sql))
    df[!, :percent_change] = ["$i%" for i in df.percent_change]
    return df
end

function ui()
    [   
        layout_shared()...,
        heading("Top Packages"),
        hr(style="border: 1px solid #ccc; margin: 20px 0;"),
        cell(class="row", [
            toggle("User", :user_data, val=true, color="green"),
            toggle("CI", :ci_data, val=false, color="red"),
            toggle("Misc", :missing_data, val=false, color="purple"),
        ]),
        cell(class="row", [
            cell(class="st-col col-12 col-sm st-module", [
                h4("Top This Month"),
                GenieFramework.table(:monthly_requests; pagination=DataTablePagination(rows_per_page=20), dense=true, flat=true)
            ]),
            cell(class="st-col col-12 col-sm st-module", [
                h4("Top This Week"),
                GenieFramework.table(:weekly_requests; pagination=DataTablePagination(rows_per_page=20), dense=true, flat=true)
            ]),
            cell(class="st-col col-12 col-sm st-module", [
                h4("Top Yesterday"),
                GenieFramework.table(:daily_requests; pagination=DataTablePagination(rows_per_page=20), dense=true, flat=true)
            ]),
        ]),
        hr(style="border: 1px solid #ccc; margin: 20px 0;"),
        cell(class="row", [
            cell(class="st-col col-12 col-sm st-module", [
                h4("Trending Downloads (last 2 weeks)"),
                GenieFramework.table(:trending_requests; pagination=DataTablePagination(rows_per_page=10), dense=true, flat=true)
            ]),
        ]),
        footer("The figures above represent unique IP address download counts for each package. The count might not fully reflect the actual downloads for packages with less frequent releases, and multiple counts could occur for users with dynamic IP addresses.", href="https://discourse.julialang.org/t/announcing-package-download-stats/69073")
    ]
end

@vars TopPackageRequestsData begin
    monthly_requests::DataTable = DataTable()
    weekly_requests::DataTable = DataTable()
    daily_requests::DataTable = DataTable()
    trending_requests::DataTable = DataTable()
end

@app begin
    @in user_data = true
    @in ci_data = false
    @in missing_data = false
    @in package_name_search = ""
    @out monthly_requests = DataTable()
    @out weekly_requests = DataTable()
    @out daily_requests = DataTable()
    @out trending_requests = DataTable()

    @onchange isready begin
        @push
    end

    @onchange user_data, ci_data, missing_data begin
        @info "Change in checkboxes on AllPackageRequests (user_data: $user_data, ci_data: $ci_data, missing_data: $missing_data)"
        conn = LibPQ.Connection(conn_str)
        monthly_requests = DataTable(get_request_count(
            conn, "1 month", N_PACKAGES_TOP; user_data, ci_data, missing_data
        ))
        weekly_requests = DataTable(get_request_count(
            conn, "7 day", N_PACKAGES_TOP; user_data, ci_data, missing_data
        ))
        daily_requests = DataTable(get_request_count(
            conn, "1 day", N_PACKAGES_TOP; user_data, ci_data, missing_data
        ))
        trending_requests = DataTable(get_trending_requests(
            conn, N_PACKAGES_TRENDING; user_data, ci_data, missing_data
        ))
        close(conn)
    end
end

route("/top"; method=GET) do
    conn = LibPQ.Connection(conn_str)
    monthly_requests = DataTable(get_request_count(conn, "1 month", N_PACKAGES_TOP))
    weekly_requests = DataTable(get_request_count(conn, "7 day", N_PACKAGES_TOP))
    daily_requests = DataTable(get_request_count(conn, "1 day", N_PACKAGES_TOP))
    trending_requests = DataTable(get_trending_requests(conn, N_PACKAGES_TRENDING))
    close(conn)
    model = @init
    model.monthly_requests[] = monthly_requests
    model.weekly_requests[] = weekly_requests
    model.daily_requests[] = daily_requests
    model.trending_requests[] = trending_requests
    html(page(model, ui()))
end

end
