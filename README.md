## JuliaPkgStats

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

