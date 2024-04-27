
module Home

using GenieFramework
include("layout_shared.jl")

function ui()
    [   
        layout_shared()...,
        a(raw"""
        <h4 style="color: black;">Navigation</h4>
        <ul>
        <li><a href="top/" style="color: black;">Top Packages</a></li>
        <li><a href="all/" style="color: black;">All Packages</a></li>
        <li><a href="api/" style="color: black;">API Details</a></li>
        </ul>

        <h4 style="color: black;">About the Data</h4>
        <p style="color: black;">The package download statistics presented here are based on download logs collected from Julia's public package servers. The data is anonymized to protect user privacy while enabling aggregate analysis. The number of users is defined as the unique IP addresses which requested said package without any indicators of being a CI process.</p>
        <p style="color: black;">For more details on the package download stats and how they are collected, see the original announcement on the Julia Discourse forum:</p>
        <p><a href="https://discourse.julialang.org/t/announcing-package-download-stats/69073" style="color: black;">Announcing Package Download Stats</a></p>
        <h4 style="color: black;">Contact</h4>
        <p style="color: black;">If you have any questions or feature requests, you can:</p>
        <ul>
            <li><p style="color: black;">Email <a href="mailto:pricklypointer@gmail.com" style="color: black;">pricklypointer@gmail.com</a></p></li>
            <li><p style="color: black;">Message on Twitter <a href="https://twitter.com/pricklypointer" target="_blank" rel="noopener noreferrer" style="color: black;">@pricklypointer</a></p></li>
        </ul>
        <p style="color: black;">The source code for the website is available here: <a href="https://github.com/pricklypointer/JuliaPkgStats" style="color: black;">https://github.com/pricklypointer/JuliaPkgStats</a></p>
        """),
    ]
end

@vars HomeData begin
end

@app begin
    @in package_name_search = ""
end

route("/", method = GET) do
    model = @init
    page(model, ui()) |> html
end

end
