
module API

using Genie
using Genie.Requests
using Genie.Renderer.Json
using GenieFramework
using LibPQ
using DataFrames
using Format
include("layout_shared.jl")
include("utils.jl")

const conn_str = "host=localhost port=5432 dbname=postgres user=postgres password=$DB_PASSWORD"

function get_package_summary(conn, package_name, table; client_type_id::Int=1)
    sql = """
        SELECT
            name.package_name,
            total_requests
        FROM juliapkgstats.$table pkg
        inner join juliapkgstats.uuid_name name on pkg.package_id = name.package_id
        WHERE lower(name.package_name) = lower('$package_name')
        and client_type_id = $client_type_id;
    """
    df = DataFrame(LibPQ.execute(conn, sql))
    if size(df, 1) == 0
        res = Dict("total_requests" => 0)
        return Genie.Renderer.Json.json(
            Dict("package_name" => package_name, "total_requests" => 0)
        )
    else
        total_requests = format(df[1, :total_requests]; commas=true)
        res = Dict("total_requests" => total_requests)
    end

    return Genie.Renderer.Json.json(res)
end

@vars APIData begin
    package_name_badge::String = ""
    submit::Bool = false
    badge::String = ""
end

function monthly_downloads(package_name)
    conn = LibPQ.Connection(conn_str)
    package_summary = get_package_summary(conn, package_name, "mv_package_requests_summary_last_month")
    close(conn)
    return package_summary
end

function total_downloads(package_name)
    conn = LibPQ.Connection(conn_str)
    package_summary = get_package_summary(conn, package_name, "mv_package_requests_summary_total")
    close(conn)
    return package_summary
end


function ui()
    [   
        layout_shared()...,
        h2("API Endpoints"),
        p("There are two API endpoints, <code>monthly_downloads</code> and <code>total_downloads</code>. The API endpoint for monthly downloads is <code>/api/v1/monthly_downloads/:package_name</code>. The <code>:package_name</code> parameter is the name of the package for which you want to get the download statistics. The response is a JSON object with the key <code>total_requests</code> and the value being the total number of <code>user</code> downloads for the package in the last month."),

        p("For example, to get the monthly download statistics for the package DataFrames, you would use the following URL: <code>juliapkgstats.com/api/v1/monthly_downloads/DataFrames</code>."),

        h4("Generate Badge"),
        cell(class="st-col col-12 col-sm st-module", [
            textfield("Package Name", @bind(:package_name_badge), @on("keyup.enter", :keypress)),
            btn("Generate", @click(:submit)),
            a("{{ badge }}"),
        ]),
    ]
end

@app begin
    @in package_name_search = ""
    @in package_name_badge = ""
    @in submit = false
    @out badge = ""

    @onbutton submit begin
        badge = """[![Downloads](https://img.shields.io/badge/dynamic/json?url=http%3A%2F%2Fjuliapkgstats.com%2Fapi%2Fv1%2Fmonthly_downloads%2F$(package_name_badge)&query=total_requests&suffix=%2Fmonth&label=Downloads)](http://juliapkgstats.com/pkg/$(package_name_badge))"""
    end

    @event :keypress begin
        badge = """[![Downloads](https://img.shields.io/badge/dynamic/json?url=http%3A%2F%2Fjuliapkgstats.com%2Fapi%2Fv1%2Fmonthly_downloads%2F$(package_name_badge)&query=total_requests&suffix=%2Fmonth&label=Downloads)](http://juliapkgstats.com/pkg/$(package_name_badge))"""
    end
end

route("/api"; method=GET) do
    model = @init
    html(page(model, ui()))
end

route("/api/v1/monthly_downloads/:package_name"; method=GET) do
    package_name = payload(:package_name)
    monthly_downloads(package_name)
end

route("/api/v1/total_downloads/:package_name"; method=GET) do
    package_name = payload(:package_name)
    total_downloads(package_name)
end

end
