# REMOVED @methods block from here

function layout_shared()
    return [
        a("<head> <title>Julia Package Download Stats</title> </head>"),
        cell(style="display: flex; justify-content: space-between; align-items: center; background-color: #112244; padding: 10px 50px; color: #ffffff; top: 0; width: 100%; box-sizing: border-box;", [
            Html.div(style="display: flex; align-items: center; gap: 20px;", [
                a(href="/", style="text-decoration: none;", [
                    img(src="/juliapkgstats.png", alt="Julia Package Stats Logo", style="height: 40px;")  # Adding the logo here
                ]),
                a(style="text-decoration: none; color: #ffffff; font-size: 1.5em; font-weight: bold;",
                    "Julia Package Download Statistics"
                )
            ]),
            Html.div(style="display: flex; gap: 20px;", [
                    cell(class="st-col col-12 col-sm st-module", [
                            textfield("Package Search", @bind(:package_name_search), 
                                dense=true,
                                hidebottomspace = true,
                                @on("keyup.enter", "redirectToPackage(package_name_search)")
                            ),
                            ]),
                            btn("Search", @click("redirectToPackage(package_name_search)")),
                        ]
                    ),
            Html.div(style="display: flex; gap: 20px;", [
                a(href="/top", style="text-decoration: none; color: #ffffff; font-size: 1.2em;",
                    "Top"
                ),
                a(href="/all", style="text-decoration: none; color: #ffffff; font-size: 1.2em;",
                    "All"
                ),
                a(href="/api", style="text-decoration: none; color: #ffffff; font-size: 1.2em;",
                    "API"
                )
            ])
        ])
    ]
end