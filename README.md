## JuliaPkgStats

[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/JuliaDiff/BlueStyle)

The code behind https://juliapkgstats.com/. 

## Installation

Docker is required to run the following application without any modifications to the code.

The following environment variables are also required for automatically and using the database.

```bash
DB_PASSWORD
```
Clone the repository and install the dependencies, then `cd` into the project directory then run:

```bash
julia --project -e 'using Pkg; Pkg.instantiate()'
```

Next, you need to add the data to the postgres database.
```bash
bash ./start_postgres.sh
bash ./update_data.sh
```

Finally, run the app

```bash
julia --project
```

```julia
using GenieFramework
Genie.loadapp() # load app
up() # start server
```

## Usage

Open your browser and navigate to `http://localhost:8000/`

## Example Badge (DataFrames.jl)

[![Downloads](https://img.shields.io/badge/dynamic/json?url=http%3A%2F%2Fjuliapkgstats.com%2Fapi%2Fv1%2Fmonthly_downloads%2FDataFrames&query=total_requests&suffix=%2Fmonth&label=Downloads)](http://juliapkgstats.com/pkg/DataFrames)
