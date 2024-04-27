module PackageRequests

using DataFrames
using Dates
using Format
using GenieFramework
using Genie.Requests
using LibPQ
include("layout_shared.jl")
include("plots.jl")
include("utils.jl")

function get_request_count(conn, table, time_interval, group_cols, package_name; user_data=true, ci_data=false, missing_data=false)
    conditions = generate_sql_conditions(user_data, ci_data, missing_data)
    group_cols_str = join(string.(group_cols), ", ")
    sql = """
        WITH max_date AS (
            SELECT MAX(date) AS max_date
            FROM $table
        )
        SELECT $group_cols_str, SUM(request_count) AS total_requests
        FROM $table 
        inner join juliapkgstats.uuid_name ON $table.package_id = juliapkgstats.uuid_name.package_id
        CROSS JOIN max_date
        WHERE lower(juliapkgstats.uuid_name.package_name) = lower('$package_name')
            AND date > max_date - INTERVAL '$time_interval' $conditions
        GROUP BY $group_cols_str
        ORDER BY $group_cols_str DESC;
    """
    return LibPQ.execute(conn, sql) |> DataFrame
end

function ui()
    [   
        layout_shared()...,
        h2("{{ package_name }}"),
        hr(style="border: 1px solid #ccc;"),
        cell(class="row", [
            toggle("User", :user_data, val=true, color="green"),
            toggle("CI", :ci_data, val=false, color="red"),
            toggle("Misc", :missing_data, val=false, color="purple"),
        ]),
        p("Downloads last month: {{ past_month_requests }}"),
        p("Downloads last week: {{ past_week_requests }}"),
        p("Downloads last day: {{ past_day_requests }}"),
        hr(style="border: 1px solid #ccc; margin: 5px 0;"),
        GenieFramework.plotly(:total_downloads),
        GenieFramework.plotly(:region_downloads),
        GenieFramework.plotly(:region_proportion),
        a("The figures above represent unique IP address download counts for each package. The count might not fully reflect the actual downloads for packages with less frequent releases, and multiple counts could occur for users with dynamic IP addresses.", href="https://discourse.julialang.org/t/announcing-package-download-stats/69073")
    ]
end


function cleanse_input(input)
    input = strip(input)
    input = replace(input, "'" => "")
    input = replace(input, "\"" => "")
    input = replace(input, "\\" => "")
    input = replace(input, ";" => "")
    input = replace(input, "--" => "")
    input = replace(input, "/" => "")
    input = replace(input, "%" => "")
    return input
end

const df_empty = DataFrame(date=Date[], total_requests=Int[], region=String[])

function get_package_request_count(conn, package_name, time_interval; user_data=true, ci_data=false, missing_data=false)
    conditions = generate_sql_conditions(user_data, ci_data, missing_data)
    sql = """
        WITH max_date AS (
            SELECT MAX(date) AS max_date
            FROM juliapkgstats.package_requests_by_date
        )
        SELECT date, SUM(request_count) AS total_requests
        FROM juliapkgstats.package_requests_by_date
        INNER JOIN juliapkgstats.uuid_name 
            ON juliapkgstats.package_requests_by_date.package_id = juliapkgstats.uuid_name.package_id
        CROSS JOIN max_date
        WHERE lower(package_name) = lower('$package_name') 
            AND date > max_date - INTERVAL '$time_interval' 
            $conditions
        GROUP BY date
        ORDER BY date;
    """
    return LibPQ.execute(conn, sql) |> DataFrame
end


function get_package_requests(package_name; user_data=true, ci_data=false, missing_data=false)
    conn = LibPQ.Connection(conn_str)
    package_requests = get_package_request_count(conn, package_name, "1 month"; user_data, ci_data, missing_data)
    close(conn)
    return DataTable(package_requests)
end

@vars PackageData begin
    package_name::String = ""
    past_day_requests = "0"
    past_week_requests = "0"
    past_month_requests = "0"
    total_downloads = plot_total_downloads(df_empty)
    region_downloads = plot_region_downloads(df_empty)
    region_proportion = plot_region_proportion(df_empty)
end

@app begin
    @in package_name_search = ""
    @in user_data = true
    @in ci_data = false
    @in missing_data = false
    @out package_name = ""
    @out past_month_requests = "0"
    @out past_week_requests = "0"
    @out past_day_requests = "0"
    @out total_downloads = plot_total_downloads(df_empty)
    @out region_downloads = plot_region_downloads(df_empty)
    @out region_proportion = plot_region_proportion(df_empty)

    @onchange isready begin
        @push
    end

    @onchange user_data, ci_data, missing_data begin
        @info "Change in checkboxes on PackageRequests (user_data: $user_data, ci_data: $ci_data, missing_data: $missing_data)"
        conn = LibPQ.Connection(conn_str)
        package_name_cleansed = package_name |> cleanse_input
        package_requests = get_package_requests(package_name_cleansed; user_data, ci_data, missing_data)
        total_downloads = plot_total_downloads(package_requests.data)
        past_day_requests = format(sum(get_request_count(conn, "juliapkgstats.package_requests_by_date", "1 day", [:date], package_name_cleansed; user_data, ci_data, missing_data).total_requests), commas=true)
        past_week_requests = format(sum(get_request_count(conn, "juliapkgstats.package_requests_by_date", "1 week", [:date], package_name_cleansed; user_data, ci_data, missing_data).total_requests), commas=true)
        past_month_requests = format(sum(get_request_count(conn, "juliapkgstats.package_requests_by_date", "1 month", [:date], package_name_cleansed; user_data, ci_data, missing_data).total_requests), commas=true)
        df_region_downloads = get_request_count(conn, "juliapkgstats.package_requests_by_region_by_date", "1 month", [:region, :date], package_name_cleansed; user_data, ci_data, missing_data)
        region_downloads = plot_region_downloads(df_region_downloads)
        region_proportion = plot_region_proportion(df_region_downloads)
        close(conn)
    end
end

route("/pkg/:package_name", method = GET) do 
    package_name = payload(:package_name) |> cleanse_input
    conn = LibPQ.Connection(conn_str)
    package_requests = get_package_requests(package_name)
    total_downloads = plot_total_downloads(package_requests.data)
    conn = LibPQ.Connection(conn_str)
    past_day_requests = format(sum(get_request_count(conn, "juliapkgstats.package_requests_by_date", "1 day", [:date], package_name).total_requests), commas=true)
    past_week_requests = format(sum(get_request_count(conn, "juliapkgstats.package_requests_by_date", "1 week", [:date], package_name).total_requests), commas=true)
    past_month_requests = format(sum(get_request_count(conn, "juliapkgstats.package_requests_by_date", "1 month", [:date], package_name).total_requests), commas=true)
    df_region_downloads = get_request_count(conn, "juliapkgstats.package_requests_by_region_by_date", "1 month", [:region, :date], package_name)
    region_downloads = plot_region_downloads(df_region_downloads)
    region_proportion = plot_region_proportion(df_region_downloads)
    model = @init
    model.package_name[] = package_name
    model.past_month_requests[] = past_month_requests
    model.past_week_requests[] = past_week_requests
    model.past_day_requests[] = past_day_requests
    model.total_downloads[] = total_downloads
    model.region_downloads[] = region_downloads
    model.region_proportion[] = region_proportion
    page(model, ui()) |> html
end

end
