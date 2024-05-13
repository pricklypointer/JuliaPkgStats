module AllPackageRequests

using DataFrames
using Dates
using GenieFramework
using Format
using LibPQ
include("layout_shared.jl")
include("plots.jl")
include("utils.jl")

function get_request_count(
    conn,
    table,
    time_interval,
    group_cols;
    user_data=true,
    ci_data=false,
    missing_data=false,
)
    conditions = generate_sql_conditions(user_data, ci_data, missing_data)
    group_cols_str = join(string.(group_cols), ", ")
    sql = """
        WITH max_date AS (
            SELECT MAX(date) AS max_date
            FROM $table
        )
        SELECT $group_cols_str, SUM(request_count) AS total_requests
        FROM $table
        CROSS JOIN max_date
        WHERE date > max_date - INTERVAL '$time_interval' $conditions
        GROUP BY $group_cols_str
        ORDER BY $group_cols_str DESC;
    """
    return DataFrame(LibPQ.execute(conn, sql))
end

function ui()
    [   
        layout_shared()...,
        heading("All Packages"),
        hr(style="border: 1px solid #ccc;"),
        cell(class="row", [
            toggle("User", :user_data, val=true, color="green"),
            toggle("CI", :ci_data, val=false, color="red"),
            toggle("Misc", :missing_data, val=false, color="purple"),
        ]),

        p("Downloads last month: {{ past_month_requests }}"),
        p("Downloads last week: {{ past_week_requests }}") ,
        p("Downloads last day: {{ past_day_requests }}"),

        hr(style="border: 1px solid #ccc; margin: 5px 0;"),
        GenieFramework.plotly(:total_downloads),

        hr(style="border: 1px solid #ccc; margin: 20px 0;"),
        GenieFramework.plotly(:julia_version_downloads),
        GenieFramework.plotly(:julia_version_proportion),

        hr(style="border: 1px solid #ccc; margin: 20px 0;"),
        GenieFramework.plotly(:region_downloads),
        GenieFramework.plotly(:region_proportion),

        hr(style="border: 1px solid #ccc; margin: 20px 0;"),
        GenieFramework.select(:selected_arch_os, options=:arch_os_options, style="width: 200px;"),
        GenieFramework.plotly(:julia_system_downloads),
        GenieFramework.plotly(:julia_system_proportion),
        footer("The figures above represent unique IP address download counts for each package. The count might not fully reflect the actual downloads for packages with less frequent releases, and multiple counts could occur for users with dynamic IP addresses.", href="https://discourse.julialang.org/t/announcing-package-download-stats/69073")
    ]
end

const conn = LibPQ.Connection(conn_str)

const df_total_requests = get_request_count(
    conn, "juliapkgstats.package_requests_by_date", "1 month", [:date]
)
const past_month_requests = format(sum(df_total_requests.total_requests); commas=true)
const past_week_requests = format(
    sum(
        get_request_count(
            conn, "juliapkgstats.package_requests_by_date", "1 week", [:date]
        ).total_requests,
    );
    commas=true,
)
const past_day_requests = format(
    sum(
        get_request_count(
            conn, "juliapkgstats.package_requests_by_date", "1 day", [:date]
        ).total_requests,
    );
    commas=true,
)
const df_julia_version_downloads = get_request_count(
    conn, "juliapkgstats.julia_versions_by_date", "1 month", [:version, :date]
)

const total_downloads = plot_total_downloads(df_total_requests)
const julia_version_downloads = plot_julia_version_by_date(df_julia_version_downloads)
const julia_version_proportion = plot_julia_version_proportion(df_julia_version_downloads)

const df_region = get_request_count(
    conn, "juliapkgstats.package_requests_by_region_by_date", "1 month", [:region, :date]
)
const region_downloads = plot_region_downloads(df_region)
const region_proportion = plot_region_proportion(df_region)

const df_julia_system_downloads = get_request_count(
    conn, "juliapkgstats.julia_systems_by_date", "1 month", [:system, :date]
)
const julia_system_downloads = plot_julia_system_downloads(df_julia_system_downloads)
const julia_system_proportion = plot_system_proportion(df_julia_system_downloads)
close(conn)

@vars AllPackageRequestsData begin
    past_month_requests::String = past_month_requests
    past_week_requests::String = past_week_requests
    past_day_requests::String = past_day_requests
    total_downloads = total_downloads
    julia_version_downloads = julia_version_downloads
    julia_version_proportion = julia_version_proportion
    region_downloads = region_downloads
    region_proportion = region_proportion
    julia_system_downloads = julia_system_downloads
    julia_system_proportion = julia_system_proportion
end

@app begin
    @in user_data = true
    @in ci_data = false
    @in missing_data = false
    @in package_name_search = ""
    @in selected_arch_os = "Full"
    @out arch_os_options = ["Full", "CPU Arch", "OS"]
    @out past_month_requests = past_month_requests
    @out past_week_requests = past_week_requests
    @out past_day_requests = past_day_requests
    @out total_downloads = total_downloads
    @out julia_version_downloads = julia_version_downloads
    @out julia_version_proportion = julia_version_proportion
    @out region_downloads = region_downloads
    @out region_proportion = region_proportion
    @out julia_system_downloads = julia_system_downloads
    @out julia_system_proportion = julia_system_proportion

    @onchange isready begin
        @push
    end

    @onchange selected_arch_os begin
        conn = LibPQ.Connection(conn_str)
        julia_system_downloads = plot_julia_system_downloads(
            get_request_count(
                conn,
                "juliapkgstats.julia_systems_by_date",
                "1 month",
                [:system, :date];
                user_data,
                ci_data,
                missing_data,
            ),
            selected_arch_os
        )
        julia_system_proportion = plot_system_proportion(
            get_request_count(
                conn,
                "juliapkgstats.julia_systems_by_date",
                "1 month",
                [:system, :date];
                user_data,
                ci_data,
                missing_data,
            ),
            selected_arch_os
        )
        close(conn)
    end

    @onchange user_data, ci_data, missing_data begin
        @info "Change in checkboxes on AllPackageRequests (user_data: $user_data, ci_data: $ci_data, missing_data: $missing_data)"
        conn = LibPQ.Connection(conn_str)
        past_month_requests = format(
            sum(
                get_request_count(
                    conn,
                    "juliapkgstats.package_requests_by_date",
                    "1 month",
                    [:date];
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
                    [:date];
                    user_data,
                    ci_data,
                    missing_data,
                ).total_requests,
            );
            commas=true,
        )
        past_day_requests = format(
            sum(
                get_request_count(
                    conn,
                    "juliapkgstats.package_requests_by_date",
                    "1 day",
                    [:date];
                    user_data,
                    ci_data,
                    missing_data,
                ).total_requests,
            );
            commas=true,
        )
        total_downloads = plot_total_downloads(
            get_request_count(
                conn,
                "juliapkgstats.package_requests_by_date",
                "1 month",
                [:date];
                user_data,
                ci_data,
                missing_data,
            ),
        )
        julia_version_downloads = plot_julia_version_by_date(
            get_request_count(
                conn,
                "juliapkgstats.julia_versions_by_date",
                "1 month",
                [:version, :date];
                user_data,
                ci_data,
                missing_data,
            ),
        )
        julia_version_proportion = plot_julia_version_proportion(
            get_request_count(
                conn,
                "juliapkgstats.julia_versions_by_date",
                "1 month",
                [:version, :date];
                user_data,
                ci_data,
                missing_data,
            ),
        )
        region_downloads = plot_region_downloads(
            get_request_count(
                conn,
                "juliapkgstats.package_requests_by_region_by_date",
                "1 month",
                [:region, :date];
                user_data,
                ci_data,
                missing_data,
            ),
        )
        region_proportion = plot_region_proportion(
            get_request_count(
                conn,
                "juliapkgstats.package_requests_by_region_by_date",
                "1 month",
                [:region, :date];
                user_data,
                ci_data,
                missing_data,
            ),
        )
        julia_system_downloads = plot_julia_system_downloads(
            get_request_count(
                conn,
                "juliapkgstats.julia_systems_by_date",
                "1 month",
                [:system, :date];
                user_data,
                ci_data,
                missing_data,
            ),
            selected_arch_os
        )
        julia_system_proportion = plot_system_proportion(
            get_request_count(
                conn,
                "juliapkgstats.julia_systems_by_date",
                "1 month",
                [:system, :date];
                user_data,
                ci_data,
                missing_data,
            ),
            selected_arch_os
        )
        close(conn)
    end
end

route("/all"; method=GET) do
    conn = LibPQ.Connection(conn_str)
    past_month_requests = format(
        sum(
            get_request_count(
                conn, "juliapkgstats.package_requests_by_date", "1 month", [:date]
            ).total_requests,
        );
        commas=true,
    )
    past_week_requests = format(
        sum(
            get_request_count(
                conn, "juliapkgstats.package_requests_by_date", "1 week", [:date]
            ).total_requests,
        );
        commas=true,
    )
    past_day_requests = format(
        sum(
            get_request_count(
                conn, "juliapkgstats.package_requests_by_date", "1 day", [:date]
            ).total_requests,
        );
        commas=true,
    )
    total_downloads = plot_total_downloads(
        get_request_count(
            conn, "juliapkgstats.package_requests_by_date", "1 month", [:date]
        ),
    )
    julia_version_downloads = plot_julia_version_by_date(
        get_request_count(
            conn, "juliapkgstats.julia_versions_by_date", "1 month", [:version, :date]
        ),
    )
    julia_version_proportion = plot_julia_version_proportion(
        get_request_count(
            conn, "juliapkgstats.julia_versions_by_date", "1 month", [:version, :date]
        ),
    )
    region_downloads = plot_region_downloads(
        get_request_count(
            conn,
            "juliapkgstats.package_requests_by_region_by_date",
            "1 month",
            [:region, :date],
        ),
    )
    region_proportion = plot_region_proportion(
        get_request_count(
            conn,
            "juliapkgstats.package_requests_by_region_by_date",
            "1 month",
            [:region, :date],
        ),
    )
    julia_system_downloads = plot_julia_system_downloads(
        get_request_count(
            conn, "juliapkgstats.julia_systems_by_date", "1 month", [:system, :date]
        ),
    )
    julia_system_proportion = plot_system_proportion(
        get_request_count(
            conn, "juliapkgstats.julia_systems_by_date", "1 month", [:system, :date]
        ),
    )
    close(conn)
    model = @init
    model.past_month_requests[] = past_month_requests
    model.past_week_requests[] = past_week_requests
    model.past_day_requests[] = past_day_requests
    model.total_downloads[] = total_downloads
    model.julia_version_downloads[] = julia_version_downloads
    model.julia_version_proportion[] = julia_version_proportion
    model.region_downloads[] = region_downloads
    model.region_proportion[] = region_proportion
    model.julia_system_downloads[] = julia_system_downloads
    model.julia_system_proportion[] = julia_system_proportion
    html(page(model, ui()))
end

end
