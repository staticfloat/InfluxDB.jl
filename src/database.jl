export create_database, list_databases

function create_database(server::InfluxServer, db_name::AbstractString)
    return query(server, "CREATE DATABASE \"$(db_name)\"", type=:post)
end

function list_databases(server::InfluxServer)
    return query(server, "SHOW DATABASES")
end

function list_measurements(server::InfluxServer, db::AbstractString)
    return query(server, "SHOW MEASUREMENTS ON $db")
end
