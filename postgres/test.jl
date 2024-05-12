using GitHub
using PackageAnalyzer

GITHUB_PAT = ENV["GITHUB_PAT"]
auth = authenticate(GITHUB_PAT)

all_packages = find_packages()
#TODO: Support GitLab
github_packages = [i for i in all_packages if occursin("github.com/", i.repo)]

repo = github_packages[1].repo
s = stargazers("TidierOrg/Tidier.jl"; auth)
c = contributors("TidierOrg/Tidier.jl"; auth)

