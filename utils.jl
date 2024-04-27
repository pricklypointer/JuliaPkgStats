
const DB_PASSWORD = ENV["DB_PASSWORD"]
const conn_str = "host=localhost port=5432 dbname=postgres user=postgres password=$DB_PASSWORD"

function generate_sql_conditions(user_data::Bool, ci_data::Bool, missing_data::Bool)
    client_types = String[]
    if user_data
        push!(client_types, "1")
    end
    if ci_data
        push!(client_types, "2")
    end
    if missing_data
        push!(client_types, "3")
    end

    if !isempty(client_types)
        return "AND client_type_id IN ('$(join(client_types, "', '"))')"
    else
        return "AND client_type_id in (4)" # Do we want no data if they are all deselected?
    end
end
