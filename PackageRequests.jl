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

@vars PackageData begin
    package_name::String = ""
    timeframe::String = "30d"
    past_day_requests = "0"
    past_week_requests = "0"
    past_month_requests = "0"
    total_downloads = plot_total_downloads(df_empty)
    region_downloads = plot_region_downloads(df_empty)
    region_proportion = plot_region_proportion(df_empty)
end

function get_request_count(
    conn,
    table,
    timeframe,
    group_cols,
    package_name;
    user_data=true,
    ci_data=false,
    missing_data=false,
)
    conditions = generate_sql_conditions(user_data, ci_data, missing_data)
    group_cols_str = join(string.(group_cols), ", ")

    if timeframe == "all"
        timeframe = "100 years"
    end

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
            AND date > max_date - INTERVAL '$timeframe' $conditions
        GROUP BY $group_cols_str
        ORDER BY $group_cols_str DESC;
    """
    return DataFrame(LibPQ.execute(conn, sql))
end

function ui()
    [
        layout_shared()...,
        h2("{{ package_name }}"),
        hr(style="border: 1px solid #ccc;"),
        
        cell(class="controls-container", [
            cell(class="control-item", [
                label("Time Range", class="control-label"),
                Stipple.select(:timeframe, 
                    options=["30d", "60d", "120d", "all"],
                    class="select-input"
                )
            ]),
            
            cell(class="toggle-group", [
                toggle("User", :user_data, val=true, color="green", class="toggle-item"),
                toggle("CI", :ci_data, val=false, color="red", class="toggle-item"),
                toggle("Misc", :missing_data, val=false, color="purple", class="toggle-item")
            ])
        ]),

        p("Downloads last month: {{ past_month_requests }}"),
        p("Downloads last week: {{ past_week_requests }}"),
        p("Downloads last day: {{ past_day_requests }}"),
        hr(style="border: 1px solid #ccc; margin: 5px 0;"),
        
        GenieFramework.plotly(:total_downloads),
        GenieFramework.plotly(:region_downloads),
        GenieFramework.plotly(:region_proportion)
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

const df_empty = DataFrame(; date=Date[], total_requests=Int[], region=String[])

function get_package_request_count(
    conn, package_name, timeframe; user_data=true, ci_data=false, missing_data=false
)
    conditions = generate_sql_conditions(user_data, ci_data, missing_data)
    
    if timeframe == "all"
        timeframe = "100 years"
    end
    
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
            AND date > max_date - INTERVAL '$timeframe'
            $conditions
        GROUP BY date
        ORDER BY date;
    """
    return DataFrame(LibPQ.execute(conn, sql))
end

function get_package_requests(
    package_name, timeframe="30d"; user_data=true, ci_data=false, missing_data=false
)
    conn = LibPQ.Connection(conn_str)
    package_requests = get_package_request_count(
        conn, package_name, timeframe; user_data, ci_data, missing_data
    )
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
    @in timeframe = "30d"
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
    @methods """
    redirectToPackage: function(packageName) {
        const url = '/pkg/' + packageName;
        window.location.href = url;
    }
    """
    @onchange isready begin
        @push
    end

    @onchange timeframe, user_data, ci_data, missing_data begin
        @info "Change in timeframe or checkboxes (timeframe: $timeframe, user_data: $user_data, ci_data: $ci_data, missing_data: $missing_data)"
        conn = LibPQ.Connection(conn_str)
        package_name_cleansed = cleanse_input(package_name)
        
        # Update the download statistics
        day_req, week_req, month_req = update_download_stats(
            conn, package_name_cleansed, user_data, ci_data, missing_data
        )
        
        # Ensure the values are strings (as expected by the reactive model)
        past_day_requests = string(day_req)
        past_week_requests = string(week_req)
        past_month_requests = string(month_req)
        
        # Update the plots
        package_requests = get_package_requests(
            package_name_cleansed,
            timeframe;
            user_data,
            ci_data,
            missing_data
        )
        total_downloads = plot_total_downloads(package_requests.data)
        
        df_region_downloads = get_request_count(
            conn,
            "juliapkgstats.package_requests_by_region_by_date",
            timeframe,
            [:region, :date],
            package_name_cleansed;
            user_data,
            ci_data,
            missing_data,
        )
        
        region_downloads = plot_region_downloads(df_region_downloads)
        region_proportion = plot_region_proportion(df_region_downloads)
        
        close(conn)
        @push
    end
end

function update_download_stats(conn, package_name, user_data, ci_data, missing_data)
    past_day_requests = format(
        sum(
            get_request_count(
                conn,
                "juliapkgstats.package_requests_by_date",
                "1 day",
                [:date],
                package_name;
                user_data,
                ci_data,
                missing_data,
            ).total_requests,
        );
        commas=true,
    )
    past_week_requests = format(
        sum(
            get_request_count(
                conn,
                "juliapkgstats.package_requests_by_date",
                "1 week",
                [:date],
                package_name;
                user_data,
                ci_data,
                missing_data,
            ).total_requests,
        );
        commas=true,
    )
    past_month_requests = format(
        sum(
            get_request_count(
                conn,
                "juliapkgstats.package_requests_by_date",
                "1 month",
                [:date],
                package_name;
                user_data,
                ci_data,
                missing_data,
            ).total_requests,
        );
        commas=true,
    )
    return past_day_requests, past_week_requests, past_month_requests
end

function get_package_requests(
    package_name, timeframe="30d"; user_data=true, ci_data=false, missing_data=false
)
    conn = LibPQ.Connection(conn_str)
    package_requests = get_package_request_count(
        conn, package_name, timeframe; user_data, ci_data, missing_data
    )
    close(conn)
    return DataTable(package_requests)
end

route("/pkg/:package_name"; method=GET) do
    package_name = cleanse_input(payload(:package_name))
    conn = LibPQ.Connection(conn_str)
    
    timeframe = "30d"
    
    package_requests = get_package_requests(package_name, timeframe)
    total_downloads = plot_total_downloads(package_requests.data)

    df_region_downloads = get_request_count(
        conn,
        "juliapkgstats.package_requests_by_region_by_date",
        timeframe,
        [:region, :date],
        package_name
    )
    region_downloads = plot_region_downloads(df_region_downloads)
    region_proportion = plot_region_proportion(df_region_downloads)
    
    past_day_requests = format(
        sum(
            get_request_count(
                conn,
                "juliapkgstats.package_requests_by_date",
                "1 day",
                [:date],
                package_name
            ).total_requests,
        );
        commas=true,
    )
    past_week_requests = format(
        sum(
            get_request_count(
                conn,
                "juliapkgstats.package_requests_by_date",
                "1 week",
                [:date],
                package_name
            ).total_requests,
        );
        commas=true,
    )
    past_month_requests = format(
        sum(
            get_request_count(
                conn,
                "juliapkgstats.package_requests_by_date",
                "1 month",
                [:date],
                package_name
            ).total_requests,
        );
        commas=true,
    )
    
    model = @init
    model.package_name[] = package_name
    model.timeframe[] = timeframe  # Set initial timeframe
    model.past_month_requests[] = past_month_requests
    model.past_week_requests[] = past_week_requests
    model.past_day_requests[] = past_day_requests
    model.total_downloads[] = total_downloads
    model.region_downloads[] = region_downloads
    model.region_proportion[] = region_proportion
    
    close(conn)
    html(page(model, ui()))
end

end
