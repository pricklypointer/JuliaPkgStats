using PlotlyJS

#######################################################
# Total Downloads
#######################################################

function plot_total_downloads(df_total_requests)
    trace = scatter(;
        x=df_total_requests.date, y=df_total_requests.total_requests, mode="lines+markers"
    )
    layout = PlotlyJS.Layout(;
        title=attr(; text="Total Downloads", x=0.5),
        xaxis_title="Date",
        yaxis_title="Total Requests",
        xaxis=attr(; fixedrange=true),
        yaxis=attr(; fixedrange=true),
    )
    return (; data=[trace], layout=layout)
end

#######################################################
# Julia Version Downloads
#######################################################

function plot_julia_version_by_date(df_julia_version_downloads)
    traces = GenericTrace[]
    for version in unique(df_julia_version_downloads.version)
        df_version = filter(row -> row.version == version, df_julia_version_downloads)
        trace = scatter(;
            x=df_version.date,
            y=df_version.total_requests,
            mode="lines+markers",
            name=version,
        )
        push!(traces, trace)
    end
    layout = PlotlyJS.Layout(;
        title=attr(; text="Downloads by Julia Version", x=0.5),
        xaxis_title="Date",
        yaxis_title="Total Requests",
        xaxis=attr(; fixedrange=true),
        yaxis=attr(; fixedrange=true),
    )
    return (; data=traces, layout=layout)
end

function plot_julia_version_proportion(df_julia_version_downloads)
    df_total_by_version_date = combine(
        groupby(df_julia_version_downloads, [:version, :date]),
        :total_requests => sum => :total_requests,
    )
    df_total_by_date = combine(
        groupby(df_julia_version_downloads, :date),
        :total_requests => sum => :total_requests_day,
    )
    df_total_by_version_date = innerjoin(
        df_total_by_version_date, df_total_by_date; on=:date, makeunique=true
    )
    df_total_by_version_date.proportion =
        df_total_by_version_date.total_requests ./
        df_total_by_version_date.total_requests_day

    traces = GenericTrace[]
    for version in unique(df_total_by_version_date.version)
        df_version = filter(row -> row.version == version, df_total_by_version_date)
        trace = scatter(;
            x=df_version.date, y=df_version.proportion, mode="lines+markers", name=version
        )
        push!(traces, trace)
    end

    layout = PlotlyJS.Layout(;
        title=attr(; text="Download Proportion by Julia Version", x=0.5),
        xaxis_title="Date",
        yaxis_title="Proportion",
        xaxis=attr(; fixedrange=true),
        yaxis=attr(; fixedrange=true),
    )
    return (; data=traces, layout=layout)
end

#######################################################
# Region Downloads
#######################################################

function plot_region_downloads(df_region)
    traces = GenericTrace[]
    for region in unique(df_region.region)
        df_region_filtered = filter(row -> row.region == region, df_region)
        trace = scatter(;
            x=df_region_filtered.date,
            y=df_region_filtered.total_requests,
            mode="lines+markers",
            name=region,
        )
        push!(traces, trace)
    end
    layout = PlotlyJS.Layout(;
        title=attr(; text="Downloads by Region", x=0.5),
        xaxis_title="Date",
        yaxis_title="Total Requests",
        xaxis=attr(; fixedrange=true),
        yaxis=attr(; fixedrange=true),
    )
    return (; data=traces, layout=layout)
end

function plot_region_proportion(df_region)
    df_total_by_region_date = combine(
        groupby(df_region, [:region, :date]), :total_requests => sum => :total_requests
    )
    df_total_by_date = combine(
        groupby(df_region, :date), :total_requests => sum => :total_requests_day
    )
    df_total_by_region_date = innerjoin(
        df_total_by_region_date, df_total_by_date; on=:date, makeunique=true
    )
    df_total_by_region_date.proportion =
        df_total_by_region_date.total_requests ./ df_total_by_region_date.total_requests_day

    traces = GenericTrace[]
    for region in unique(df_total_by_region_date.region)
        df_region_filtered = filter(row -> row.region == region, df_total_by_region_date)
        trace = scatter(;
            x=df_region_filtered.date,
            y=df_region_filtered.proportion,
            mode="lines+markers",
            name=region,
        )
        push!(traces, trace)
    end

    layout = PlotlyJS.Layout(;
        title=attr(; text="Download Proportion by Region", x=0.5),
        xaxis_title="Date",
        yaxis_title="Proportion",
        xaxis=attr(; fixedrange=true),
        yaxis=attr(; fixedrange=true),
    )
    return (; data=traces, layout=layout)
end

#######################################################
# Julia System Downloads
#######################################################
# Taken from Mosè Giordano on Slack
function getos(full_system_name::String)
    platform = tryparse(Base.BinaryPlatforms.Platform, full_system_name)

    if !isnothing(platform)
        return Base.BinaryPlatforms.os(platform)
    end

    return split(full_system_name, '-')[2]
end

function getarch(full_system_name::String)
    platform = tryparse(Base.BinaryPlatforms.Platform, full_system_name)

    if !isnothing(platform)
        return Base.BinaryPlatforms.arch(platform)
    end

    return split(full_system_name, '-')[1]
end
function process_system(full_system_name::String, selected_arch_os::String)
    full_system_name = replace(full_system_name, "unknown" => "freebsd")
    full_system_name = replace(full_system_name, "-apple" => "-apple-darwin")
    full_system_name = replace(full_system_name, "-w64" => "-w64-mingw32")
    if selected_arch_os == "Full"
        return getarch(full_system_name) * "-" * getos(full_system_name)
    elseif selected_arch_os == "CPU Arch"
        return getarch(full_system_name)
    elseif selected_arch_os == "OS"
        return getos(full_system_name)
    end
end

function plot_julia_system_downloads(
    df_julia_system_downloads::DataFrame, selected_arch_os::String="Full"
)
    df_julia_system_downloads[!, :selected_system] =
        process_system.(df_julia_system_downloads.system, selected_arch_os)

    df_julia_system_downloads = combine(
        groupby(df_julia_system_downloads, [:selected_system, :date]),
        :total_requests => sum => :total_requests,
    )

    traces = GenericTrace[]
    for system in unique(df_julia_system_downloads.selected_system)
        df_system = filter(row -> row.selected_system == system, df_julia_system_downloads)
        df_system = sort(df_system, :date)
        trace = scatter(;
            x=df_system.date, y=df_system.total_requests, mode="lines+markers", name=system
        )
        push!(traces, trace)
    end
    layout = PlotlyJS.Layout(;
        title=attr(; text="Downloads by Julia System", x=0.5),
        xaxis_title="Date",
        yaxis_title="Total Requests",
        xaxis=attr(; fixedrange=true),
        yaxis=attr(; fixedrange=true),
    )
    return (; data=traces, layout=layout)
end

function plot_system_proportion(
    df_julia_system_downloads::DataFrame, selected_arch_os::String="Full"
)
    df_julia_system_downloads[!, :selected_system] =
        process_system.(df_julia_system_downloads.system, selected_arch_os)

    df_total_by_system_date = combine(
        groupby(df_julia_system_downloads, [:selected_system, :date]),
        :total_requests => sum => :total_requests,
    )
    df_total_by_date = combine(
        groupby(df_julia_system_downloads, :date),
        :total_requests => sum => :total_requests_day,
    )
    df_total_by_system_date = innerjoin(
        df_total_by_system_date, df_total_by_date; on=:date, makeunique=true
    )
    df_total_by_system_date.proportion =
        df_total_by_system_date.total_requests ./ df_total_by_system_date.total_requests_day

    traces = GenericTrace[]
    for system in unique(df_total_by_system_date.selected_system)
        df_system = filter(row -> row.selected_system == system, df_total_by_system_date)
        df_system = sort(df_system, :date)
        trace = scatter(;
            x=df_system.date, y=df_system.proportion, mode="lines+markers", name=system
        )
        push!(traces, trace)
    end

    layout = PlotlyJS.Layout(;
        title=attr(; text="Download Proportion by System", x=0.5),
        xaxis_title="Date",
        yaxis_title="Proportion",
        xaxis=attr(; fixedrange=true),
        yaxis=attr(; fixedrange=true),
    )
    return (; data=traces, layout=layout)
end
